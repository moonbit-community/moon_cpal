#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <avrt.h>

typedef struct moon_cpal_wasapi_stream_t {
  int is_input;
  int is_loopback;
  uint32_t sample_format_tag;
  uint32_t channels;
  double sample_rate;
  uint32_t requested_frames;
  // Optional endpoint id to open (UTF-16). If NULL, use the default endpoint per flow.
  wchar_t *endpoint_id_w;

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
  HANDLE audio_event;

  volatile LONG running;
  volatile LONG closed;
  volatile LONG initialized;
  volatile LONG started;

  HRESULT init_hr;

  // COM/WASAPI objects (owned by the worker thread).
  IMMDeviceEnumerator *enumerator;
  IMMDevice *device;
  IAudioClient *client;
  IAudioRenderClient *render;
  IAudioCaptureClient *capture;
  WAVEFORMATEX *wfx;
  UINT32 buffer_frame_count;

  // Capture accumulation for fixed-size callbacks.
  uint32_t cap_accum_frames;
} moon_cpal_wasapi_stream_t;

static int wasapi_utf8_is_loopback(const char *s) {
  if (s == NULL) {
    return 0;
  }
  return strcmp(s, "loopback") == 0;
}

static wchar_t *wasapi_endpoint_id_from_utf8_bytes(uint8_t *bytes, int32_t len) {
  if (bytes == NULL || len <= 0) {
    return NULL;
  }
  // Ensure NUL-terminated for MultiByteToWideChar.
  char tmp[512];
  size_t n = (size_t)len;
  if (n >= sizeof(tmp)) {
    n = sizeof(tmp) - 1;
  }
  memcpy(tmp, bytes, n);
  tmp[n] = '\0';
  if (tmp[0] == '\0' || wasapi_utf8_is_loopback(tmp)) {
    return NULL;
  }

  int wlen = MultiByteToWideChar(CP_UTF8, 0, tmp, -1, NULL, 0);
  if (wlen <= 0) {
    return NULL;
  }
  wchar_t *ws = (wchar_t *)calloc((size_t)wlen, sizeof(wchar_t));
  if (ws == NULL) {
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, 0, tmp, -1, ws, wlen) <= 0) {
    free(ws);
    return NULL;
  }
  return ws;
}

static uint32_t wasapi_guess_sample_format_tag_from_wfx(const WAVEFORMATEX *wfx) {
  if (wfx == NULL) {
    return 0;
  }
  // Keep this conservative: we only surface F32/I16/U8 to MoonBit today.
  if (wfx->wBitsPerSample == 32) {
    return 1; // F32
  }
  if (wfx->wBitsPerSample == 16) {
    return 2; // I16
  }
  if (wfx->wBitsPerSample == 8) {
    return 4; // U8
  }
  return 0;
}

static void wasapi_now(int64_t *out_secs, int32_t *out_nanos) {
  if (out_secs == NULL || out_nanos == NULL) {
    return;
  }
  static LARGE_INTEGER freq = {0};
  if (freq.QuadPart == 0) {
    QueryPerformanceFrequency(&freq);
  }
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  double secs = (double)now.QuadPart / (double)freq.QuadPart;
  int64_t si = (int64_t)secs;
  double frac = secs - (double)si;
  if (frac < 0.0) {
    frac = 0.0;
  }
  *out_secs = si;
  *out_nanos = (int32_t)(frac * 1000000000.0);
}

static void wasapi_invoke_error(moon_cpal_wasapi_stream_t *s, int32_t op_tag, int32_t status) {
  if (s == NULL || s->call_error_callback == NULL || s->mb_error_callback == NULL) {
    return;
  }
  moonbit_incref(s->mb_error_callback);
  s->call_error_callback(s->mb_error_callback, op_tag, status);
}

static uint32_t wasapi_bytes_per_sample_from_tag(uint32_t tag) {
  switch (tag) {
  case 1:
    return 4;
  case 2:
    return 2;
  case 4:
    return 1;
  default:
    return 0;
  }
}

