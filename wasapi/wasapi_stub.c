#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

// -----------------------------------------------------------------------------
// WASAPI device discovery + friendly name (Windows)
// -----------------------------------------------------------------------------
//
// Exported device list format: UTF-8, newline-separated device IDs.
//
// Device IDs are endpoint IDs from `IMMDevice::GetId` (UTF-16 -> UTF-8).
// We also include a synthetic "default" id at the top to match upstream-ish UX.

static void buf_reserve(char **buf, size_t *cap, size_t need) {
  if (*cap >= need) {
    return;
  }
  size_t ncap = (*cap == 0) ? 256 : *cap;
  while (ncap < need) {
    ncap *= 2;
  }
  char *nbuf = (char *)realloc(*buf, ncap);
  if (nbuf == NULL) {
    return;
  }
  *buf = nbuf;
  *cap = ncap;
}

static void buf_append(char **buf, size_t *len, size_t *cap, const char *s, size_t slen) {
  if (slen == 0) {
    return;
  }
  size_t need = *len + slen;
  buf_reserve(buf, cap, need);
  if (*buf == NULL || *cap < need) {
    return;
  }
  memcpy(*buf + *len, s, slen);
  *len = need;
}

static void buf_append_cstr(char **buf, size_t *len, size_t *cap, const char *s) {
  buf_append(buf, len, cap, s, strlen(s));
}

static int cstr_eq_n(const char *a, const char *b, size_t n) {
  if (a == NULL || b == NULL) {
    return 0;
  }
  return strncmp(a, b, n) == 0;
}

static int buf_has_line(const char *buf, size_t len, const char *line, size_t line_len) {
  if (buf == NULL || len == 0 || line == NULL || line_len == 0) {
    return 0;
  }
  for (size_t i = 0; i + line_len + 1 <= len; i++) {
    if (buf[i + line_len] != '\n') {
      continue;
    }
    if (memcmp(buf + i, line, line_len) == 0) {
      if (i == 0 || buf[i - 1] == '\n') {
        return 1;
      }
    }
  }
  return 0;
}

#if defined(_WIN32)
#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <propidl.h>
#include <propvarutil.h>
#include <functiondiscoverykeys_devpkey.h>

// -----------------------------------------------------------------------------
// Default config query (Windows)
// -----------------------------------------------------------------------------
//
// Returns (channels, sample_rate, sample_format_tag) via a u32 out array.
// - sample_format_tag: 1 = f32, 2 = i16

static wchar_t *utf8_bytes_to_wide(uint8_t *bytes, int32_t len) {
  if (bytes == NULL || len <= 0) {
    return NULL;
  }
  // NUL-terminate for MultiByteToWideChar.
  char *tmp = (char *)calloc((size_t)len + 1, 1);
  if (tmp == NULL) {
    return NULL;
  }
  memcpy(tmp, bytes, (size_t)len);
  tmp[len] = '\0';
  if (tmp[0] == '\0' || strcmp(tmp, "default") == 0) {
    free(tmp);
    return NULL;
  }

  int wlen = MultiByteToWideChar(CP_UTF8, 0, tmp, -1, NULL, 0);
  if (wlen <= 0) {
    free(tmp);
    return NULL;
  }
  wchar_t *ws = (wchar_t *)calloc((size_t)wlen, sizeof(wchar_t));
  if (ws == NULL) {
    free(tmp);
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, 0, tmp, -1, ws, wlen) <= 0) {
    free(tmp);
    free(ws);
    return NULL;
  }
  free(tmp);
  return ws;
}

static uint32_t sample_format_tag_from_mix(const WAVEFORMATEX *wfx) {
  if (wfx == NULL) {
    return 0;
  }
  if (wfx->wBitsPerSample == 32) {
    return 1;
  }
  if (wfx->wBitsPerSample == 16) {
    return 2;
  }
  return 0;
}

static uint32_t channel_mask_from_channels(uint32_t channels) {
  // Best-effort channel masks for common layouts.
  switch (channels) {
  case 1:
    return SPEAKER_FRONT_CENTER;
  case 2:
    return SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
  case 4:
    return SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_BACK_LEFT | SPEAKER_BACK_RIGHT;
  case 6:
    return SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_LOW_FREQUENCY |
           SPEAKER_SIDE_LEFT | SPEAKER_SIDE_RIGHT;
  case 8:
    return SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_LOW_FREQUENCY |
           SPEAKER_BACK_LEFT | SPEAKER_BACK_RIGHT | SPEAKER_SIDE_LEFT | SPEAKER_SIDE_RIGHT;
  default:
    // Unknown layout.
    return 0;
  }
}

