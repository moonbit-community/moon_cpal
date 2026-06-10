#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#if defined(__linux__)

#include <jack/jack.h>
#include <jack/ringbuffer.h>

#include <errno.h>
#include <pthread.h>
#include <stdatomic.h>
#include <time.h>

typedef struct moon_cpal_jack_stream_t {
  int is_input;
  uint32_t sample_format_tag; // 1 = f32
  uint32_t channels;
  double sample_rate;
  uint32_t frames_per_cb;
  uint32_t bytes_per_frame;
  uint32_t buffer_bytes;

  jack_client_t *client;
  jack_port_t **ports;              // [channels]
  jack_ringbuffer_t **rb_per_chan;  // [channels]

  void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t, int32_t);
  void *mb_data_callback;
  void (*call_error_callback)(void *, int32_t, int32_t);
  void *mb_error_callback;
  moonbit_bytes_t mb_buffer; // interleaved float bytes, buffer_bytes

  pthread_t thread;
  pthread_mutex_t mu;
  pthread_cond_t cv;

  atomic_int running;
  atomic_int closed;
  atomic_int xrun_pending;
  atomic_int shutdown_pending;
  atomic_int sample_rate_init_seen;
  atomic_int sample_rate_changed_pending;
  atomic_uint pending_sample_rate;
} moon_cpal_jack_stream_t;

static void jack_now(int64_t *out_secs, int32_t *out_nanos) {
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

static void jack_invoke_error(moon_cpal_jack_stream_t *s, int32_t op_tag, int32_t status) {
  if (s == NULL || s->call_error_callback == NULL || s->mb_error_callback == NULL) {
    return;
  }
  moonbit_incref(s->mb_error_callback);
  s->call_error_callback(s->mb_error_callback, op_tag, status);
}

static int jack_xrun_cb(void *arg) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)arg;
  if (s != NULL) {
    atomic_store(&s->xrun_pending, 1);
  }
  return 0;
}

static int jack_sample_rate_cb(jack_nframes_t nframes, void *arg) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)arg;
  if (s == NULL) {
    return 0;
  }
  // JACK fires one sample-rate callback when a client starts. Mirror upstream behavior:
  // ignore the first call, then treat subsequent calls as stream invalidation.
  if (atomic_exchange(&s->sample_rate_init_seen, 1) == 0) {
    return 0;
  }
  atomic_store(&s->pending_sample_rate, (unsigned)nframes);
  atomic_store(&s->sample_rate_changed_pending, 1);
  return 0;
}

static void jack_shutdown_cb(void *arg) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)arg;
  if (s == NULL) {
    return;
  }
  atomic_store(&s->shutdown_pending, 1);
  atomic_store(&s->closed, 1);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
}

static uint32_t jack_rb_size_bytes(uint32_t frames_per_cb) {
  // Keep ~8 callbacks worth of buffering per channel.
  uint32_t frames = frames_per_cb;
  if (frames < 256) {
    frames = 256;
  }
  uint32_t want = frames * 8;
  // Each frame is one float per channel in per-channel ringbuffer.
  return want * 4;
}

static int jack_register_ports(moon_cpal_jack_stream_t *s) {
  if (s == NULL || s->client == NULL || s->channels == 0) {
    return -EINVAL;
  }
  s->ports = (jack_port_t **)calloc((size_t)s->channels, sizeof(jack_port_t *));
  if (s->ports == NULL) {
    return -ENOMEM;
  }
  const unsigned long flags = s->is_input ? JackPortIsInput : JackPortIsOutput;
  for (uint32_t ch = 0; ch < s->channels; ch++) {
    char name[64];
    snprintf(name, sizeof(name), "%s_%u", s->is_input ? "in" : "out", (unsigned)(ch + 1));
    jack_port_t *p = jack_port_register(s->client, name, JACK_DEFAULT_AUDIO_TYPE, flags, 0);
    if (p == NULL) {
      return -1;
    }
    s->ports[ch] = p;
  }
  return 0;
}

