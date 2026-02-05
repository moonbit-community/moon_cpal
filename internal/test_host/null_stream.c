#include <stdint.h>
#include <stdlib.h>

#include "moonbit.h"

#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdatomic.h>

typedef struct moon_cpal_null_stream_t {
  int is_input;
  uint32_t sample_format_tag;
  uint32_t channels;
  double sample_rate;
  uint32_t frames_per_cb;
  uint32_t bytes_per_frame;
  uint32_t buffer_bytes;

  void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t, int32_t);
  void *mb_data_callback;
  void (*call_error_callback)(void *, int32_t, int32_t);
  void *mb_error_callback;
  moonbit_bytes_t mb_buffer;

  HANDLE thread;
  HANDLE wake_event;

  atomic_int running;
  atomic_int closed;

  atomic_int inject_pending;
  atomic_int inject_after;
  atomic_int inject_op_tag;
  atomic_int inject_status;
  atomic_int inject_sent;

  uint64_t frame_cursor;
  uint32_t period_ms;
  uint32_t cb_count;
} moon_cpal_null_stream_t;

static uint32_t null_bytes_per_sample_from_tag(uint32_t tag) {
  switch (tag) {
  case 1:  // F32
    return 4;
  case 2:  // I16
  case 3:  // U16
    return 2;
  case 4:  // U8
  case 5:  // I8
    return 1;
  case 6:  // I24 (stored in u32)
  case 7:  // U24 (stored in u32)
  case 8:  // I32
  case 9:  // U32
    return 4;
  case 10: // I64
  case 11: // U64
  case 12: // F64
    return 8;
  default:
    return 0;
  }
}

static void null_time_from_frames(uint64_t frames, double sample_rate, int64_t *out_secs, int32_t *out_nanos) {
  if (out_secs == NULL || out_nanos == NULL) {
    return;
  }
  if (sample_rate <= 0.0) {
    *out_secs = 0;
    *out_nanos = 0;
    return;
  }
  double t = (double)frames / sample_rate;
  int64_t si = (int64_t)t;
  double frac = t - (double)si;
  if (frac < 0.0) {
    frac = 0.0;
  }
  *out_secs = si;
  *out_nanos = (int32_t)(frac * 1000000000.0);
}

static DWORD WINAPI null_thread_main(LPVOID p) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)p;
  if (s == NULL) {
    return 0;
  }

  for (;;) {
    if (atomic_load(&s->closed) != 0) {
      break;
    }
    // Wait until running (or wake due to pause/close).
    if (atomic_load(&s->running) == 0) {
      (void)WaitForSingleObject(s->wake_event, INFINITE);
      continue;
    }

    int64_t cb_secs = 0;
    int32_t cb_nanos = 0;
    null_time_from_frames(s->frame_cursor, s->sample_rate, &cb_secs, &cb_nanos);
    // Best-effort: set playback/capture equal to callback time.
    int64_t io_secs = cb_secs;
    int32_t io_nanos = cb_nanos;

    if (s->mb_data_callback != NULL && s->mb_buffer != NULL) {
      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos, io_secs,
                            io_nanos);
    }

    s->cb_count += 1;
    if (atomic_load(&s->inject_pending) != 0 && atomic_load(&s->inject_sent) == 0) {
      int32_t after = atomic_load(&s->inject_after);
      if (after < 0) {
        after = 0;
      }
      if ((int32_t)s->cb_count >= after) {
        atomic_store(&s->inject_sent, 1);
        atomic_store(&s->inject_pending, 0);
        if (s->mb_error_callback != NULL && s->call_error_callback != NULL) {
          int32_t op_tag = atomic_load(&s->inject_op_tag);
          int32_t status = atomic_load(&s->inject_status);
          moonbit_incref(s->mb_error_callback);
          s->call_error_callback(s->mb_error_callback, op_tag, status);
        }
      }
    }

    s->frame_cursor += (uint64_t)s->frames_per_cb;

    // Wait for the next callback period, but allow immediate wake on pause/close.
    (void)WaitForSingleObject(s->wake_event, (DWORD)s->period_ms);
  }

  return 0;
}