// MinGW doesn't always provide linkable definitions for KSDATAFORMAT_SUBTYPE_* GUIDs.
// Define the two subformats we need locally:
// - PCM:        {00000001-0000-0010-8000-00AA00389B71}
// - IEEE_FLOAT: {00000003-0000-0010-8000-00AA00389B71}
static const GUID moon_cpal_ks_subtype_pcm = {0x00000001,
                                             0x0000,
                                             0x0010,
                                             {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
static const GUID moon_cpal_ks_subtype_ieee_float = {0x00000003,
                                                     0x0000,
                                                     0x0010,
                                                     {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};

static int wasapi_build_wfx_ext(uint32_t channels,
                                uint32_t sample_rate,
                                uint32_t sample_format_tag,
                                WAVEFORMATEXTENSIBLE *out) {
  if (out == NULL || channels == 0 || sample_rate == 0) {
    return 0;
  }
  memset(out, 0, sizeof(*out));

  uint16_t bits = 0;
  GUID sub = moon_cpal_ks_subtype_pcm;
  if (sample_format_tag == 1) {
    bits = 32;
    sub = moon_cpal_ks_subtype_ieee_float;
  } else if (sample_format_tag == 2) {
    bits = 16;
    sub = moon_cpal_ks_subtype_pcm;
  } else {
    return 0;
  }

  out->Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
  out->Format.nChannels = (WORD)channels;
  out->Format.nSamplesPerSec = (DWORD)sample_rate;
  out->Format.wBitsPerSample = bits;
  out->Format.nBlockAlign = (WORD)((channels * bits) / 8);
  out->Format.nAvgBytesPerSec = out->Format.nSamplesPerSec * out->Format.nBlockAlign;
  out->Format.cbSize = (WORD)(sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX));
  out->Samples.wValidBitsPerSample = bits;
  out->dwChannelMask = channel_mask_from_channels(channels);
  out->SubFormat = sub;
  return 1;
}

static void wasapi_buffer_size_range_frames(IAudioClient *client,
                                            const WAVEFORMATEX *wfx,
                                            uint32_t sample_rate,
                                            uint32_t *out_min,
                                            uint32_t *out_max) {
  if (out_min != NULL) {
    *out_min = 0;
  }
  if (out_max != NULL) {
    *out_max = 0xFFFFFFFFu;
  }
  if (client == NULL || wfx == NULL || sample_rate == 0) {
    return;
  }

  IAudioClient2 *client2 = NULL;
  HRESULT hr = IAudioClient_QueryInterface(client, &IID_IAudioClient2, (void **)&client2);
  if (FAILED(hr) || client2 == NULL) {
    return;
  }

  REFERENCE_TIME min_dur = 0;
  REFERENCE_TIME max_dur = 0;
  hr = IAudioClient2_GetBufferSizeLimits(client2, wfx, TRUE, &min_dur, &max_dur);
  IAudioClient2_Release(client2);
  client2 = NULL;

  if (FAILED(hr)) {
    // In software stacks this often returns AUDCLNT_E_OFFLOAD_MODE_ONLY; treat as unbounded.
    return;
  }

  // Convert 100ns durations to frame counts (same math as upstream CPAL).
  uint64_t s = (uint64_t)sample_rate;
  uint64_t min_frames = ((uint64_t)min_dur * s) / 10000000ull;
  uint64_t max_frames = ((uint64_t)max_dur * s) / 10000000ull;
  if (out_min != NULL) {
    *out_min = (min_frames > 0xFFFFFFFFull) ? 0xFFFFFFFFu : (uint32_t)min_frames;
  }
  if (out_max != NULL) {
    *out_max = (max_frames > 0xFFFFFFFFull) ? 0xFFFFFFFFu : (uint32_t)max_frames;
  }
}

int32_t moon_cpal_wasapi_device_data_flow_tag(uint8_t *device_id_utf8, int32_t device_id_len) {
  wchar_t *endpoint_id_w = utf8_bytes_to_wide(device_id_utf8, device_id_len);
  moonbit_decref(device_id_utf8);

  if (endpoint_id_w == NULL) {
    return 0;
  }

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    free(endpoint_id_w);
    return 0;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IMMEndpoint *endpoint = NULL;
  EDataFlow flow = eAll;
  int32_t out = 0;

  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                        (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    goto done;
  }

  hr = IMMDeviceEnumerator_GetDevice(enumerator, endpoint_id_w, &device);
  if (FAILED(hr) || device == NULL) {
    goto done;
  }

  hr = IMMDevice_QueryInterface(device, &IID_IMMEndpoint, (void **)&endpoint);
  if (FAILED(hr) || endpoint == NULL) {
    goto done;
  }

  hr = IMMEndpoint_GetDataFlow(endpoint, &flow);
  if (FAILED(hr)) {
    goto done;
  }

  if (flow == eCapture) {
    out = 1;
  } else if (flow == eRender) {
    out = 2;
  } else {
    out = 0;
  }

done:
  if (endpoint != NULL) {
    IMMEndpoint_Release(endpoint);
    endpoint = NULL;
  }
  if (device != NULL) {
    IMMDevice_Release(device);
    device = NULL;
  }
  if (enumerator != NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    enumerator = NULL;
  }
  free(endpoint_id_w);
  CoUninitialize();
  return out;
}

int32_t moon_cpal_wasapi_default_config_ex_u32(uint8_t *device_id_utf8,
                                              int32_t device_id_len,
                                              int32_t is_input,
                                              uint32_t *out,
                                              int32_t out_len) {
  if (out == NULL || out_len < 5) {
    moonbit_decref(device_id_utf8);
    return -1;
  }
  out[0] = 0;
  out[1] = 0;
  out[2] = 0;
  out[3] = 0;
  out[4] = 0;

  wchar_t *endpoint_id_w = utf8_bytes_to_wide(device_id_utf8, device_id_len);
  moonbit_decref(device_id_utf8);

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    if (endpoint_id_w != NULL) {
      free(endpoint_id_w);
    }
    return (int32_t)hr;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioClient *client = NULL;
  WAVEFORMATEX *wfx = NULL;

  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                        (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    goto done;
  }

  EDataFlow flow = is_input ? eCapture : eRender;
  if (endpoint_id_w != NULL) {
    hr = IMMDeviceEnumerator_GetDevice(enumerator, endpoint_id_w, &device);
    if (FAILED(hr) || device == NULL) {
      hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, flow, eConsole, &device);
    }
  } else {
    hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, flow, eConsole, &device);
  }
  if (FAILED(hr) || device == NULL) {
    goto done;
  }

  hr = IMMDevice_Activate(device, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)&client);
  if (FAILED(hr) || client == NULL) {
    goto done;
  }

  hr = IAudioClient_GetMixFormat(client, &wfx);
  if (FAILED(hr) || wfx == NULL) {
    goto done;
  }

  uint32_t tag = sample_format_tag_from_mix(wfx);
  if (tag == 0) {
    hr = E_FAIL;
    goto done;
  }

  uint32_t bmin = 0;
  uint32_t bmax = 0xFFFFFFFFu;
  wasapi_buffer_size_range_frames(client, wfx, (uint32_t)wfx->nSamplesPerSec, &bmin, &bmax);

  out[0] = (uint32_t)wfx->nChannels;
  out[1] = (uint32_t)wfx->nSamplesPerSec;
  out[2] = tag;
  out[3] = bmin;
  out[4] = bmax;
  hr = S_OK;