static void jack_try_autoconnect(moon_cpal_jack_stream_t *s) {
  if (s == NULL || s->client == NULL || s->ports == NULL) {
    return;
  }

  if (s->is_input == 0) {
    // Connect our outputs -> physical playback inputs.
    const char **dsts = jack_get_ports(s->client, NULL, NULL,
                                      JackPortIsPhysical | JackPortIsInput);
    if (dsts == NULL) {
      return;
    }
    for (uint32_t ch = 0; ch < s->channels; ch++) {
      const char *dst = dsts[ch];
      if (dst == NULL) {
        break;
      }
      const char *src = jack_port_name(s->ports[ch]);
      if (src != NULL && dst != NULL) {
        (void)jack_connect(s->client, src, dst);
      }
    }
    jack_free(dsts);
  } else {
    // Connect physical capture outputs -> our inputs.
    const char **srcs = jack_get_ports(s->client, NULL, NULL,
                                      JackPortIsPhysical | JackPortIsOutput);
    if (srcs == NULL) {
      return;
    }
    for (uint32_t ch = 0; ch < s->channels; ch++) {
      const char *src = srcs[ch];
      if (src == NULL) {
        break;
      }
      const char *dst = jack_port_name(s->ports[ch]);
      if (src != NULL && dst != NULL) {
        (void)jack_connect(s->client, src, dst);
      }
    }
    jack_free(srcs);
  }
}

static int jack_process(jack_nframes_t nframes, void *arg) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)arg;
  if (s == NULL || s->ports == NULL || s->rb_per_chan == NULL) {
    return 0;
  }

  const size_t need_bytes = (size_t)nframes * 4;

  if (s->is_input == 0) {
    // Render: ringbuffer -> JACK buffers.
    for (uint32_t ch = 0; ch < s->channels; ch++) {
      float *dst = (float *)jack_port_get_buffer(s->ports[ch], nframes);
      if (dst == NULL) {
        continue;
      }
      jack_ringbuffer_t *rb = s->rb_per_chan[ch];
      if (rb == NULL) {
        memset(dst, 0, need_bytes);
        continue;
      }
      size_t avail = jack_ringbuffer_read_space(rb);
      if (avail >= need_bytes) {
        (void)jack_ringbuffer_read(rb, (char *)dst, need_bytes);
      } else {
        // Underflow: read what we can, zero the rest.
        if (avail > 0) {
          (void)jack_ringbuffer_read(rb, (char *)dst, avail);
        }
        memset(((uint8_t *)dst) + avail, 0, need_bytes - avail);
      }
    }
  } else {
    // Capture: JACK buffers -> ringbuffer.
    for (uint32_t ch = 0; ch < s->channels; ch++) {
      const float *src = (const float *)jack_port_get_buffer(s->ports[ch], nframes);
      if (src == NULL) {
        continue;
      }
      jack_ringbuffer_t *rb = s->rb_per_chan[ch];
      if (rb == NULL) {
        continue;
      }
      size_t space = jack_ringbuffer_write_space(rb);
      if (space >= need_bytes) {
        (void)jack_ringbuffer_write(rb, (const char *)src, need_bytes);
      } else {
        // Overflow: drop.
      }
    }
  }

  return 0;
}

