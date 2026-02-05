#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#if defined(__linux__)

#include <alsa/asoundlib.h>
#include <errno.h>
#include <pthread.h>
#include <stdatomic.h>
#include <time.h>

typedef struct moon_cpal_alsa_stream_t {
  int is_input;
  uint32_t sample_format_tag;
  uint32_t channels;
  unsigned int sample_rate;
  uint32_t buffer_frames;
  uint32_t buffer_bytes;

  snd_pcm_t *pcm;

  void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t, int32_t);
  void *mb_data_callback;
  void (*call_error_callback)(void *, int32_t, int32_t);
  void *mb_error_callback;

  moonbit_bytes_t mb_buffer;

  pthread_t thread;
  int thread_started;
  pthread_mutex_t mu;
  pthread_cond_t cv;

  atomic_int running;
  atomic_int closed;
} moon_cpal_alsa_stream_t;

static void alsa_now(int64_t *out_secs, int32_t *out_nanos) {
  if (out_secs == NULL || out_nanos == NULL) {
    return;
  }
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    *out_secs = 0;
    *out_nanos = 0;
    return;
  }
  *out_secs = (int64_t)ts.tv_sec;
  *out_nanos = (int32_t)ts.tv_nsec;
}

static void alsa_invoke_error(moon_cpal_alsa_stream_t *s, int32_t op_tag, int32_t status) {
  if (s == NULL || s->call_error_callback == NULL || s->mb_error_callback == NULL) {
    return;
  }
  moonbit_incref(s->mb_error_callback);
  s->call_error_callback(s->mb_error_callback, op_tag, status);
}

static int alsa_sample_format_from_tag(uint32_t tag, snd_pcm_format_t *out) {
  if (out == NULL) {
    return -1;
  }
  switch (tag) {
  case 1:
    *out = SND_PCM_FORMAT_FLOAT_LE;
    return 0;
  case 2:
    *out = SND_PCM_FORMAT_S16_LE;
    return 0;
  case 3:
    *out = SND_PCM_FORMAT_U16_LE;
    return 0;
  case 4:
    *out = SND_PCM_FORMAT_U8;
    return 0;
  default:
    return -1;
  }
}

static uint32_t alsa_bytes_per_sample_from_tag(uint32_t tag) {
  switch (tag) {
  case 1:
    return 4;
  case 2:
    return 2;
  case 3:
    return 2;
  case 4:
    return 1;
  default:
    return 0;
  }
}