done:
  if (wfx != NULL) {
    CoTaskMemFree(wfx);
    wfx = NULL;
  }
  if (client != NULL) {
    IAudioClient_Release(client);
    client = NULL;
  }
  if (device != NULL) {
    IMMDevice_Release(device);
    device = NULL;
  }
  if (enumerator != NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    enumerator = NULL;
  }
  if (endpoint_id_w != NULL) {
    free(endpoint_id_w);
    endpoint_id_w = NULL;
  }
  CoUninitialize();

  return FAILED(hr) ? (int32_t)hr : 0;
}

int32_t moon_cpal_wasapi_supported_configs_u32(uint8_t *device_id_utf8,
                                              int32_t device_id_len,
                                              int32_t is_input,
                                              uint32_t *out,
                                              int32_t out_len) {
  if (out == NULL || out_len <= 0) {
    moonbit_decref(device_id_utf8);
    return -1;
  }

  const int32_t stride = 5;
  int32_t max_entries = out_len / stride;
  if (max_entries <= 0) {
    moonbit_decref(device_id_utf8);
    return -1;
  }

  wchar_t *endpoint_id_w = utf8_bytes_to_wide(device_id_utf8, device_id_len);
  moonbit_decref(device_id_utf8);

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    if (endpoint_id_w != NULL) {
      free(endpoint_id_w);
    }
    return (int32_t)hr;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioClient *client = NULL;
  WAVEFORMATEX *mix = NULL;

  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                        (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    goto done;
  }

  EDataFlow flow = is_input ? eCapture : eRender;
  if (endpoint_id_w != NULL) {
    hr = IMMDeviceEnumerator_GetDevice(enumerator, endpoint_id_w, &device);
    if (FAILED(hr) || device == NULL) {
      hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, flow, eConsole, &device);
    }
  } else {
    hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, flow, eConsole, &device);
  }
  if (FAILED(hr) || device == NULL) {
    goto done;
  }

  hr = IMMDevice_Activate(device, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)&client);
  if (FAILED(hr) || client == NULL) {
    goto done;
  }

  hr = IAudioClient_GetMixFormat(client, &mix);
  if (FAILED(hr) || mix == NULL) {
    goto done;
  }

  if (IAudioClient_IsFormatSupported(client, AUDCLNT_SHAREMODE_SHARED, mix, NULL) != S_OK) {
    hr = E_FAIL;
    goto done;
  }

  uint32_t channels = (uint32_t)mix->nChannels;
  uint32_t default_sr = (uint32_t)mix->nSamplesPerSec;

  uint32_t bmin = 0;
  uint32_t bmax = 0xFFFFFFFFu;
  wasapi_buffer_size_range_frames(client, mix, default_sr, &bmin, &bmax);

  // Mirror upstream CPAL's COMMON_SAMPLE_RATES list.
  static const uint32_t rates[] = {
      5512,   8000,   11025,  12000,  16000,  22050,  24000,
      32000,  44100,  48000,  64000,  88200,  96000,  176400,
      192000, 352800, 384000, 705600, 768000, 1411200, 1536000,
  };

  // Supported formats in this MoonBit port (today): F32 + I16.
  static const uint32_t fmts[] = {2 /* i16 */, 1 /* f32 */};

  int32_t wrote = 0;
  for (size_t ri = 0; ri < (sizeof(rates) / sizeof(rates[0])); ri++) {
    uint32_t sr = rates[ri];
    for (size_t fi = 0; fi < (sizeof(fmts) / sizeof(fmts[0])); fi++) {
      uint32_t fmt_tag = fmts[fi];
      if (wrote >= max_entries) {
        goto ok;
      }
      WAVEFORMATEXTENSIBLE wf;
      if (!wasapi_build_wfx_ext(channels, sr, fmt_tag, &wf)) {
        continue;
      }
      HRESULT okfmt = IAudioClient_IsFormatSupported(client, AUDCLNT_SHAREMODE_SHARED,
                                                     (const WAVEFORMATEX *)&wf, NULL);
      if (okfmt == S_OK) {
        int32_t off = wrote * stride;
        out[off + 0] = channels;
        out[off + 1] = sr;
        out[off + 2] = fmt_tag;
        out[off + 3] = bmin;
        out[off + 4] = bmax;
        wrote++;
      }
    }
  }