static void null_stream_destroy(moon_cpal_null_stream_t *s) {
  if (s == NULL) {
    return;
  }
  atomic_store(&s->closed, 1);
  atomic_store(&s->running, 0);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  if (s->thread != NULL) {
    WaitForSingleObject(s->thread, INFINITE);
    CloseHandle(s->thread);
    s->thread = NULL;
  }
  if (s->wake_event != NULL) {
    CloseHandle(s->wake_event);
    s->wake_event = NULL;
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
  free(s);
}

static int32_t null_stream_new(int is_input,
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
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -22;
  }
  *out_handle = 0;

  uint32_t bps = null_bytes_per_sample_from_tag(sample_format_tag);
  if (bps == 0 || channels == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -22;
  }
  uint32_t frames = buffer_frames == 0 ? 128u : buffer_frames;
  uint32_t buffer_bytes = frames * channels * bps;
  if (buffer_bytes == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -22;
  }

  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)calloc(1, sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -12;
  }
  s->is_input = is_input ? 1 : 0;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels;
  s->sample_rate = sample_rate <= 0.0 ? 48000.0 : sample_rate;
  s->frames_per_cb = frames;
  s->bytes_per_frame = channels * bps;
  s->buffer_bytes = buffer_bytes;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;
  atomic_store(&s->running, 0);
  atomic_store(&s->closed, 0);
  atomic_store(&s->inject_pending, 0);
  atomic_store(&s->inject_after, 0);
  atomic_store(&s->inject_op_tag, 0);
  atomic_store(&s->inject_status, 0);
  atomic_store(&s->inject_sent, 0);
  s->frame_cursor = 0;
  s->cb_count = 0;

  // Choose a conservative callback period for tests.
  double ms = ((double)frames * 1000.0) / s->sample_rate;
  if (ms < 1.0) {
    ms = 1.0;
  }
  if (ms > 10.0) {
    ms = 10.0;
  }
  s->period_ms = (uint32_t)ms;

  s->mb_buffer = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)buffer_bytes, 1);
  if (s->mb_buffer == NULL) {
    null_stream_destroy(s);
    return -12;
  }

  s->wake_event = CreateEventW(NULL, FALSE, FALSE, NULL);
  if (s->wake_event == NULL) {
    null_stream_destroy(s);
    return -1;
  }

  DWORD tid = 0;
  s->thread = CreateThread(NULL, 0, null_thread_main, s, 0, &tid);
  if (s->thread == NULL) {
    null_stream_destroy(s);
    return -1;
  }

  *out_handle = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_null_stream_build_output(double sample_rate,
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
    return -22;
  }
  out_handles[0] = 0;
  uint64_t h = 0;
  int32_t st = null_stream_new(0, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                               data_callback, call_error_callback, error_callback, &h);
  if (st != 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

int32_t moon_cpal_null_stream_build_input(double sample_rate,
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
    return -22;
  }
  out_handles[0] = 0;
  uint64_t h = 0;
  int32_t st = null_stream_new(1, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                               data_callback, call_error_callback, error_callback, &h);
  if (st != 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

static int32_t null_stream_play(uint64_t handle) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL || atomic_load(&s->closed) != 0) {
    return -1;
  }
  atomic_store(&s->running, 1);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  return 0;
}

static int32_t null_stream_pause(uint64_t handle) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL || atomic_load(&s->closed) != 0) {
    return -1;
  }
  atomic_store(&s->running, 0);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  return 0;
}

static int32_t null_stream_destroy_handle(uint64_t handle) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return 0;
  }
  null_stream_destroy(s);
  return 0;
}

static int32_t null_stream_inject_error(uint64_t handle, int32_t after_callbacks, int32_t op_tag, int32_t status) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL || atomic_load(&s->closed) != 0) {
    return -1;
  }
  atomic_store(&s->inject_after, after_callbacks);
  atomic_store(&s->inject_op_tag, op_tag);
  atomic_store(&s->inject_status, status);
  atomic_store(&s->inject_sent, 0);
  atomic_store(&s->inject_pending, 1);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  return 0;
}

typedef struct moon_cpal_null_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_null_stream_owner_payload_t;

static void moon_cpal_null_stream_owner_finalize(void *self) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)self;
  if (p == NULL) {
    return;
  }
  if (p->handle != 0) {
    null_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
}

void *moon_cpal_null_stream_owner_new(uint64_t handle) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_null_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

static uint64_t null_stream_owner_handle(void *owner) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  return p->handle;
}

int32_t moon_cpal_null_stream_owner_play(void *owner) {
  uint64_t h = null_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return null_stream_play(h);
}

int32_t moon_cpal_null_stream_owner_pause(void *owner) {
  uint64_t h = null_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return null_stream_pause(h);
}

int32_t moon_cpal_null_stream_owner_close(void *owner) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  if (p->handle != 0) {
    null_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
  return 0;
}

int32_t moon_cpal_null_stream_owner_inject_error(void *owner, int32_t after_callbacks, int32_t op_tag, int32_t status) {
  uint64_t h = null_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return null_stream_inject_error(h, after_callbacks, op_tag, status);
}

#else

#include <pthread.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <stdatomic.h>