static int alsa_configure_pcm(snd_pcm_t *pcm,
                              unsigned int sample_rate,
                              uint32_t channels,
                              uint32_t sample_format_tag,
                              uint32_t buffer_frames) {
  if (pcm == NULL || channels == 0 || sample_rate == 0) {
    return -EINVAL;
  }

  snd_pcm_hw_params_t *hw = NULL;
  snd_pcm_hw_params_alloca(&hw);
  int err = snd_pcm_hw_params_any(pcm, hw);
  if (err < 0) {
    return err;
  }

  err = snd_pcm_hw_params_set_access(pcm, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
  if (err < 0) {
    return err;
  }

  snd_pcm_format_t fmt;
  if (alsa_sample_format_from_tag(sample_format_tag, &fmt) != 0) {
    return -EINVAL;
  }
  err = snd_pcm_hw_params_set_format(pcm, hw, fmt);
  if (err < 0) {
    return err;
  }

  err = snd_pcm_hw_params_set_channels(pcm, hw, channels);
  if (err < 0) {
    return err;
  }

  unsigned int rate = sample_rate;
  err = snd_pcm_hw_params_set_rate_near(pcm, hw, &rate, NULL);
  if (err < 0) {
    return err;
  }

  if (buffer_frames != 0) {
    snd_pcm_uframes_t period = (snd_pcm_uframes_t)buffer_frames;
    err = snd_pcm_hw_params_set_period_size_near(pcm, hw, &period, NULL);
    if (err < 0) {
      return err;
    }

    snd_pcm_uframes_t buf_sz = period * 4;
    err = snd_pcm_hw_params_set_buffer_size_near(pcm, hw, &buf_sz);
    if (err < 0) {
      return err;
    }
  }

  err = snd_pcm_hw_params(pcm, hw);
  if (err < 0) {
    return err;
  }

  err = snd_pcm_prepare(pcm);
  if (err < 0) {
    return err;
  }
  return 0;
}

static uint32_t alsa_current_period_frames(snd_pcm_t *pcm) {
  if (pcm == NULL) {
    return 0;
  }
  snd_pcm_hw_params_t *hw = NULL;
  snd_pcm_hw_params_alloca(&hw);
  if (snd_pcm_hw_params_current(pcm, hw) < 0) {
    return 0;
  }
  snd_pcm_uframes_t period = 0;
  if (snd_pcm_hw_params_get_period_size(hw, &period, NULL) < 0) {
    return 0;
  }
  if (period == 0) {
    return 0;
  }
  if (period > 0xFFFFFFFFu) {
    return 0xFFFFFFFFu;
  }
  return (uint32_t)period;
}

static void *alsa_thread_main(void *p) {
  moon_cpal_alsa_stream_t *s = (moon_cpal_alsa_stream_t *)p;
  if (s == NULL) {
    return NULL;
  }

  for (;;) {
    pthread_mutex_lock(&s->mu);
    while (atomic_load(&s->running) == 0 && atomic_load(&s->closed) == 0) {
      pthread_cond_wait(&s->cv, &s->mu);
    }
    pthread_mutex_unlock(&s->mu);

    if (atomic_load(&s->closed) != 0) {
      break;
    }

    if (s->pcm == NULL || s->mb_buffer == NULL || s->buffer_frames == 0) {
      alsa_invoke_error(s, 4 /* config */, -EINVAL);
      break;
    }

    if (s->is_input == 0) {
      // Output: callback -> ALSA write.
      int64_t cb_secs = 0;
      int32_t cb_nanos = 0;
      alsa_now(&cb_secs, &cb_nanos);

      // Best-effort "playback" time: use callback time.
      int64_t pb_secs = cb_secs;
      int32_t pb_nanos = cb_nanos;

      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos,
                            pb_secs, pb_nanos);

      uint32_t frames_left = s->buffer_frames;
      uint8_t *ptr = (uint8_t *)s->mb_buffer;
      uint32_t bytes_per_frame = s->buffer_bytes / s->buffer_frames;
      while (frames_left > 0 && atomic_load(&s->running) != 0 && atomic_load(&s->closed) == 0) {
        snd_pcm_sframes_t w = snd_pcm_writei(s->pcm, ptr, (snd_pcm_uframes_t)frames_left);
        if (w == -EPIPE) {
          // XRUN
          alsa_invoke_error(s, 6 /* xrun */, (int32_t)w);
          snd_pcm_prepare(s->pcm);
          continue;
        }
        if (w < 0) {
          alsa_invoke_error(s, 1 /* snd_pcm_writei */, (int32_t)w);
          // Try to recover.
          snd_pcm_prepare(s->pcm);
          break;
        }
        if (w == 0) {
          continue;
        }
        frames_left -= (uint32_t)w;
        ptr += (size_t)w * (size_t)bytes_per_frame;
      }
    } else {
      // Input: ALSA read -> callback.
      uint32_t frames_left = s->buffer_frames;
      uint8_t *ptr = (uint8_t *)s->mb_buffer;
      uint32_t bytes_per_frame = s->buffer_bytes / s->buffer_frames;
      while (frames_left > 0 && atomic_load(&s->running) != 0 && atomic_load(&s->closed) == 0) {
        snd_pcm_sframes_t r = snd_pcm_readi(s->pcm, ptr, (snd_pcm_uframes_t)frames_left);
        if (r == -EPIPE) {
          alsa_invoke_error(s, 6 /* xrun */, (int32_t)r);
          snd_pcm_prepare(s->pcm);
          continue;
        }
        if (r < 0) {
          alsa_invoke_error(s, 2 /* snd_pcm_readi */, (int32_t)r);
          snd_pcm_prepare(s->pcm);
          break;
        }
        if (r == 0) {
          continue;
        }
        frames_left -= (uint32_t)r;
        ptr += (size_t)r * (size_t)bytes_per_frame;
      }

      int64_t cb_secs = 0;
      int32_t cb_nanos = 0;
      alsa_now(&cb_secs, &cb_nanos);
      int64_t cap_secs = cb_secs;
      int32_t cap_nanos = cb_nanos;

      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos,
                            cap_secs, cap_nanos);
    }
  }

  return NULL;
}