ok:
  // Ensure the default sample rate is included (in case it's unusual).
  for (size_t fi = 0; fi < (sizeof(fmts) / sizeof(fmts[0])); fi++) {
    uint32_t fmt_tag = fmts[fi];
    int already = 0;
    for (int32_t i = 0; i < wrote; i++) {
      int32_t off = i * stride;
      if (out[off + 1] == default_sr && out[off + 2] == fmt_tag) {
        already = 1;
        break;
      }
    }
    if (already) {
      continue;
    }
    if (wrote >= max_entries) {
      break;
    }
    WAVEFORMATEXTENSIBLE wf;
    if (!wasapi_build_wfx_ext(channels, default_sr, fmt_tag, &wf)) {
      continue;
    }
    HRESULT okfmt = IAudioClient_IsFormatSupported(client, AUDCLNT_SHAREMODE_SHARED,
                                                   (const WAVEFORMATEX *)&wf, NULL);
    if (okfmt == S_OK) {
      int32_t off = wrote * stride;
      out[off + 0] = channels;
      out[off + 1] = default_sr;
      out[off + 2] = fmt_tag;
      out[off + 3] = bmin;
      out[off + 4] = bmax;
      wrote++;
    }
  }

  hr = S_OK;

done:
  if (mix != NULL) {
    CoTaskMemFree(mix);
    mix = NULL;
  }
  if (client != NULL) {
    IAudioClient_Release(client);
    client = NULL;
  }
  if (device != NULL) {
    IMMDevice_Release(device);
    device = NULL;
  }
  if (enumerator != NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    enumerator = NULL;
  }
  if (endpoint_id_w != NULL) {
    free(endpoint_id_w);
    endpoint_id_w = NULL;
  }
  CoUninitialize();

  return FAILED(hr) ? (int32_t)hr : wrote;
}

int32_t moon_cpal_wasapi_default_config_u32(uint8_t *device_id_utf8,
                                           int32_t device_id_len,
                                           int32_t is_input,
                                           uint32_t *out,
                                           int32_t out_len) {
  if (out == NULL || out_len < 3) {
    moonbit_decref(device_id_utf8);
    return -1;
  }
  out[0] = 0;
  out[1] = 0;
  out[2] = 0;

  wchar_t *endpoint_id_w = utf8_bytes_to_wide(device_id_utf8, device_id_len);
  moonbit_decref(device_id_utf8);

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    if (endpoint_id_w != NULL) {
      free(endpoint_id_w);
    }
    return (int32_t)hr;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *device = NULL;
  IAudioClient *client = NULL;
  WAVEFORMATEX *wfx = NULL;

  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                        (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    goto done;
  }

  EDataFlow flow = is_input ? eCapture : eRender;
  if (endpoint_id_w != NULL) {
    hr = IMMDeviceEnumerator_GetDevice(enumerator, endpoint_id_w, &device);
    if (FAILED(hr) || device == NULL) {
      hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, flow, eConsole, &device);
    }
  } else {
    hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, flow, eConsole, &device);
  }
  if (FAILED(hr) || device == NULL) {
    goto done;
  }

  hr = IMMDevice_Activate(device, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)&client);
  if (FAILED(hr) || client == NULL) {
    goto done;
  }

  hr = IAudioClient_GetMixFormat(client, &wfx);
  if (FAILED(hr) || wfx == NULL) {
    goto done;
  }

  uint32_t tag = sample_format_tag_from_mix(wfx);
  if (tag == 0) {
    hr = E_FAIL;
    goto done;
  }

  out[0] = (uint32_t)wfx->nChannels;
  out[1] = (uint32_t)wfx->nSamplesPerSec;
  out[2] = tag;
  hr = S_OK;