static void *jack_thread_main(void *p) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)p;
  if (s == NULL) {
    return NULL;
  }

  // ~1ms sleep between polling iterations.
  struct timespec nap;
  nap.tv_sec = 0;
  nap.tv_nsec = 1000000;

  const uint32_t frames = s->frames_per_cb;
  const size_t chan_need = (size_t)frames * 4;

  for (;;) {
    pthread_mutex_lock(&s->mu);
    while (atomic_load(&s->running) == 0 && atomic_load(&s->closed) == 0) {
      pthread_cond_wait(&s->cv, &s->mu);
    }
    pthread_mutex_unlock(&s->mu);

    if (atomic_exchange(&s->shutdown_pending, 0) != 0) {
      jack_invoke_error(s, 7, 0);
      break;
    }
    if (atomic_load(&s->closed) != 0) {
      break;
    }

    if (atomic_exchange(&s->xrun_pending, 0) != 0) {
      // Mirror upstream: report xrun as BufferUnderrun.
      jack_invoke_error(s, 5, 0);
    }
    if (atomic_exchange(&s->sample_rate_changed_pending, 0) != 0) {
      // Mirror upstream: changing sample rate invalidates the stream.
      jack_invoke_error(s, 6, (int32_t)atomic_load(&s->pending_sample_rate));
      atomic_store(&s->closed, 1);
      break;
    }

    if (s->mb_buffer == NULL || s->rb_per_chan == NULL) {
      jack_invoke_error(s, 0, -EINVAL);
      break;
    }

    if (s->is_input == 0) {
      // Output: MoonBit callback -> ringbuffers.
      // Backpressure: only call if we have enough space in all channels.
      int ok = 1;
      for (uint32_t ch = 0; ch < s->channels; ch++) {
        if (jack_ringbuffer_write_space(s->rb_per_chan[ch]) < chan_need) {
          ok = 0;
          break;
        }
      }
      if (!ok) {
        nanosleep(&nap, NULL);
        continue;
      }

      int64_t cb_secs = 0;
      int32_t cb_nanos = 0;
      jack_now(&cb_secs, &cb_nanos);
      int64_t pb_secs = cb_secs;
      int32_t pb_nanos = cb_nanos;

      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos, pb_secs, pb_nanos);

      // Deinterleave into per-channel ringbuffers (float32 LE).
      const float *inter = (const float *)s->mb_buffer;
      for (uint32_t f = 0; f < frames; f++) {
        for (uint32_t ch = 0; ch < s->channels; ch++) {
          const float v = inter[(size_t)f * (size_t)s->channels + (size_t)ch];
          (void)jack_ringbuffer_write(s->rb_per_chan[ch], (const char *)&v, 4);
        }
      }
    } else {
      // Input: ringbuffers -> MoonBit callback.
      int ok = 1;
      for (uint32_t ch = 0; ch < s->channels; ch++) {
        if (jack_ringbuffer_read_space(s->rb_per_chan[ch]) < chan_need) {
          ok = 0;
          break;
        }
      }
      if (!ok) {
        nanosleep(&nap, NULL);
        continue;
      }

      float *inter = (float *)s->mb_buffer;
      for (uint32_t f = 0; f < frames; f++) {
        for (uint32_t ch = 0; ch < s->channels; ch++) {
          float v = 0.0f;
          (void)jack_ringbuffer_read(s->rb_per_chan[ch], (char *)&v, 4);
          inter[(size_t)f * (size_t)s->channels + (size_t)ch] = v;
        }
      }

      int64_t cb_secs = 0;
      int32_t cb_nanos = 0;
      jack_now(&cb_secs, &cb_nanos);
      int64_t cap_secs = cb_secs;
      int32_t cap_nanos = cb_nanos;

      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos, cap_secs, cap_nanos);
    }
  }

  return NULL;
}

static void jack_stream_destroy(moon_cpal_jack_stream_t *s) {
  if (s == NULL) {
    return;
  }
  atomic_store(&s->closed, 1);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);

  if (s->thread) {
    pthread_join(s->thread, NULL);
    s->thread = 0;
  }

  if (s->client != NULL) {
    (void)jack_deactivate(s->client);
    jack_client_close(s->client);
    s->client = NULL;
  }

  if (s->rb_per_chan != NULL) {
    for (uint32_t ch = 0; ch < s->channels; ch++) {
      if (s->rb_per_chan[ch] != NULL) {
        jack_ringbuffer_free(s->rb_per_chan[ch]);
      }
    }
    free(s->rb_per_chan);
    s->rb_per_chan = NULL;
  }

  if (s->ports != NULL) {
    free(s->ports);
    s->ports = NULL;
  }

  pthread_mutex_destroy(&s->mu);
  pthread_cond_destroy(&s->cv);

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

  free(s);
}