typedef struct moon_cpal_null_stream_t {
  int is_input;
  uint32_t sample_format_tag;
  uint32_t channels;
  double sample_rate;
  uint32_t frames_per_cb;
  uint32_t bytes_per_frame;
  uint32_t buffer_bytes;

  void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t, int32_t);
  void *mb_data_callback;
  void (*call_error_callback)(void *, int32_t, int32_t);
  void *mb_error_callback;
  moonbit_bytes_t mb_buffer;

  pthread_t thread;
  pthread_mutex_t mu;
  pthread_cond_t cv;

  atomic_int running;
  atomic_int closed;

  atomic_int inject_pending;
  atomic_int inject_after;
  atomic_int inject_op_tag;
  atomic_int inject_status;
  atomic_int inject_sent;

  uint64_t frame_cursor;
  uint32_t period_ms;
  uint32_t cb_count;
  int thread_started;
} moon_cpal_null_stream_t;

static uint32_t null_bytes_per_sample_from_tag(uint32_t tag) {
  switch (tag) {
  case 1:
    return 4;
  case 2:
  case 3:
    return 2;
  case 4:
  case 5:
    return 1;
  case 6:
  case 7:
  case 8:
  case 9:
    return 4;
  case 10:
  case 11:
  case 12:
    return 8;
  default:
    return 0;
  }
}

static void null_time_from_frames(uint64_t frames, double sample_rate, int64_t *out_secs, int32_t *out_nanos) {
  if (out_secs == NULL || out_nanos == NULL) {
    return;
  }
  if (sample_rate <= 0.0) {
    *out_secs = 0;
    *out_nanos = 0;
    return;
  }
  double t = (double)frames / sample_rate;
  int64_t si = (int64_t)t;
  double frac = t - (double)si;
  if (frac < 0.0) {
    frac = 0.0;
  }
  *out_secs = si;
  *out_nanos = (int32_t)(frac * 1000000000.0);
}

static void timespec_add_ms(struct timespec *ts, uint32_t ms) {
  if (ts == NULL) {
    return;
  }
  ts->tv_sec += (time_t)(ms / 1000);
  ts->tv_nsec += (long)((ms % 1000) * 1000000L);
  if (ts->tv_nsec >= 1000000000L) {
    ts->tv_sec += 1;
    ts->tv_nsec -= 1000000000L;
  }
}

static void *null_thread_main(void *p) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)p;
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

    int64_t cb_secs = 0;
    int32_t cb_nanos = 0;
    null_time_from_frames(s->frame_cursor, s->sample_rate, &cb_secs, &cb_nanos);
    int64_t io_secs = cb_secs;
    int32_t io_nanos = cb_nanos;

    if (s->mb_data_callback != NULL && s->mb_buffer != NULL) {
      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos, io_secs,
                            io_nanos);
    }

    s->cb_count += 1;
    if (atomic_load(&s->inject_pending) != 0 && atomic_load(&s->inject_sent) == 0) {
      int32_t after = atomic_load(&s->inject_after);
      if (after < 0) {
        after = 0;
      }
      if ((int32_t)s->cb_count >= after) {
        atomic_store(&s->inject_sent, 1);
        atomic_store(&s->inject_pending, 0);
        if (s->mb_error_callback != NULL && s->call_error_callback != NULL) {
          int32_t op_tag = atomic_load(&s->inject_op_tag);
          int32_t status = atomic_load(&s->inject_status);
          moonbit_incref(s->mb_error_callback);
          s->call_error_callback(s->mb_error_callback, op_tag, status);
        }
      }
    }

    s->frame_cursor += (uint64_t)s->frames_per_cb;

    // Timed wait for period_ms, wakeable by play/pause/close.
    pthread_mutex_lock(&s->mu);
    if (atomic_load(&s->closed) == 0 && atomic_load(&s->running) != 0) {
      struct timespec ts;
      memset(&ts, 0, sizeof(ts));
      clock_gettime(CLOCK_REALTIME, &ts);
      timespec_add_ms(&ts, s->period_ms);
      (void)pthread_cond_timedwait(&s->cv, &s->mu, &ts);
    }
    pthread_mutex_unlock(&s->mu);
  }

  return NULL;
}