done:
  if (wfx != NULL) {
    CoTaskMemFree(wfx);
    wfx = NULL;
  }
  if (client != NULL) {
    IAudioClient_Release(client);
    client = NULL;
  }
  if (device != NULL) {
    IMMDevice_Release(device);
    device = NULL;
  }
  if (enumerator != NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    enumerator = NULL;
  }
  if (endpoint_id_w != NULL) {
    free(endpoint_id_w);
    endpoint_id_w = NULL;
  }
  CoUninitialize();

  return FAILED(hr) ? (int32_t)hr : 0;
}

static int wstr_is_default(const wchar_t *s) {
  if (s == NULL) {
    return 0;
  }
  return wcscmp(s, L"default") == 0;
}

static int utf8_is_default(const char *s, size_t len) {
  static const char *k = "default";
  if (len != 7) {
    return 0;
  }
  return cstr_eq_n(s, k, 7);
}

static int wide_to_utf8_len(const wchar_t *ws) {
  if (ws == NULL) {
    return 0;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, ws, -1, NULL, 0, NULL, NULL);
  if (n <= 0) {
    return 0;
  }
  // Exclude terminating NUL.
  return n - 1;
}

static int wide_to_utf8(const wchar_t *ws, char *out, int out_len) {
  if (ws == NULL || out == NULL || out_len <= 0) {
    return 0;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, ws, -1, out, out_len, NULL, NULL);
  if (n <= 0) {
    return 0;
  }
  // Exclude terminating NUL.
  return n - 1;
}

static wchar_t *utf8_to_wide_alloc(const char *s, size_t len) {
  if (s == NULL || len == 0) {
    return NULL;
  }
  // Ensure NUL-terminated.
  char tmp[512];
  if (len >= sizeof(tmp)) {
    len = sizeof(tmp) - 1;
  }
  memcpy(tmp, s, len);
  tmp[len] = '\0';

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

static int wasapi_enum_devices_utf8(char **out_buf, size_t *out_len, size_t *out_cap) {
  if (out_buf == NULL || out_len == NULL || out_cap == NULL) {
    return -1;
  }

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    return -1;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    CoUninitialize();
    return -1;
  }

  IMMDeviceCollection *col = NULL;
  hr = IMMDeviceEnumerator_EnumAudioEndpoints(enumerator, eAll, DEVICE_STATE_ACTIVE, &col);
  if (FAILED(hr) || col == NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    CoUninitialize();
    return -1;
  }

  UINT count = 0;
  hr = IMMDeviceCollection_GetCount(col, &count);
  if (FAILED(hr)) {
    IMMDeviceCollection_Release(col);
    IMMDeviceEnumerator_Release(enumerator);
    CoUninitialize();
    return -1;
  }

  for (UINT i = 0; i < count; i++) {
    IMMDevice *dev = NULL;
    hr = IMMDeviceCollection_Item(col, i, &dev);
    if (FAILED(hr) || dev == NULL) {
      continue;
    }
    LPWSTR idw = NULL;
    hr = IMMDevice_GetId(dev, &idw);
    if (SUCCEEDED(hr) && idw != NULL && !wstr_is_default(idw)) {
      int n = wide_to_utf8_len(idw);
      if (n > 0) {
        char *tmp = (char *)calloc((size_t)n + 1, 1);
        if (tmp != NULL) {
          int used = wide_to_utf8(idw, tmp, n + 1);
          if (used > 0 && !buf_has_line(*out_buf, *out_len, tmp, (size_t)used)) {
            buf_append(out_buf, out_len, out_cap, tmp, (size_t)used);
            buf_append(out_buf, out_len, out_cap, "\n", 1);
          }
          free(tmp);
        }
      }
    }
    if (idw != NULL) {
      CoTaskMemFree(idw);
    }
    IMMDevice_Release(dev);
  }

  IMMDeviceCollection_Release(col);
  IMMDeviceEnumerator_Release(enumerator);
  CoUninitialize();
  return 0;
}

