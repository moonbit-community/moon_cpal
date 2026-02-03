#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

// -----------------------------------------------------------------------------
// ALSA device discovery (best-effort, no libasound dependency)
// -----------------------------------------------------------------------------
//
// To keep the project building without extra system linker flags, this file avoids linking
// against libasound and instead reads `/proc/asound/pcm` on Linux.
//
// Exported format: UTF-8, newline-separated device IDs.
// Example:
//   default
//   hw:0,0
//   hw:1,0
//
// On non-Linux platforms, returns an empty bytes value.

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

moonbit_bytes_t moon_cpal_alsa_devices_utf8(void) {
#if defined(__linux__)
  char *buf = NULL;
  size_t len = 0;
  size_t cap = 0;

  // Always include a "default" device.
  buf_append_cstr(&buf, &len, &cap, "default\n");

  FILE *f = fopen("/proc/asound/pcm", "r");
  if (f != NULL) {
    char line[512];
    while (fgets(line, (int)sizeof(line), f) != NULL) {
      // Parse leading "<card>-<device>:" token.
      unsigned int card = 0, dev = 0;
      if (sscanf(line, "%u-%u:", &card, &dev) == 2) {
        char tmp[64];
        snprintf(tmp, sizeof(tmp), "hw:%u,%u\n", card, dev);
        buf_append_cstr(&buf, &len, &cap, tmp);
      }
    }
    fclose(f);
  }

  if (len == 0) {
    // Should not happen due to "default\n", but keep it robust.
    moonbit_bytes_t empty = moonbit_make_bytes_raw(0);
    return empty;
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