static HRESULT wasapi_build_wfx(double sample_rate, uint32_t channels, uint32_t sample_format_tag, WAVEFORMATEX **out_wfx) {
  if (out_wfx == NULL || channels == 0) {
    return E_INVALIDARG;
  }
  *out_wfx = NULL;
  uint32_t bps = wasapi_bytes_per_sample_from_tag(sample_format_tag);
  if (bps == 0) {
    return E_INVALIDARG;
  }

  WAVEFORMATEX *wfx = (WAVEFORMATEX *)CoTaskMemAlloc(sizeof(WAVEFORMATEX));
  if (wfx == NULL) {
    return E_OUTOFMEMORY;
  }
  memset(wfx, 0, sizeof(*wfx));

  wfx->nChannels = (WORD)channels;
  wfx->nSamplesPerSec = (DWORD)(sample_rate <= 0.0 ? 48000.0 : sample_rate);
  wfx->wBitsPerSample = (WORD)(bps * 8);
  wfx->nBlockAlign = (WORD)(channels * bps);
  wfx->nAvgBytesPerSec = wfx->nSamplesPerSec * wfx->nBlockAlign;

  if (sample_format_tag == 1) {
    wfx->wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
  } else {
    wfx->wFormatTag = WAVE_FORMAT_PCM;
  }
  wfx->cbSize = 0;

  *out_wfx = wfx;
  return S_OK;
}

static void wasapi_release_objects(moon_cpal_wasapi_stream_t *s) {
  if (s == NULL) {
    return;
  }
  if (s->render) {
    IAudioRenderClient_Release(s->render);
    s->render = NULL;
  }
  if (s->capture) {
    IAudioCaptureClient_Release(s->capture);
    s->capture = NULL;
  }
  if (s->client) {
    IAudioClient_Release(s->client);
    s->client = NULL;
  }
  if (s->device) {
    IMMDevice_Release(s->device);
    s->device = NULL;
  }
  if (s->enumerator) {
    IMMDeviceEnumerator_Release(s->enumerator);
    s->enumerator = NULL;
  }
  if (s->wfx) {
    CoTaskMemFree(s->wfx);
    s->wfx = NULL;
  }
  s->buffer_frame_count = 0;
}