static void alsa_stream_destroy(moon_cpal_alsa_stream_t *s) {
  if (s == NULL) {
    return;
  }
  atomic_store(&s->running, 0);
  atomic_store(&s->closed, 1);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  // Ensure blocking I/O wakes up.
  if (s->pcm != NULL) {
    snd_pcm_drop(s->pcm);
  }
  if (s->thread_started) {
    pthread_join(s->thread, NULL);
  }
  if (s->pcm != NULL) {
    snd_pcm_close(s->pcm);
    s->pcm = NULL;
  }
  if (s->mb_data_callback != NULL) {
    moonbit_decref(s->mb_data_callback);
    s->mb_data_callback = NULL;
  }
  if (s->mb_error_callback != NULL) {
    moonbit_decref(s->mb_error_callback);
    s->mb_error_callback = NULL;
  }
  if (s->mb_buffer != NULL) {
    moonbit_decref(s->mb_buffer);
    s->mb_buffer = NULL;
  }
  pthread_mutex_destroy(&s->mu);
  pthread_cond_destroy(&s->cv);
  free(s);
}

static int alsa_stream_new(const char *device_id,
                           int is_input,
                           double sample_rate,
                           uint32_t channels,
                           uint32_t sample_format_tag,
                           uint32_t buffer_frames,
                           void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t,
                                                     int32_t),
                           void *data_callback,
                           void (*call_error_callback)(void *, int32_t, int32_t),
                           void *error_callback,
                           uint64_t *out_handle) {
  if (out_handle == NULL) {
    return -EINVAL;
  }
  *out_handle = 0;

  if (device_id == NULL || device_id[0] == '\0') {
    device_id = "default";
  }

  uint32_t bps = alsa_bytes_per_sample_from_tag(sample_format_tag);
  if (bps == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -EINVAL;
  }
  // `buffer_frames == 0` means "default": do not constrain the device period size.
  // We'll query the configured period after applying hw_params.
  uint32_t requested_frames = buffer_frames;

  moon_cpal_alsa_stream_t *s = (moon_cpal_alsa_stream_t *)calloc(1, sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -ENOMEM;
  }
  s->is_input = is_input ? 1 : 0;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels;
  s->sample_rate = (unsigned int)(sample_rate <= 0.0 ? 48000.0 : sample_rate);
  s->buffer_frames = 0;
  s->buffer_bytes = 0;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;
  atomic_store(&s->running, 0);
  atomic_store(&s->closed, 0);

  pthread_mutex_init(&s->mu, NULL);
  pthread_cond_init(&s->cv, NULL);
  s->thread_started = 0;

  snd_pcm_stream_t stype = is_input ? SND_PCM_STREAM_CAPTURE : SND_PCM_STREAM_PLAYBACK;
  int err = snd_pcm_open(&s->pcm, device_id, stype, 0);
  if (err < 0) {
    alsa_invoke_error(s, 3 /* snd_pcm_open */, (int32_t)err);
    alsa_stream_destroy(s);
    return err;
  }

  err = alsa_configure_pcm(s->pcm, s->sample_rate, channels, sample_format_tag, buffer_frames);
  if (err < 0) {
    alsa_invoke_error(s, 4 /* snd_pcm_hw_params */, (int32_t)err);
    alsa_stream_destroy(s);
    return err;
  }

  uint32_t period_frames = alsa_current_period_frames(s->pcm);
  if (period_frames == 0) {
    period_frames = requested_frames == 0 ? 512u : requested_frames;
  }
  // Enforce BufferSize::Fixed semantics: if a fixed period was requested and ALSA chose a different
  // period size, treat the config as unsupported rather than silently clamping.
  if (requested_frames != 0 && period_frames != 0 && period_frames != requested_frames) {
    alsa_invoke_error(s, 4 /* snd_pcm_hw_params */, -EINVAL);
    alsa_stream_destroy(s);
    return -EINVAL;
  }
  uint32_t buffer_bytes = period_frames * channels * bps;
  if (buffer_bytes == 0) {
    alsa_invoke_error(s, 4 /* snd_pcm_hw_params */, -EINVAL);
    alsa_stream_destroy(s);
    return -EINVAL;
  }

  s->buffer_frames = period_frames;
  s->buffer_bytes = buffer_bytes;

  s->mb_buffer = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)buffer_bytes, 1);
  if (s->mb_buffer == NULL) {
    alsa_stream_destroy(s);
    return -ENOMEM;
  }

  int perr = pthread_create(&s->thread, NULL, alsa_thread_main, s);
  if (perr != 0) {
    alsa_invoke_error(s, 5 /* pthread_create */, -perr);
    alsa_stream_destroy(s);
    return -perr;
  }
  s->thread_started = 1;

  *out_handle = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_alsa_stream_build_output(uint8_t *device_id_utf8,
                                          int32_t device_id_len,
                                          double sample_rate,
                                          uint32_t channels,
                                          uint32_t sample_format_tag,
                                          uint32_t buffer_frames,
                                          void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t,
                                                                    int64_t, int32_t),
                                          void *data_callback,
                                          void (*call_error_callback)(void *, int32_t, int32_t),
                                          void *error_callback,
                                          uint64_t *out_handles,
                                          int32_t out_len) {
  if (out_handles == NULL || out_len <= 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -EINVAL;
  }
  out_handles[0] = 0;

  // Make a NUL-terminated device id.
  char dev[256];
  memset(dev, 0, sizeof(dev));
  if (device_id_utf8 != NULL && device_id_len > 0) {
    size_t n = (size_t)device_id_len;
    if (n >= sizeof(dev)) {
      n = sizeof(dev) - 1;
    }
    memcpy(dev, device_id_utf8, n);
  } else {
    strncpy(dev, "default", sizeof(dev) - 1);
  }

  // Callee owns `device_id_utf8` param in MoonBit; drop it.
  moonbit_decref(device_id_utf8);

  uint64_t h = 0;
  int err = alsa_stream_new(dev, 0, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                            data_callback, call_error_callback, error_callback, &h);
  if (err < 0) {
    return err;
  }
  out_handles[0] = h;
  return 0;
}