static int jack_stream_new(int is_input,
                           const char *client_name,
                           double sample_rate,
                           uint32_t channels,
                           uint32_t sample_format_tag,
                           uint32_t buffer_frames,
                           void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t, int32_t),
                           void *data_callback,
                           void (*call_error_callback)(void *, int32_t, int32_t),
                           void *error_callback,
                           uint64_t *out_handle) {
  if (out_handle == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -EINVAL;
  }
  *out_handle = 0;

  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)calloc(1, sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -ENOMEM;
  }

  s->is_input = is_input ? 1 : 0;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels == 0 ? 2 : channels;
  s->sample_rate = sample_rate;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;
  atomic_store(&s->running, 0);
  atomic_store(&s->closed, 0);
  atomic_store(&s->xrun_pending, 0);
  atomic_store(&s->shutdown_pending, 0);
  atomic_store(&s->sample_rate_init_seen, 0);
  atomic_store(&s->sample_rate_changed_pending, 0);
  atomic_store(&s->pending_sample_rate, 0U);

  pthread_mutex_init(&s->mu, NULL);
  pthread_cond_init(&s->cv, NULL);

  jack_status_t status = 0;
  const char *name = (client_name != NULL && client_name[0] != '\0') ? client_name : "moon_cpal";
  s->client = jack_client_open(name, JackNoStartServer, &status);
  if (s->client == NULL) {
    jack_invoke_error(s, 1, (int32_t)status);
    jack_stream_destroy(s);
    return -ENODEV;
  }

  (void)jack_set_xrun_callback(s->client, jack_xrun_cb, s);
  (void)jack_set_sample_rate_callback(s->client, jack_sample_rate_cb, s);
  jack_on_shutdown(s->client, jack_shutdown_cb, s);

  s->sample_rate = (double)jack_get_sample_rate(s->client);
  uint32_t period = (uint32_t)jack_get_buffer_size(s->client);
  // JACK buffer size is controlled by the server and cannot be changed by clients.
  // Always use the server period here; `BufferSize::Fixed` validation happens in MoonBit.
  (void)buffer_frames;
  s->frames_per_cb = period;
  if (s->frames_per_cb == 0) {
    s->frames_per_cb = 64;
  }
  s->bytes_per_frame = s->channels * 4;
  s->buffer_bytes = s->frames_per_cb * s->bytes_per_frame;

  s->mb_buffer = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)s->buffer_bytes, 1);
  if (s->mb_buffer == NULL) {
    jack_stream_destroy(s);
    return -ENOMEM;
  }

  if (jack_set_process_callback(s->client, jack_process, s) != 0) {
    jack_invoke_error(s, 4, -1);
    jack_stream_destroy(s);
    return -EIO;
  }

  if (jack_register_ports(s) != 0) {
    jack_invoke_error(s, 3, -1);
    jack_stream_destroy(s);
    return -EIO;
  }

  s->rb_per_chan = (jack_ringbuffer_t **)calloc((size_t)s->channels, sizeof(jack_ringbuffer_t *));
  if (s->rb_per_chan == NULL) {
    jack_stream_destroy(s);
    return -ENOMEM;
  }
  for (uint32_t ch = 0; ch < s->channels; ch++) {
    s->rb_per_chan[ch] = jack_ringbuffer_create(jack_rb_size_bytes(s->frames_per_cb));
    if (s->rb_per_chan[ch] == NULL) {
      jack_stream_destroy(s);
      return -ENOMEM;
    }
  }

  if (jack_activate(s->client) != 0) {
    jack_invoke_error(s, 2, -1);
    jack_stream_destroy(s);
    return -EIO;
  }

  jack_try_autoconnect(s);

  int perr = pthread_create(&s->thread, NULL, jack_thread_main, s);
  if (perr != 0) {
    jack_invoke_error(s, 0, -perr);
    jack_stream_destroy(s);
    return -perr;
  }

  *out_handle = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_jack_stream_build_output(uint8_t *device_id_utf8,
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
  char name_buf[128];
  const char *name = NULL;
  size_t n = (size_t)(device_id_len < 0 ? 0 : device_id_len);
  if (device_id_utf8 != NULL && n > 0) {
    if (n >= sizeof(name_buf)) {
      n = sizeof(name_buf) - 1;
    }
    memcpy(name_buf, device_id_utf8, n);
    name_buf[n] = '\0';
    name = name_buf;
  }
  moonbit_decref(device_id_utf8);

  if (out_handles == NULL || out_len <= 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -1;
  }
  out_handles[0] = 0;

  uint64_t h = 0;
  int st = jack_stream_new(0, name, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                           data_callback, call_error_callback, error_callback, &h);
  if (st < 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

int32_t moon_cpal_jack_stream_build_input(uint8_t *device_id_utf8,
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
  char name_buf[128];
  const char *name = NULL;
  size_t n = (size_t)(device_id_len < 0 ? 0 : device_id_len);
  if (device_id_utf8 != NULL && n > 0) {
    if (n >= sizeof(name_buf)) {
      n = sizeof(name_buf) - 1;
    }
    memcpy(name_buf, device_id_utf8, n);
    name_buf[n] = '\0';
    name = name_buf;
  }
  moonbit_decref(device_id_utf8);

  if (out_handles == NULL || out_len <= 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -1;
  }
  out_handles[0] = 0;

  uint64_t h = 0;
  int st = jack_stream_new(1, name, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                           data_callback, call_error_callback, error_callback, &h);
  if (st < 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

static int32_t jack_stream_play(uint64_t handle) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return -1;
  }
  atomic_store(&s->running, 1);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  return 0;
}

static int32_t jack_stream_pause(uint64_t handle) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return -1;
  }
  atomic_store(&s->running, 0);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  return 0;
}

