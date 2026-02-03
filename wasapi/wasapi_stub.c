#include <stdint.h>
#include <string.h>

#include "moonbit.h"

// -----------------------------------------------------------------------------
// WASAPI device discovery stub
// -----------------------------------------------------------------------------
//
// A real WASAPI implementation will likely require COM/MMDevice (Windows SDK) and careful
// callback scheduling. For now we expose a minimal device list so higher-level code paths
// can be exercised on Windows.
//
// Exported format: UTF-8, newline-separated device IDs.

moonbit_bytes_t moon_cpal_wasapi_devices_utf8(void) {
#if defined(_WIN32)
  static const char *k = "default\n";
  int32_t n = (int32_t)strlen(k);
  moonbit_bytes_t out = moonbit_make_bytes_raw(n);
  if (out != NULL) {
    memcpy(out, k, (size_t)n);
  }
  return out;
#else
  return moonbit_make_bytes_raw(0);
#endif
}

