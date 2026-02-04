#include <stdint.h>
#include "moonbit.h"

// Placeholder for future JACK device enumeration helpers.
//
// This file intentionally does not include JACK headers so it can compile on
// non-Linux platforms as part of the native target build.
#if defined(__linux__)
#include <jack/jack.h>
#endif

// -----------------------------------------------------------------------------
// JACK default server config query (binary)
// -----------------------------------------------------------------------------
//
// Exported format (little-endian): (sample_rate_u32, buffer_size_frames_u32)
//
// On non-Linux platforms, or if no JACK server is available, returns empty bytes.

static void write_u32_le(uint8_t *dst, uint32_t v) {
  dst[0] = (uint8_t)(v & 0xFFu);
  dst[1] = (uint8_t)((v >> 8) & 0xFFu);
  dst[2] = (uint8_t)((v >> 16) & 0xFFu);
  dst[3] = (uint8_t)((v >> 24) & 0xFFu);
}

moonbit_bytes_t moon_cpal_jack_default_config_bin(void) {
#if defined(__linux__)
  jack_status_t status = 0;
  jack_client_t *client = jack_client_open("moon_cpal_query", JackNoStartServer, &status, NULL);
  if (client == NULL) {
    return moonbit_make_bytes_raw(0);
  }

  uint32_t sr = (uint32_t)jack_get_sample_rate(client);
  uint32_t buf = (uint32_t)jack_get_buffer_size(client);
  jack_client_close(client);

  if (sr == 0 || buf == 0) {
    return moonbit_make_bytes_raw(0);
  }

  moonbit_bytes_t out = moonbit_make_bytes_raw(8);
  if (out == NULL) {
    return moonbit_make_bytes_raw(0);
  }
  uint8_t *p = (uint8_t *)out;
  write_u32_le(p + 0, sr);
  write_u32_le(p + 4, buf);
  return out;
#else
  return moonbit_make_bytes_raw(0);
#endif
}