static void null_stream_destroy(moon_cpal_null_stream_t *s) {
  if (s == NULL) {
    return;
  }
  atomic_store(&s->closed, 1);
  atomic_store(&s->running, 0);

  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);

  if (s->thread_started) {
    pthread_join(s->thread, NULL);
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

static int32_t null_stream_new(int is_input,
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
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -22;
  }
  *out_handle = 0;

  uint32_t bps = null_bytes_per_sample_from_tag(sample_format_tag);
  if (bps == 0 || channels == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -22;
  }
  uint32_t frames = buffer_frames == 0 ? 128u : buffer_frames;
  uint32_t buffer_bytes = frames * channels * bps;
  if (buffer_bytes == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -22;
  }

  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)calloc(1, sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -12;
  }
  s->is_input = is_input ? 1 : 0;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels;
  s->sample_rate = sample_rate <= 0.0 ? 48000.0 : sample_rate;
  s->frames_per_cb = frames;
  s->bytes_per_frame = channels * bps;
  s->buffer_bytes = buffer_bytes;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;
  atomic_store(&s->running, 0);
  atomic_store(&s->closed, 0);
  atomic_store(&s->inject_pending, 0);
  atomic_store(&s->inject_after, 0);
  atomic_store(&s->inject_op_tag, 0);
  atomic_store(&s->inject_status, 0);
  atomic_store(&s->inject_sent, 0);
  s->frame_cursor = 0;
  s->cb_count = 0;
  s->thread_started = 0;

  // Choose a conservative callback period for tests.
  double ms = ((double)frames * 1000.0) / s->sample_rate;
  if (ms < 1.0) {
    ms = 1.0;
  }
  if (ms > 10.0) {
    ms = 10.0;
  }
  s->period_ms = (uint32_t)ms;

  (void)pthread_mutex_init(&s->mu, NULL);
  (void)pthread_cond_init(&s->cv, NULL);

  s->mb_buffer = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)buffer_bytes, 1);
  if (s->mb_buffer == NULL) {
    null_stream_destroy(s);
    return -12;
  }

  int perr = pthread_create(&s->thread, NULL, null_thread_main, s);
  if (perr != 0) {
    null_stream_destroy(s);
    return -1;
  }
  s->thread_started = 1;

  *out_handle = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_null_stream_build_output(double sample_rate,
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
    return -22;
  }
  out_handles[0] = 0;
  uint64_t h = 0;
  int32_t st = null_stream_new(0, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                               data_callback, call_error_callback, error_callback, &h);
  if (st != 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

int32_t moon_cpal_null_stream_build_input(double sample_rate,
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
    return -22;
  }
  out_handles[0] = 0;
  uint64_t h = 0;
  int32_t st = null_stream_new(1, sample_rate, channels, sample_format_tag, buffer_frames, call_data_callback,
                               data_callback, call_error_callback, error_callback, &h);
  if (st != 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

static int32_t null_stream_play(uint64_t handle) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL || atomic_load(&s->closed) != 0) {
    return -1;
  }
  atomic_store(&s->running, 1);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  return 0;
}

static int32_t null_stream_pause(uint64_t handle) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL || atomic_load(&s->closed) != 0) {
    return -1;
  }
  atomic_store(&s->running, 0);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  return 0;
}

static int32_t null_stream_destroy_handle(uint64_t handle) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return 0;
  }
  null_stream_destroy(s);
  return 0;
}

static int32_t null_stream_inject_error(uint64_t handle, int32_t after_callbacks, int32_t op_tag, int32_t status) {
  moon_cpal_null_stream_t *s = (moon_cpal_null_stream_t *)(uintptr_t)handle;
  if (s == NULL || atomic_load(&s->closed) != 0) {
    return -1;
  }
  atomic_store(&s->inject_after, after_callbacks);
  atomic_store(&s->inject_op_tag, op_tag);
  atomic_store(&s->inject_status, status);
  atomic_store(&s->inject_sent, 0);
  atomic_store(&s->inject_pending, 1);
  pthread_mutex_lock(&s->mu);
  pthread_cond_broadcast(&s->cv);
  pthread_mutex_unlock(&s->mu);
  return 0;
}

typedef struct moon_cpal_null_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_null_stream_owner_payload_t;

static void moon_cpal_null_stream_owner_finalize(void *self) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)self;
  if (p == NULL) {
    return;
  }
  if (p->handle != 0) {
    null_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
}

void *moon_cpal_null_stream_owner_new(uint64_t handle) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_null_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

static uint64_t null_stream_owner_handle(void *owner) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  return p->handle;
}

int32_t moon_cpal_null_stream_owner_play(void *owner) {
  uint64_t h = null_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return null_stream_play(h);
}

int32_t moon_cpal_null_stream_owner_pause(void *owner) {
  uint64_t h = null_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return null_stream_pause(h);
}

int32_t moon_cpal_null_stream_owner_close(void *owner) {
  moon_cpal_null_stream_owner_payload_t *p = (moon_cpal_null_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  if (p->handle != 0) {
    null_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
  return 0;
}

int32_t moon_cpal_null_stream_owner_inject_error(void *owner, int32_t after_callbacks, int32_t op_tag, int32_t status) {
  uint64_t h = null_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return null_stream_inject_error(h, after_callbacks, op_tag, status);
}

#endif
