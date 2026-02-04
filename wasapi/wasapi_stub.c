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

#include <mmdeviceapi.h>
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