static int wasapi_lookup_friendly_name_utf8(const char *id_utf8, size_t id_len, char **out_name) {
  if (out_name == NULL) {
    return -1;
  }
  *out_name = NULL;
  if (id_utf8 == NULL || id_len == 0) {
    return -1;
  }
  if (utf8_is_default(id_utf8, id_len)) {
    const char *k = "default";
    size_t n = strlen(k);
    char *p = (char *)calloc(n + 1, 1);
    if (p == NULL) {
      return -1;
    }
    memcpy(p, k, n);
    p[n] = '\0';
    *out_name = p;
    return 0;
  }

  wchar_t *idw = utf8_to_wide_alloc(id_utf8, id_len);
  if (idw == NULL) {
    return -1;
  }

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    free(idw);
    return -1;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    CoUninitialize();
    free(idw);
    return -1;
  }

  IMMDevice *dev = NULL;
  hr = IMMDeviceEnumerator_GetDevice(enumerator, idw, &dev);
  free(idw);
  if (FAILED(hr) || dev == NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    CoUninitialize();
    return -1;
  }

  IPropertyStore *props = NULL;
  hr = IMMDevice_OpenPropertyStore(dev, STGM_READ, &props);
  if (FAILED(hr) || props == NULL) {
    IMMDevice_Release(dev);
    IMMDeviceEnumerator_Release(enumerator);
    CoUninitialize();
    return -1;
  }

  PROPVARIANT pv;
  PropVariantInit(&pv);
  hr = IPropertyStore_GetValue(props, &PKEY_Device_FriendlyName, &pv);
  if (SUCCEEDED(hr) && pv.vt == VT_LPWSTR && pv.pwszVal != NULL) {
    int n = wide_to_utf8_len(pv.pwszVal);
    if (n > 0) {
      char *tmp = (char *)calloc((size_t)n + 1, 1);
      if (tmp != NULL) {
        int used = wide_to_utf8(pv.pwszVal, tmp, n + 1);
        if (used > 0) {
          tmp[used] = '\0';
          *out_name = tmp;
        } else {
          free(tmp);
        }
      }
    }
  }
  PropVariantClear(&pv);

  IPropertyStore_Release(props);
  IMMDevice_Release(dev);
  IMMDeviceEnumerator_Release(enumerator);
  CoUninitialize();
  return *out_name ? 0 : -1;
}

// -----------------------------------------------------------------------------
// Device property helpers (Windows)
// -----------------------------------------------------------------------------

static int wasapi_open_property_store(const char *id_utf8,
                                      size_t id_len,
                                      IMMDeviceEnumerator **out_enumerator,
                                      IMMDevice **out_device,
                                      IPropertyStore **out_props) {
  if (out_enumerator != NULL) {
    *out_enumerator = NULL;
  }
  if (out_device != NULL) {
    *out_device = NULL;
  }
  if (out_props != NULL) {
    *out_props = NULL;
  }
  if (id_utf8 == NULL || id_len == 0 || out_props == NULL) {
    return -1;
  }
  if (utf8_is_default(id_utf8, id_len)) {
    return -1;
  }

  wchar_t *idw = utf8_to_wide_alloc(id_utf8, id_len);
  if (idw == NULL) {
    return -1;
  }

  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    free(idw);
    return -1;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *dev = NULL;
  IPropertyStore *props = NULL;

  hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                        (void **)&enumerator);
  if (FAILED(hr) || enumerator == NULL) {
    goto fail;
  }

  hr = IMMDeviceEnumerator_GetDevice(enumerator, idw, &dev);
  if (FAILED(hr) || dev == NULL) {
    goto fail;
  }

  hr = IMMDevice_OpenPropertyStore(dev, STGM_READ, &props);
  if (FAILED(hr) || props == NULL) {
    goto fail;
  }

  if (out_enumerator != NULL) {
    *out_enumerator = enumerator;
  }
  if (out_device != NULL) {
    *out_device = dev;
  }
  *out_props = props;
  free(idw);
  return 0;

fail:
  if (props != NULL) {
    IPropertyStore_Release(props);
    props = NULL;
  }
  if (dev != NULL) {
    IMMDevice_Release(dev);
    dev = NULL;
  }
  if (enumerator != NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    enumerator = NULL;
  }
  free(idw);
  CoUninitialize();
  return -1;
}

static void wasapi_close_property_store(IMMDeviceEnumerator *enumerator,
                                       IMMDevice *device,
                                       IPropertyStore *props) {
  if (props != NULL) {
    IPropertyStore_Release(props);
    props = NULL;
  }
  if (device != NULL) {
    IMMDevice_Release(device);
    device = NULL;
  }
  if (enumerator != NULL) {
    IMMDeviceEnumerator_Release(enumerator);
    enumerator = NULL;
  }
  CoUninitialize();
}

