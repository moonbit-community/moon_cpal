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

// -----------------------------------------------------------------------------
// ALSA supported config query (binary)
// -----------------------------------------------------------------------------
//
// Exported format (little-endian):
// - u32 record_count
// - repeated records of 6 u32 values:
//   (sample_format_tag, channels, min_rate, max_rate, buffer_min, buffer_max)
//
// sample_format_tag:
// - 1 => F32 (SND_PCM_FORMAT_FLOAT_LE)
// - 2 => I16 (SND_PCM_FORMAT_S16_LE)
//
// On non-Linux platforms, or on error, returns an empty bytes value.

static void write_u32_le(uint8_t *dst, uint32_t v) {
  dst[0] = (uint8_t)(v & 0xFFu);
  dst[1] = (uint8_t)((v >> 8) & 0xFFu);
  dst[2] = (uint8_t)((v >> 16) & 0xFFu);
  dst[3] = (uint8_t)((v >> 24) & 0xFFu);
}

moonbit_bytes_t moon_cpal_alsa_supported_configs_bin(uint8_t *device_id_utf8,
                                                    int32_t device_id_len,
                                                    uint32_t is_input) {
#if defined(__linux__)
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    moonbit_decref(device_id_utf8);
    return moonbit_make_bytes_raw(0);
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

  snd_pcm_t *pcm = NULL;
  snd_pcm_stream_t st = is_input ? SND_PCM_STREAM_CAPTURE : SND_PCM_STREAM_PLAYBACK;
  int err = snd_pcm_open(&pcm, id_buf, st, 0);
  if (err < 0 || pcm == NULL) {
    if (pcm != NULL) {
      snd_pcm_close(pcm);
    }
    return moonbit_make_bytes_raw(0);
  }

  snd_pcm_hw_params_t *hw = NULL;
  if (snd_pcm_hw_params_malloc(&hw) < 0 || hw == NULL) {
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }
  if (snd_pcm_hw_params_any(pcm, hw) < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }

  // Supported formats: keep in sync with the MoonBit stream builder.
  uint32_t fmt_tags[2];
  size_t fmt_count = 0;
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_FLOAT_LE) == 0) {
    fmt_tags[fmt_count++] = 1u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_S16_LE) == 0) {
    fmt_tags[fmt_count++] = 2u;
  }
  if (fmt_count == 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }

  unsigned int min_rate = 0, max_rate = 0;
  int dir = 0;
  if (snd_pcm_hw_params_get_rate_min(hw, &min_rate, &dir) < 0 ||
      snd_pcm_hw_params_get_rate_max(hw, &max_rate, &dir) < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }

  // Decide whether to return a continuous range or a list of discrete common rates.
  struct rate_pair {
    uint32_t min;
    uint32_t max;
  };
  struct rate_pair rates[64];
  size_t rate_count = 0;

  if (min_rate == max_rate || snd_pcm_hw_params_test_rate(pcm, hw, min_rate + 1, 0) == 0) {
    rates[rate_count++] = (struct rate_pair){(uint32_t)min_rate, (uint32_t)max_rate};
  } else {
    static const uint32_t COMMON_RATES[] = {
        5512u,   8000u,    11025u,   12000u,   16000u,  22050u,  24000u,
        32000u,  44100u,   48000u,   64000u,   88200u,  96000u,  176400u,
        192000u, 352800u,  384000u,  705600u,  768000u, 1411200u, 1536000u,
    };
    for (size_t i = 0; i < sizeof(COMMON_RATES) / sizeof(COMMON_RATES[0]); i++) {
      uint32_t r = COMMON_RATES[i];
      if (snd_pcm_hw_params_test_rate(pcm, hw, r, 0) == 0) {
        rates[rate_count++] = (struct rate_pair){r, r};
      }
    }
    if (rate_count == 0) {
      rates[rate_count++] = (struct rate_pair){(uint32_t)min_rate, (uint32_t)max_rate};
    }
  }

  unsigned int min_ch = 0, max_ch = 0;
  if (snd_pcm_hw_params_get_channels_min(hw, &min_ch) < 0 ||
      snd_pcm_hw_params_get_channels_max(hw, &max_ch) < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }
  if (max_ch > 32) {
    max_ch = 32;
  }

  uint32_t channels[64];
  size_t ch_count = 0;
  for (unsigned int ch = min_ch; ch <= max_ch; ch++) {
    if (snd_pcm_hw_params_test_channels(pcm, hw, ch) == 0) {
      channels[ch_count++] = (uint32_t)ch;
    }
  }
  if (ch_count == 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }

  snd_pcm_uframes_t min_buf = 0, max_buf = 0;
  if (snd_pcm_hw_params_get_buffer_size_min(hw, &min_buf) < 0 ||
      snd_pcm_hw_params_get_buffer_size_max(hw, &max_buf) < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return moonbit_make_bytes_raw(0);
  }
  // Clamp into u32 range and avoid a zero-length buffer range.
  uint32_t buf_min = (min_buf == 0) ? 1u
                                    : (min_buf > 0xFFFFFFFFu ? 0xFFFFFFFFu : (uint32_t)min_buf);
  uint32_t buf_max =
      (max_buf == 0) ? buf_min
                     : (max_buf > 0xFFFFFFFFu ? 0xFFFFFFFFu : (uint32_t)max_buf);
  if (buf_max < buf_min) {
    buf_max = buf_min;
  }

  snd_pcm_hw_params_free(hw);
  snd_pcm_close(pcm);

  uint64_t rec_count64 = (uint64_t)fmt_count * (uint64_t)ch_count * (uint64_t)rate_count;
  if (rec_count64 == 0 || rec_count64 > 1000000u) {
    return moonbit_make_bytes_raw(0);
  }
  uint32_t rec_count = (uint32_t)rec_count64;

  size_t out_len = 4u + (size_t)rec_count * 24u;
  moonbit_bytes_t out = moonbit_make_bytes_raw((int32_t)out_len);
  if (out == NULL) {
    return moonbit_make_bytes_raw(0);
  }

  uint8_t *p = (uint8_t *)out;
  write_u32_le(p, rec_count);
  p += 4;
  for (size_t fi = 0; fi < fmt_count; fi++) {
    uint32_t fmt_tag = fmt_tags[fi];
    for (size_t ci = 0; ci < ch_count; ci++) {
      uint32_t ch = channels[ci];
      for (size_t ri = 0; ri < rate_count; ri++) {
        write_u32_le(p + 0, fmt_tag);
        write_u32_le(p + 4, ch);
        write_u32_le(p + 8, rates[ri].min);
        write_u32_le(p + 12, rates[ri].max);
        write_u32_le(p + 16, buf_min);
        write_u32_le(p + 20, buf_max);
        p += 24;
      }
    }
  }

  return out;
#else
  (void)device_id_len;
  (void)is_input;
  moonbit_decref(device_id_utf8);
  return moonbit_make_bytes_raw(0);
#endif
}
