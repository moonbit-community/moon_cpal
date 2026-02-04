#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

// -----------------------------------------------------------------------------
// ALSA device discovery
// -----------------------------------------------------------------------------
//
// On Linux, we prefer libasound enumeration (`snd_device_name_hint`) for a stable and complete
// list of PCM devices.
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
  // Search for exact "<line>\n" matches to avoid prefix collisions.
  for (size_t i = 0; i + line_len + 1 <= len; i++) {
    if (buf[i + line_len] != '\n') {
      continue;
    }
    if (memcmp(buf + i, line, line_len) == 0) {
      // Ensure line boundary.
      if (i == 0 || buf[i - 1] == '\n') {
        return 1;
      }
    }
  }
  return 0;
}

#if defined(__linux__)
#include <alsa/asoundlib.h>

static void alsa_append_hint_names(char **buf, size_t *len, size_t *cap) {
  void **hints = NULL;
  int err = snd_device_name_hint(-1, "pcm", &hints);
  if (err != 0 || hints == NULL) {
    return;
  }

  for (void **p = hints; *p != NULL; p++) {
    char *name = snd_device_name_get_hint(*p, "NAME");
    if (name == NULL || name[0] == '\0') {
      if (name != NULL) {
        free(name);
      }
      continue;
    }

    // Skip a few pseudo entries that are not useful as device IDs.
    if (strcmp(name, "null") == 0) {
      free(name);
      continue;
    }

    size_t nlen = strlen(name);
    if (!buf_has_line(*buf, *len, name, nlen)) {
      buf_append(buf, len, cap, name, nlen);
      buf_append(buf, len, cap, "\n", 1);
    }
    free(name);
  }

  snd_device_name_free_hint(hints);
}
#endif

static void alsa_append_proc_pcm(char **buf, size_t *len, size_t *cap) {
#if defined(__linux__)
  if (buf == NULL || len == NULL || cap == NULL) {
    return;
  }

  FILE *f = fopen("/proc/asound/pcm", "r");
  if (f != NULL) {
    char line[512];
    while (fgets(line, (int)sizeof(line), f) != NULL) {
      // Parse leading "<card>-<device>:" token.
      unsigned int card = 0, dev = 0;
      if (sscanf(line, "%u-%u:", &card, &dev) == 2) {
        char id[64];
        snprintf(id, sizeof(id), "hw:%u,%u", card, dev);
        size_t id_len = strlen(id);
        if (!buf_has_line(*buf, *len, id, id_len)) {
          buf_append(buf, len, cap, id, id_len);
          buf_append(buf, len, cap, "\n", 1);
        }
      }
    }
    fclose(f);
  }

#else
  (void)buf;
  (void)len;
  (void)cap;
#endif
}