static int32_t jack_stream_destroy_handle(uint64_t handle) {
  moon_cpal_jack_stream_t *s = (moon_cpal_jack_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return 0;
  }
  jack_stream_destroy(s);
  return 0;
}

typedef struct moon_cpal_jack_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_jack_stream_owner_payload_t;

static void moon_cpal_jack_stream_owner_finalize(void *self) {
  moon_cpal_jack_stream_owner_payload_t *p = (moon_cpal_jack_stream_owner_payload_t *)self;
  if (p == NULL) {
    return;
  }
  if (p->handle != 0) {
    jack_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
}

void *moon_cpal_jack_stream_owner_new(uint64_t handle) {
  moon_cpal_jack_stream_owner_payload_t *p = (moon_cpal_jack_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_jack_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

static uint64_t jack_stream_owner_handle(void *owner) {
  moon_cpal_jack_stream_owner_payload_t *p = (moon_cpal_jack_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  return p->handle;
}

int32_t moon_cpal_jack_stream_owner_play(void *owner) {
  uint64_t h = jack_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return jack_stream_play(h);
}

int32_t moon_cpal_jack_stream_owner_pause(void *owner) {
  uint64_t h = jack_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return jack_stream_pause(h);
}

int32_t moon_cpal_jack_stream_owner_close(void *owner) {
  moon_cpal_jack_stream_owner_payload_t *p = (moon_cpal_jack_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  if (p->handle != 0) {
    jack_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
  return 0;
}

#else

// Non-Linux native builds: stubs.

int32_t moon_cpal_jack_stream_build_output(uint8_t *device_id_utf8,
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

int32_t moon_cpal_jack_stream_build_input(uint8_t *device_id_utf8,
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

typedef struct moon_cpal_jack_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_jack_stream_owner_payload_t;

static void moon_cpal_jack_stream_owner_finalize(void *self) { (void)self; }

void *moon_cpal_jack_stream_owner_new(uint64_t handle) {
  moon_cpal_jack_stream_owner_payload_t *p = (moon_cpal_jack_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_jack_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

int32_t moon_cpal_jack_stream_owner_play(void *owner) {
  (void)owner;
  return -1;
}

int32_t moon_cpal_jack_stream_owner_pause(void *owner) {
  (void)owner;
  return -1;
}

int32_t moon_cpal_jack_stream_owner_close(void *owner) {
  (void)owner;
  return 0;
}

#endif