int32_t moon_cpal_alsa_stream_build_input(uint8_t *device_id_utf8,
                                         int32_t device_id_len,
                                         double sample_rate,
                                         uint32_t channels,
                                         uint32_t sample_format_tag,
                                         uint32_t buffer_frames,
                                         void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t,
                                                                   int64_t, int32_t),
                                         void *data_callback,
                                         void (*call_error_callback)(void *, int32_t, int32_t),
                                         void *error_callback,
                                         uint64_t *out_handles,
                                         int32_t out_len) {
  if (out_handles == NULL || out_len <= 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -EINVAL;
  }
  out_handles[0] = 0;

  char dev[256];
  memset(dev, 0, sizeof(dev));
  if (device_id_utf8 != NULL && device_id_len > 0) {
    size_t n = (size_t)device_id_len;
    if (n >= sizeof(dev)) {
      n = sizeof(dev) - 1;
    }
    memcpy(dev, device_id_utf8, n);
  } else {
    strncpy(dev, "default", sizeof(dev) - 1);
  }

  moonbit_decref(device_id_utf8);

  uint64_t h = 0;
  int err = alsa_stream_new(dev, 1, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                            data_callback, call_error_callback, error_callback, &h);
  if (err < 0) {
    return err;
  }
  out_handles[0] = h;
  return 0;
}

static int32_t alsa_stream_play(uint64_t handle) {
  moon_cpal_alsa_stream_t *s = (moon_cpal_alsa_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return -EINVAL;
  }
  atomic_store(&s->running, 1);
  if (s->pcm != NULL) {
    snd_pcm_prepare(s->pcm);
  }
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  return 0;
}

static int32_t alsa_stream_pause(uint64_t handle) {
  moon_cpal_alsa_stream_t *s = (moon_cpal_alsa_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return -EINVAL;
  }
  atomic_store(&s->running, 0);
  if (s->pcm != NULL) {
    // Drop stops the PCM immediately and unblocks blocking I/O.
    snd_pcm_drop(s->pcm);
  }
  return 0;
}

static int32_t alsa_stream_destroy_handle(uint64_t handle) {
  moon_cpal_alsa_stream_t *s = (moon_cpal_alsa_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return 0;
  }
  alsa_stream_destroy(s);
  return 0;
}