static DWORD WINAPI wasapi_thread_main(LPVOID param) {
  moon_cpal_wasapi_stream_t *s = (moon_cpal_wasapi_stream_t *)param;
  if (s == NULL) {
    return 0;
  }

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 5 /* CoInitializeEx */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    return 0;
  }

  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                        (void **)&s->enumerator);
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    CoUninitialize();
    return 0;
  }

  if (s->endpoint_id_w != NULL) {
    hr = IMMDeviceEnumerator_GetDevice(s->enumerator, s->endpoint_id_w, &s->device);
    if (FAILED(hr) || s->device == NULL) {
      // Fall back to default endpoint if the id is stale/unavailable.
      wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
      // Loopback capture uses a render endpoint but still captures.
      EDataFlow flow = (s->is_input && !s->is_loopback) ? eCapture : eRender;
      hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(s->enumerator, flow, eConsole, &s->device);
    }
  } else {
    EDataFlow flow = (s->is_input && !s->is_loopback) ? eCapture : eRender;
    hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(s->enumerator, flow, eConsole, &s->device);
  }
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  hr = IMMDevice_Activate(s->device, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)&s->client);
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  hr = wasapi_build_wfx(s->sample_rate, s->channels, s->sample_format_tag, &s->wfx);
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  // Shared mode, event callback.
  DWORD stream_flags = AUDCLNT_STREAMFLAGS_EVENTCALLBACK;
  if (s->is_input && s->is_loopback) {
    stream_flags |= AUDCLNT_STREAMFLAGS_LOOPBACK;
  }
  REFERENCE_TIME hns = 0;
  if (s->requested_frames > 0 && s->sample_rate > 0.0) {
    hns = (REFERENCE_TIME)(10000000.0 * ((double)s->requested_frames / s->sample_rate));
  } else {
    // ~10ms default.
    hns = (REFERENCE_TIME)100000;
  }
  hr = IAudioClient_Initialize(s->client, AUDCLNT_SHAREMODE_SHARED, stream_flags, hns, 0, s->wfx, NULL);
  if (FAILED(hr) && s->is_input && s->is_loopback) {
    // Loopback capture is picky about formats; fall back to the device mix format.
    if (s->wfx) {
      CoTaskMemFree(s->wfx);
      s->wfx = NULL;
    }
    hr = IAudioClient_GetMixFormat(s->client, &s->wfx);
    if (SUCCEEDED(hr)) {
      hr = IAudioClient_Initialize(s->client, AUDCLNT_SHAREMODE_SHARED, stream_flags, hns, 0, s->wfx, NULL);
    }
  }
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  hr = IAudioClient_GetBufferSize(s->client, &s->buffer_frame_count);
  if (FAILED(hr) || s->buffer_frame_count == 0) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = FAILED(hr) ? hr : E_FAIL;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  // Enforce BufferSize::Fixed semantics: if the caller requested a fixed callback size larger than
  // the WASAPI buffer, fail initialization rather than silently clamping.
  if (s->requested_frames > 0 && s->requested_frames > s->buffer_frame_count) {
    s->init_hr = AUDCLNT_E_BUFFER_SIZE_ERROR;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  s->frames_per_cb = s->requested_frames > 0 ? s->requested_frames : (s->buffer_frame_count / 2);
  if (s->frames_per_cb == 0) {
    s->frames_per_cb = 1;
  }
  if (s->frames_per_cb > s->buffer_frame_count) {
    s->frames_per_cb = s->buffer_frame_count;
  }

  // Normalize the runtime format to what WASAPI accepted.
  if (s->wfx != NULL) {
    s->channels = (uint32_t)s->wfx->nChannels;
    s->sample_rate = (double)s->wfx->nSamplesPerSec;
    uint32_t tag = wasapi_guess_sample_format_tag_from_wfx(s->wfx);
    if (tag != 0) {
      s->sample_format_tag = tag;
    }
  }

  s->bytes_per_frame = s->channels * wasapi_bytes_per_sample_from_tag(s->sample_format_tag);
  s->buffer_bytes = s->frames_per_cb * s->bytes_per_frame;

  s->mb_buffer = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)s->buffer_bytes, 1);
  if (s->mb_buffer == NULL) {
    s->init_hr = E_OUTOFMEMORY;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  s->audio_event = CreateEventW(NULL, FALSE, FALSE, NULL);
  if (s->audio_event == NULL) {
    s->init_hr = E_FAIL;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }
  hr = IAudioClient_SetEventHandle(s->client, s->audio_event);
  if (FAILED(hr)) {
    wasapi_invoke_error(s, 6 /* DeviceInit */, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    CloseHandle(s->audio_event);
    s->audio_event = NULL;
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  if (s->is_input) {
    hr = IAudioClient_GetService(s->client, &IID_IAudioCaptureClient, (void **)&s->capture);
  } else {
    hr = IAudioClient_GetService(s->client, &IID_IAudioRenderClient, (void **)&s->render);
  }
  if (FAILED(hr)) {
    wasapi_invoke_error(s, s->is_input ? 2 : 1, (int32_t)hr);
    s->init_hr = hr;
    InterlockedExchange(&s->initialized, 1);
    SetEvent(s->wake_event);
    if (s->audio_event) {
      CloseHandle(s->audio_event);
      s->audio_event = NULL;
    }
    wasapi_release_objects(s);
    CoUninitialize();
    return 0;
  }

  s->init_hr = S_OK;
  InterlockedExchange(&s->initialized, 1);
  SetEvent(s->wake_event);

  // Main loop.
  for (;;) {
    if (InterlockedCompareExchange(&s->closed, 0, 0) != 0) {
      break;
    }

    if (InterlockedCompareExchange(&s->running, 0, 0) == 0) {
      // Ensure stopped.
      if (InterlockedCompareExchange(&s->started, 0, 0) != 0 && s->client != NULL) {
        IAudioClient_Stop(s->client);
        InterlockedExchange(&s->started, 0);
      }
      WaitForSingleObject(s->wake_event, 10);
      continue;
    }

    // Start if needed.
    if (InterlockedCompareExchange(&s->started, 0, 0) == 0 && s->client != NULL) {
      hr = IAudioClient_Start(s->client);
      if (FAILED(hr)) {
        wasapi_invoke_error(s, 3 /* Start */, (int32_t)hr);
        InterlockedExchange(&s->running, 0);
        continue;
      }
      InterlockedExchange(&s->started, 1);
    }

    DWORD w = WaitForSingleObject(s->audio_event, 1000);
    if (w != WAIT_OBJECT_0) {
      continue;
    }

    if (s->is_input == 0) {
      UINT32 padding = 0;
      hr = IAudioClient_GetCurrentPadding(s->client, &padding);
      if (FAILED(hr)) {
        wasapi_invoke_error(s, 1, (int32_t)hr);
        continue;
      }
      UINT32 avail = s->buffer_frame_count - padding;
      if (avail < s->frames_per_cb) {
        continue;
      }

      int64_t cb_secs = 0;
      int32_t cb_nanos = 0;
      wasapi_now(&cb_secs, &cb_nanos);
      int64_t pb_secs = cb_secs;
      int32_t pb_nanos = cb_nanos;

      moonbit_incref(s->mb_data_callback);
      moonbit_incref(s->mb_buffer);
      s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos, pb_secs, pb_nanos);

      BYTE *dst = NULL;
      hr = IAudioRenderClient_GetBuffer(s->render, s->frames_per_cb, &dst);
      if (FAILED(hr) || dst == NULL) {
        wasapi_invoke_error(s, 1, (int32_t)hr);
        continue;
      }
      memcpy(dst, s->mb_buffer, s->buffer_bytes);
      hr = IAudioRenderClient_ReleaseBuffer(s->render, s->frames_per_cb, 0);
      if (FAILED(hr)) {
        wasapi_invoke_error(s, 1, (int32_t)hr);
        continue;
      }
    } else {
      // Capture: accumulate into a fixed-size callback buffer.
      for (;;) {
        UINT32 next = 0;
        hr = IAudioCaptureClient_GetNextPacketSize(s->capture, &next);
        if (FAILED(hr) || next == 0) {
          break;
        }

        BYTE *src = NULL;
        UINT32 frames = 0;
        DWORD flags = 0;
        hr = IAudioCaptureClient_GetBuffer(s->capture, &src, &frames, &flags, NULL, NULL);
        if (FAILED(hr)) {
          wasapi_invoke_error(s, 2, (int32_t)hr);
          break;
        }

        uint32_t to_copy = frames;
        uint32_t off_frames = s->cap_accum_frames;
        while (to_copy > 0) {
          uint32_t cap = s->frames_per_cb - off_frames;
          uint32_t n = to_copy < cap ? to_copy : cap;
          size_t off_bytes = (size_t)off_frames * (size_t)s->bytes_per_frame;
          size_t nbytes = (size_t)n * (size_t)s->bytes_per_frame;
          if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0 || src == NULL) {
            memset((uint8_t *)s->mb_buffer + off_bytes, 0, nbytes);
          } else {
            memcpy((uint8_t *)s->mb_buffer + off_bytes, src, nbytes);
            src += nbytes;
          }
          off_frames += n;
          to_copy -= n;

          if (off_frames == s->frames_per_cb) {
            int64_t cb_secs = 0;
            int32_t cb_nanos = 0;
            wasapi_now(&cb_secs, &cb_nanos);
            int64_t cap_secs = cb_secs;
            int32_t cap_nanos = cb_nanos;
            moonbit_incref(s->mb_data_callback);
            moonbit_incref(s->mb_buffer);
            s->call_data_callback(s->mb_data_callback, s->sample_format_tag, s->mb_buffer, cb_secs, cb_nanos, cap_secs, cap_nanos);
            off_frames = 0;
          }
        }
        s->cap_accum_frames = off_frames;

        hr = IAudioCaptureClient_ReleaseBuffer(s->capture, frames);
        if (FAILED(hr)) {
          wasapi_invoke_error(s, 2, (int32_t)hr);
          break;
        }
      }
    }
  }

  if (s->client != NULL) {
    IAudioClient_Stop(s->client);
  }
  if (s->audio_event != NULL) {
    CloseHandle(s->audio_event);
    s->audio_event = NULL;
  }

  wasapi_release_objects(s);
  CoUninitialize();
  return 0;
}