moonbit_bytes_t moon_cpal_alsa_devices_utf8(void) {
#if defined(__linux__)
  char *buf = NULL;
  size_t len = 0;
  size_t cap = 0;

  // Always include a "default" device first.
  buf_append_cstr(&buf, &len, &cap, "default\n");

  // Prefer libasound enumeration. If it fails, fall back to /proc parsing.
  size_t before = len;
#if defined(__linux__)
  alsa_append_hint_names(&buf, &len, &cap);
#endif
  if (len == before) {
    // No additional devices found; try the /proc fallback.
    alsa_append_proc_pcm(&buf, &len, &cap);
  }

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

// -----------------------------------------------------------------------------
// ALSA device name lookup
// -----------------------------------------------------------------------------
//
// Given a device id (UTF-8), return a human-readable name (UTF-8).
// Currently best-effort: uses `DESC` from snd_device_name_hint and falls back to the id itself.

static int alsa_is_default_id(const char *id, size_t len) {
  static const char *k = "default";
  size_t klen = 7;
  if (len != klen) {
    return 0;
  }
  return cstr_eq_n(id, k, klen);
}

static int alsa_copy_first_line(const char *desc, char *out, size_t out_len) {
  if (desc == NULL || out == NULL || out_len == 0) {
    return 0;
  }
  // DESC often contains multiple lines, e.g. "Built-in Audio\n..." - keep the first line only.
  size_t n = 0;
  while (desc[n] != '\0' && desc[n] != '\n' && n + 1 < out_len) {
    out[n] = desc[n];
    n++;
  }
  out[n] = '\0';
  return (int)n;
}

static int alsa_device_desc_utf8(const char *id, size_t id_len, char **out_desc) {
  if (out_desc == NULL) {
    return -1;
  }
  *out_desc = NULL;
#if defined(__linux__)
  void **hints = NULL;
  int err = snd_device_name_hint(-1, "pcm", &hints);
  if (err != 0 || hints == NULL) {
    return -1;
  }

  for (void **p = hints; *p != NULL; p++) {
    char *name = snd_device_name_get_hint(*p, "NAME");
    if (name == NULL) {
      continue;
    }
    if (strlen(name) == id_len && memcmp(name, id, id_len) == 0) {
      free(name);
      char *desc = snd_device_name_get_hint(*p, "DESC");
      if (desc == NULL || desc[0] == '\0') {
        if (desc != NULL) {
          free(desc);
        }
        snd_device_name_free_hint(hints);
        return -1;
      }
      *out_desc = desc; // caller frees
      snd_device_name_free_hint(hints);
      return 0;
    }
    free(name);
  }

  snd_device_name_free_hint(hints);
  return -1;
#else
  (void)id;
  (void)id_len;
  return -1;
#endif
}

int32_t moon_cpal_alsa_device_name_utf8_len(uint8_t *device_id_utf8, int32_t device_id_len) {
#if defined(__linux__)
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    return -1;
  }
  // Copy before decref: `device_id_utf8` is owned by this function.
  char id_buf[256];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';

  // Callee owns the bytes on the MoonBit side for convenience.
  moonbit_decref(device_id_utf8);

  if (alsa_is_default_id(id_buf, id_len)) {
    // Keep it stable and readable.
    return (int32_t)strlen("default");
  }

  char *desc = NULL;
  if (alsa_device_desc_utf8(id_buf, id_len, &desc) == 0 && desc != NULL) {
    char tmp[512];
    int n = alsa_copy_first_line(desc, tmp, sizeof(tmp));
    free(desc);
    if (n > 0) {
      return (int32_t)n;
    }
  }

  // Fallback: use the id.
  return (int32_t)id_len;
#else
  (void)device_id_len;
  moonbit_decref(device_id_utf8);
  return -1;
#endif
}

int32_t moon_cpal_alsa_device_name_utf8(uint8_t *device_id_utf8,
                                       int32_t device_id_len,
                                       uint8_t *out,
                                       int32_t out_len) {
#if defined(__linux__)
  if (out == NULL || out_len <= 0) {
    moonbit_decref(device_id_utf8);
    return 0;
  }
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    moonbit_decref(device_id_utf8);
    return -1;
  }
  // Copy before decref: `device_id_utf8` is owned by this function.
  char id_buf[256];
  size_t id_len = (size_t)device_id_len;
  if (id_len >= sizeof(id_buf)) {
    id_len = sizeof(id_buf) - 1;
  }
  memcpy(id_buf, device_id_utf8, id_len);
  id_buf[id_len] = '\0';

  moonbit_decref(device_id_utf8);

  const char *fallback = id_buf;
  size_t fallback_len = id_len;

  char name_buf[512];
  name_buf[0] = '\0';
  size_t name_len = 0;

  if (alsa_is_default_id(id_buf, id_len)) {
    fallback = "default";
    fallback_len = strlen(fallback);
  } else {
    char *desc = NULL;
    if (alsa_device_desc_utf8(id_buf, id_len, &desc) == 0 && desc != NULL) {
      int n = alsa_copy_first_line(desc, name_buf, sizeof(name_buf));
      free(desc);
      if (n > 0) {
        name_len = (size_t)n;
        fallback = name_buf;
        fallback_len = name_len;
      }
    }
  }

  if ((int32_t)fallback_len > out_len) {
    return (int32_t)fallback_len;
  }
  memcpy(out, fallback, fallback_len);
  return (int32_t)fallback_len;
#else
  (void)device_id_len;
  (void)out;
  (void)out_len;
  moonbit_decref(device_id_utf8);
  return -1;
#endif
}