static int wasapi_get_property_string_utf8(const char *id_utf8,
                                           size_t id_len,
                                           const PROPERTYKEY *key,
                                           char **out_str) {
  if (out_str == NULL) {
    return -1;
  }
  *out_str = NULL;
  if (key == NULL) {
    return -1;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *dev = NULL;
  IPropertyStore *props = NULL;
  if (wasapi_open_property_store(id_utf8, id_len, &enumerator, &dev, &props) != 0) {
    return -1;
  }

  PROPVARIANT pv;
  PropVariantInit(&pv);
  HRESULT hr = IPropertyStore_GetValue(props, key, &pv);
  if (SUCCEEDED(hr) && pv.vt == VT_LPWSTR && pv.pwszVal != NULL) {
    int n = wide_to_utf8_len(pv.pwszVal);
    if (n > 0) {
      char *tmp = (char *)calloc((size_t)n + 1, 1);
      if (tmp != NULL) {
        int used = wide_to_utf8(pv.pwszVal, tmp, n + 1);
        if (used > 0) {
          tmp[used] = '\0';
          *out_str = tmp;
        } else {
          free(tmp);
        }
      }
    }
  }
  PropVariantClear(&pv);

  wasapi_close_property_store(enumerator, dev, props);
  return *out_str ? 0 : -1;
}

static int wasapi_get_property_u32(const char *id_utf8,
                                   size_t id_len,
                                   const PROPERTYKEY *key,
                                   uint32_t *out_u32) {
  if (out_u32 == NULL) {
    return -1;
  }
  *out_u32 = 0;
  if (key == NULL) {
    return -1;
  }

  IMMDeviceEnumerator *enumerator = NULL;
  IMMDevice *dev = NULL;
  IPropertyStore *props = NULL;
  if (wasapi_open_property_store(id_utf8, id_len, &enumerator, &dev, &props) != 0) {
    return -1;
  }

  PROPVARIANT pv;
  PropVariantInit(&pv);
  HRESULT hr = IPropertyStore_GetValue(props, key, &pv);
  if (SUCCEEDED(hr) && pv.vt == VT_UI4) {
    *out_u32 = (uint32_t)pv.ulVal;
  }
  PropVariantClear(&pv);
  wasapi_close_property_store(enumerator, dev, props);
  return 0;
}

static const PROPERTYKEY *wasapi_propkey_from_tag(int32_t prop_tag) {
  // These correspond to the keys used in upstream CPAL's WASAPI `Device::description`.
  switch (prop_tag) {
  case 1:
#if defined(PKEY_Device_Manufacturer)
    return &PKEY_Device_Manufacturer;
#else
    return NULL;
#endif
  case 2:
#if defined(PKEY_Device_DeviceDesc)
    return &PKEY_Device_DeviceDesc;
#else
    return NULL;
#endif
  case 3:
#if defined(PKEY_DeviceInterface_FriendlyName)
    return &PKEY_DeviceInterface_FriendlyName;
#else
    return NULL;
#endif
  case 4:
#if defined(PKEY_Device_EnumeratorName)
    return &PKEY_Device_EnumeratorName;
#else
    return NULL;
#endif
  case 5:
#if defined(PKEY_AudioEndpoint_JackSubType)
    return &PKEY_AudioEndpoint_JackSubType;
#else
    return NULL;
#endif
  case 6:
#if defined(PKEY_Device_FriendlyName)
    return &PKEY_Device_FriendlyName;
#else
    return NULL;
#endif
  default:
    return NULL;
  }
}
#endif

moonbit_bytes_t moon_cpal_wasapi_devices_utf8(void) {
#if defined(_WIN32)
  char *buf = NULL;
  size_t len = 0;
  size_t cap = 0;

  // Always include a "default" device.
  buf_append_cstr(&buf, &len, &cap, "default\n");
  (void)wasapi_enum_devices_utf8(&buf, &len, &cap);

  if (len == 0) {
    return moonbit_make_bytes_raw(0);
  }
  moonbit_bytes_t out = moonbit_make_bytes_raw((int32_t)len);
  if (out != NULL) {
    memcpy(out, buf, len);
  }
  free(buf);
  return out;
#else
  return moonbit_make_bytes_raw(0);
#endif
}

uint32_t moon_cpal_wasapi_device_form_factor_u32(uint8_t *device_id_utf8, int32_t device_id_len) {
#if defined(_WIN32)
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    return 0xFFFFFFFFu;
  }

  char id_buf[512];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';
  moonbit_decref(device_id_utf8);

#if !defined(PKEY_AudioEndpoint_FormFactor)
  return 0xFFFFFFFFu;
#else
  uint32_t out = 0;
  if (wasapi_get_property_u32(id_buf, id_len, &PKEY_AudioEndpoint_FormFactor, &out) != 0) {
    return 0xFFFFFFFFu;
  }
  return out;
#endif
#else
  (void)device_id_len;
  moonbit_decref(device_id_utf8);
  return 0xFFFFFFFFu;
#endif
}

int32_t moon_cpal_wasapi_device_property_utf8_len(uint8_t *device_id_utf8,
                                                  int32_t device_id_len,
                                                  int32_t prop_tag) {
#if defined(_WIN32)
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    return -1;
  }

  char id_buf[512];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';
  moonbit_decref(device_id_utf8);

  const PROPERTYKEY *key = wasapi_propkey_from_tag(prop_tag);
  if (key == NULL) {
    return -1;
  }

  char *s = NULL;
  if (wasapi_get_property_string_utf8(id_buf, id_len, key, &s) == 0 && s != NULL) {
    int32_t n = (int32_t)strlen(s);
    free(s);
    return n;
  }
  return -1;
#else
  (void)device_id_len;
  (void)prop_tag;
  moonbit_decref(device_id_utf8);
  return -1;
#endif
}