static void wasapi_stream_destroy(moon_cpal_wasapi_stream_t *s) {
  if (s == NULL) {
    return;
  }
  InterlockedExchange(&s->closed, 1);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  if (s->audio_event != NULL) {
    SetEvent(s->audio_event);
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
  if (s->endpoint_id_w != NULL) {
    free(s->endpoint_id_w);
    s->endpoint_id_w = NULL;
  }
  free(s);
}

static int wasapi_stream_new(int is_input,
                             int is_loopback,
                             double sample_rate,
                             uint32_t channels,
                             uint32_t sample_format_tag,
                             uint32_t buffer_frames,
                             wchar_t *endpoint_id_w,
                             void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t, int64_t, int32_t),
                             void *data_callback,
                             void (*call_error_callback)(void *, int32_t, int32_t),
                             void *error_callback,
                             uint64_t *out_handle) {
  if (out_handle == NULL) {
    return -1;
  }
  *out_handle = 0;

  moon_cpal_wasapi_stream_t *s = (moon_cpal_wasapi_stream_t *)calloc(1, sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -1;
  }
  s->is_input = is_input ? 1 : 0;
  s->is_loopback = is_loopback ? 1 : 0;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels;
  s->sample_rate = sample_rate;
  s->requested_frames = buffer_frames == 0 ? 0 : buffer_frames;
  s->endpoint_id_w = endpoint_id_w;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;
  s->running = 0;
  s->closed = 0;
  s->initialized = 0;
  s->started = 0;
  s->init_hr = S_OK;
  s->cap_accum_frames = 0;

  s->wake_event = CreateEventW(NULL, FALSE, FALSE, NULL);
  if (s->wake_event == NULL) {
    wasapi_stream_destroy(s);
    return -1;
  }

  DWORD tid = 0;
  s->thread = CreateThread(NULL, 0, wasapi_thread_main, s, 0, &tid);
  if (s->thread == NULL) {
    wasapi_invoke_error(s, 6, (int32_t)E_FAIL);
    wasapi_stream_destroy(s);
    return -1;
  }

  // Wait for initialization.
  for (;;) {
    if (InterlockedCompareExchange(&s->initialized, 0, 0) != 0) {
      break;
    }
    WaitForSingleObject(s->wake_event, 100);
  }
  if (FAILED(s->init_hr)) {
    int32_t hr = (int32_t)s->init_hr;
    wasapi_stream_destroy(s);
    return hr;
  }

  *out_handle = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_wasapi_stream_build_output(uint8_t *device_id_utf8,
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
  wchar_t *endpoint_id_w = wasapi_endpoint_id_from_utf8_bytes(device_id_utf8, device_id_len);
  // `device_id_utf8` is owned by this function from MoonBit.
  moonbit_decref(device_id_utf8);

  if (out_handles == NULL || out_len <= 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    if (endpoint_id_w != NULL) {
      free(endpoint_id_w);
    }
    return -1;
  }
  out_handles[0] = 0;

  uint64_t h = 0;
  int st = wasapi_stream_new(0, 0, sample_rate, channels, sample_format_tag, buffer_frames, endpoint_id_w, call_data_callback, data_callback,
                             call_error_callback, error_callback, &h);
  if (st < 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

int32_t moon_cpal_wasapi_stream_build_input(uint8_t *device_id_utf8,
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
  int is_loopback = 0;
  {
    // Detect the special "loopback" device id. It's an internal sentinel used by smoke tests to
    // exercise input capture on Windows CI even when no capture endpoints exist.
    //
    // Note: `device_id_utf8` is not NUL-terminated; use a bounded copy.
    char tmp[32];
    size_t n = (device_id_len <= 0) ? 0 : (size_t)device_id_len;
    if (n >= sizeof(tmp)) {
      n = sizeof(tmp) - 1;
    }
    memcpy(tmp, device_id_utf8, n);
    tmp[n] = '\0';
    if (wasapi_utf8_is_loopback(tmp)) {
      is_loopback = 1;
    }
  }

  wchar_t *endpoint_id_w = is_loopback ? NULL : wasapi_endpoint_id_from_utf8_bytes(device_id_utf8, device_id_len);
  moonbit_decref(device_id_utf8);

  if (out_handles == NULL || out_len <= 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    if (endpoint_id_w != NULL) {
      free(endpoint_id_w);
    }
    return -1;
  }
  out_handles[0] = 0;

  uint64_t h = 0;
  int st = wasapi_stream_new(1, is_loopback, sample_rate, channels, sample_format_tag, buffer_frames, endpoint_id_w, call_data_callback, data_callback,
                             call_error_callback, error_callback, &h);
  if (st < 0) {
    return st;
  }
  out_handles[0] = h;
  return 0;
}

static int32_t wasapi_stream_play(uint64_t handle) {
  moon_cpal_wasapi_stream_t *s = (moon_cpal_wasapi_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return -1;
  }
  InterlockedExchange(&s->running, 1);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  return 0;
}

static int32_t wasapi_stream_pause(uint64_t handle) {
  moon_cpal_wasapi_stream_t *s = (moon_cpal_wasapi_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return -1;
  }
  InterlockedExchange(&s->running, 0);
  if (s->wake_event != NULL) {
    SetEvent(s->wake_event);
  }
  return 0;
}

static int32_t wasapi_stream_destroy_handle(uint64_t handle) {
  moon_cpal_wasapi_stream_t *s = (moon_cpal_wasapi_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return 0;
  }
  wasapi_stream_destroy(s);
  return 0;
}

typedef struct moon_cpal_wasapi_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_wasapi_stream_owner_payload_t;

static void moon_cpal_wasapi_stream_owner_finalize(void *self) {
  moon_cpal_wasapi_stream_owner_payload_t *p = (moon_cpal_wasapi_stream_owner_payload_t *)self;
  if (p == NULL) {
    return;
  }
  if (p->handle != 0) {
    wasapi_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
}

void *moon_cpal_wasapi_stream_owner_new(uint64_t handle) {
  moon_cpal_wasapi_stream_owner_payload_t *p = (moon_cpal_wasapi_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_wasapi_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

static uint64_t wasapi_stream_owner_handle(void *owner) {
  moon_cpal_wasapi_stream_owner_payload_t *p = (moon_cpal_wasapi_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  return p->handle;
}

int32_t moon_cpal_wasapi_stream_owner_play(void *owner) {
  uint64_t h = wasapi_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return wasapi_stream_play(h);
}

int32_t moon_cpal_wasapi_stream_owner_pause(void *owner) {
  uint64_t h = wasapi_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return wasapi_stream_pause(h);
}

int32_t moon_cpal_wasapi_stream_owner_close(void *owner) {
  moon_cpal_wasapi_stream_owner_payload_t *p = (moon_cpal_wasapi_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  if (p->handle != 0) {
    wasapi_stream_destroy_handle(p->handle);
    p->handle = 0;
  }
  return 0;
}

#else

// -----------------------------------------------------------------------------
// Non-Windows native builds (stubs)
// -----------------------------------------------------------------------------

int32_t moon_cpal_wasapi_stream_build_output(uint8_t *device_id_utf8,
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

int32_t moon_cpal_wasapi_stream_build_input(uint8_t *device_id_utf8,
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

typedef struct moon_cpal_wasapi_stream_owner_payload_t {
  uint64_t handle;
} moon_cpal_wasapi_stream_owner_payload_t;

static void moon_cpal_wasapi_stream_owner_finalize(void *self) { (void)self; }

void *moon_cpal_wasapi_stream_owner_new(uint64_t handle) {
  moon_cpal_wasapi_stream_owner_payload_t *p = (moon_cpal_wasapi_stream_owner_payload_t *)
      moonbit_make_external_object(moon_cpal_wasapi_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p != NULL) {
    p->handle = handle;
  }
  return p;
}

int32_t moon_cpal_wasapi_stream_owner_play(void *owner) {
  (void)owner;
  return -1;
}

int32_t moon_cpal_wasapi_stream_owner_pause(void *owner) {
  (void)owner;
  return -1;
}

int32_t moon_cpal_wasapi_stream_owner_close(void *owner) {
  (void)owner;
  return 0;
}

#endif