typedef struct moon_cpal_alsa_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_alsa_stream_owner_payload_t;

static void moon_cpal_alsa_stream_owner_finalize(void *self) {
  moon_cpal_alsa_stream_owner_payload_t *p = (moon_cpal_alsa_stream_owner_payload_t *)self;
  if (p == NULL) {
    return;
  }
  if (p->handle != 0) {
    alsa_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
}

void *moon_cpal_alsa_stream_owner_new(uint64_t handle) {
  moon_cpal_alsa_stream_owner_payload_t *p = (moon_cpal_alsa_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_alsa_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

static uint64_t alsa_stream_owner_handle(void *owner) {
  moon_cpal_alsa_stream_owner_payload_t *p = (moon_cpal_alsa_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  return p->handle;
}

int32_t moon_cpal_alsa_stream_owner_play(void *owner) {
  uint64_t h = alsa_stream_owner_handle(owner);
  if (h == 0) {
    return -EINVAL;
  }
  return alsa_stream_play(h);
}

int32_t moon_cpal_alsa_stream_owner_pause(void *owner) {
  uint64_t h = alsa_stream_owner_handle(owner);
  if (h == 0) {
    return -EINVAL;
  }
  return alsa_stream_pause(h);
}

int32_t moon_cpal_alsa_stream_owner_close(void *owner) {
  moon_cpal_alsa_stream_owner_payload_t *p = (moon_cpal_alsa_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  if (p->handle != 0) {
    alsa_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
  return 0;
}

#else

// -----------------------------------------------------------------------------
// Non-Linux native builds (stubs)
// -----------------------------------------------------------------------------

int32_t moon_cpal_alsa_stream_build_output(uint8_t *device_id_utf8,
                                          int32_t device_id_len,
                                          double sample_rate,
                                          uint32_t channels,
                                          uint32_t sample_format_tag,
                                          uint32_t buffer_frames,
                                          void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t,
                                                                    int64_t, int32_t),
                                          void *data_callback,
                                          void (*call_error_callback)(void *, int32_t, int32_t),
                                          void *error_callback,
                                          uint64_t *out_handles,
                                          int32_t out_len) {
  (void)device_id_len;
  (void)sample_rate;
  (void)channels;
  (void)sample_format_tag;
  (void)buffer_frames;
  (void)call_data_callback;
  (void)call_error_callback;
  if (out_handles != NULL && out_len > 0) {
    out_handles[0] = 0;
  }
  moonbit_decref(device_id_utf8);
  moonbit_decref(data_callback);
  moonbit_decref(error_callback);
  return -1;
}

int32_t moon_cpal_alsa_stream_build_input(uint8_t *device_id_utf8,
                                         int32_t device_id_len,
                                         double sample_rate,
                                         uint32_t channels,
                                         uint32_t sample_format_tag,
                                         uint32_t buffer_frames,
                                         void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t,
                                                                   int64_t, int32_t),
                                         void *data_callback,
                                         void (*call_error_callback)(void *, int32_t, int32_t),
                                         void *error_callback,
                                         uint64_t *out_handles,
                                         int32_t out_len) {
  (void)device_id_len;
  (void)sample_rate;
  (void)channels;
  (void)sample_format_tag;
  (void)buffer_frames;
  (void)call_data_callback;
  (void)call_error_callback;
  if (out_handles != NULL && out_len > 0) {
    out_handles[0] = 0;
  }
  moonbit_decref(device_id_utf8);
  moonbit_decref(data_callback);
  moonbit_decref(error_callback);
  return -1;
}

typedef struct moon_cpal_alsa_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_alsa_stream_owner_payload_t;

static void moon_cpal_alsa_stream_owner_finalize(void *self) { (void)self; }

void *moon_cpal_alsa_stream_owner_new(uint64_t handle) {
  moon_cpal_alsa_stream_owner_payload_t *p = (moon_cpal_alsa_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_alsa_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

int32_t moon_cpal_alsa_stream_owner_play(void *owner) {
  (void)owner;
  return -1;
}

int32_t moon_cpal_alsa_stream_owner_pause(void *owner) {
  (void)owner;
  return -1;
}

int32_t moon_cpal_alsa_stream_owner_close(void *owner) {
  (void)owner;
  return 0;
}

#endif