int32_t moon_cpal_wasapi_device_property_utf8(uint8_t *device_id_utf8,
                                              int32_t device_id_len,
                                              int32_t prop_tag,
                                              uint8_t *out,
                                              int32_t out_len) {
#if defined(_WIN32)
  if (out == NULL || out_len <= 0) {
    moonbit_decref(device_id_utf8);
    return 0;
  }
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    moonbit_decref(device_id_utf8);
    return -1;
  }

  char id_buf[512];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';
  moonbit_decref(device_id_utf8);

  const PROPERTYKEY *key = wasapi_propkey_from_tag(prop_tag);
  if (key == NULL) {
    return -1;
  }

  char *s = NULL;
  if (wasapi_get_property_string_utf8(id_buf, id_len, key, &s) == 0 && s != NULL) {
    size_t slen = strlen(s);
    int32_t needed = (int32_t)slen;
    if (needed > out_len) {
      free(s);
      return needed;
    }
    memcpy(out, s, slen);
    free(s);
    return needed;
  }
  return -1;
#else
  (void)device_id_len;
  (void)prop_tag;
  (void)out;
  (void)out_len;
  moonbit_decref(device_id_utf8);
  return -1;
#endif
}

int32_t moon_cpal_wasapi_device_name_utf8_len(uint8_t *device_id_utf8, int32_t device_id_len) {
#if defined(_WIN32)
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    return -1;
  }

  // Copy before decref: `device_id_utf8` is owned by this function.
  char id_buf[512];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';
  moonbit_decref(device_id_utf8);

  char *name = NULL;
  if (wasapi_lookup_friendly_name_utf8(id_buf, id_len, &name) == 0 && name != NULL) {
    int32_t n = (int32_t)strlen(name);
    free(name);
    return n;
  }
  return (int32_t)id_len;
#else
  (void)device_id_len;
  moonbit_decref(device_id_utf8);
  return -1;
#endif
}

int32_t moon_cpal_wasapi_device_name_utf8(uint8_t *device_id_utf8,
                                         int32_t device_id_len,
                                         uint8_t *out,
                                         int32_t out_len) {
#if defined(_WIN32)
  if (out == NULL || out_len <= 0) {
    moonbit_decref(device_id_utf8);
    return 0;
  }
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    moonbit_decref(device_id_utf8);
    return -1;
  }

  // Copy before decref: `device_id_utf8` is owned by this function.
  char id_buf[512];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';
  moonbit_decref(device_id_utf8);

  const char *fallback = id_buf;
  size_t fallback_len = id_len;

  char *name = NULL;
  if (wasapi_lookup_friendly_name_utf8(id_buf, id_len, &name) == 0 && name != NULL) {
    fallback = name;
    fallback_len = strlen(name);
  }

  int32_t needed = (int32_t)fallback_len;
  if (needed > out_len) {
    if (name != NULL) {
      free(name);
    }
    return needed;
  }
  memcpy(out, fallback, fallback_len);
  if (name != NULL) {
    free(name);
  }
  return needed;
#else
  (void)device_id_len;
  (void)out;
  (void)out_len;
  moonbit_decref(device_id_utf8);
  return -1;
#endif
}

#if !defined(_WIN32)
// Non-Windows native builds: provide stubs so the module links when the WASAPI package is
// pulled in via platform dispatch.
int32_t moon_cpal_wasapi_device_data_flow_tag(uint8_t *device_id_utf8, int32_t device_id_len) {
  (void)device_id_len;
  moonbit_decref(device_id_utf8);
  return 0;
}

int32_t moon_cpal_wasapi_default_config_ex_u32(uint8_t *device_id_utf8,
                                              int32_t device_id_len,
                                              int32_t is_input,
                                              uint32_t *out,
                                              int32_t out_len) {
  (void)device_id_len;
  (void)is_input;
  if (out != NULL && out_len >= 5) {
    out[0] = 0;
    out[1] = 0;
    out[2] = 0;
    out[3] = 0;
    out[4] = 0;
  }
  moonbit_decref(device_id_utf8);
  return -1;
}

int32_t moon_cpal_wasapi_supported_configs_u32(uint8_t *device_id_utf8,
                                              int32_t device_id_len,
                                              int32_t is_input,
                                              uint32_t *out,
                                              int32_t out_len) {
  (void)device_id_len;
  (void)is_input;
  if (out != NULL && out_len > 0) {
    out[0] = 0;
  }
  moonbit_decref(device_id_utf8);
  return -1;
}

int32_t moon_cpal_wasapi_default_config_u32(uint8_t *device_id_utf8,
                                           int32_t device_id_len,
                                           int32_t is_input,
                                           uint32_t *out,
                                           int32_t out_len) {
  (void)device_id_len;
  (void)is_input;
  if (out != NULL && out_len >= 3) {
    out[0] = 0;
    out[1] = 0;
    out[2] = 0;
  }
  moonbit_decref(device_id_utf8);
  return -1;
}
#endif
