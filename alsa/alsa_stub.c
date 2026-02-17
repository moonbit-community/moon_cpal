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

static int ascii_lower(int ch) {
  if (ch >= 'A' && ch <= 'Z') {
    return ch + ('a' - 'A');
  }
  return ch;
}

static int cstr_case_eq(const char *a, const char *b) {
  if (a == NULL || b == NULL) {
    return 0;
  }
  while (*a != '\0' && *b != '\0') {
    if (ascii_lower((unsigned char)*a) != ascii_lower((unsigned char)*b)) {
      return 0;
    }
    a++;
    b++;
  }
  return *a == '\0' && *b == '\0';
}

static int buf_has_id(const char *buf, size_t len, const char *id, size_t id_len) {
  if (buf == NULL || len == 0 || id == NULL || id_len == 0) {
    return 0;
  }
  // Each line is: "<id>\t<dir>\t<desc_escaped>\n" (desc may be empty).
  // Dedupe on <id> only.
  size_t i = 0;
  while (i < len) {
    size_t line_start = i;
    // Find end-of-line.
    size_t line_end = i;
    while (line_end < len && buf[line_end] != '\n') {
      line_end++;
    }
    // Find end of id field (tab or EOL).
    size_t field_end = line_start;
    while (field_end < line_end && buf[field_end] != '\t') {
      field_end++;
    }
    size_t field_len = field_end - line_start;
    if (field_len == id_len && memcmp(buf + line_start, id, id_len) == 0) {
      return 1;
    }
    i = (line_end < len) ? (line_end + 1) : len;
  }
  return 0;
}

static void buf_append_escaped(char **buf, size_t *len, size_t *cap, const char *s) {
  if (s == NULL) {
    return;
  }
  for (const char *p = s; *p != '\0'; p++) {
    char c = *p;
    if (c == '\\') {
      buf_append(buf, len, cap, "\\\\", 2);
    } else if (c == '\n') {
      buf_append(buf, len, cap, "\\n", 2);
    } else if (c == '\t') {
      buf_append(buf, len, cap, "\\t", 2);
    } else if (c == '\r') {
      // drop
    } else {
      buf_append(buf, len, cap, &c, 1);
    }
  }
}

static void buf_append_device_line(char **buf,
                                   size_t *len,
                                   size_t *cap,
                                   const char *id,
                                   char dir_tag,
                                   const char *desc) {
  if (id == NULL || id[0] == '\0') {
    return;
  }
  size_t id_len = strlen(id);
  if (buf_has_id(*buf, *len, id, id_len)) {
    return;
  }
  buf_append(buf, len, cap, id, id_len);
  buf_append(buf, len, cap, "\t", 1);
  buf_append(buf, len, cap, &dir_tag, 1);
  buf_append(buf, len, cap, "\t", 1);
  buf_append_escaped(buf, len, cap, desc);
  buf_append(buf, len, cap, "\n", 1);
}

#if defined(__linux__)
#include <alsa/asoundlib.h>

static char alsa_dir_tag_from_ioid(const char *ioid) {
  // Per ALSA docs: NULL IOID => both input/output.
  if (ioid == NULL) {
    return 'd';
  }
  if (cstr_case_eq(ioid, "Input")) {
    return 'i';
  }
  if (cstr_case_eq(ioid, "Output")) {
    return 'o';
  }
  return 'd';
}

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

    char *ioid = snd_device_name_get_hint(*p, "IOID");
    char dir_tag = alsa_dir_tag_from_ioid(ioid);
    char *desc = snd_device_name_get_hint(*p, "DESC");
    buf_append_device_line(buf, len, cap, name, dir_tag, desc);
    if (ioid != NULL) {
      free(ioid);
    }
    if (desc != NULL) {
      free(desc);
    }
    free(name);
  }

  snd_device_name_free_hint(hints);
}
static void alsa_append_physical_devices(char **buf, size_t *len, size_t *cap) {
  if (buf == NULL || len == NULL || cap == NULL) {
    return;
  }

  int card = -1;
  if (snd_card_next(&card) < 0) {
    return;
  }
  while (card >= 0) {
    char ctl_name[64];
    snprintf(ctl_name, sizeof(ctl_name), "hw:%d", card);
    snd_ctl_t *ctl = NULL;
    if (snd_ctl_open(&ctl, ctl_name, 0) >= 0 && ctl != NULL) {
      snd_ctl_card_info_t *card_info = NULL;
      snd_ctl_card_info_alloca(&card_info);
      char card_name[256];
      card_name[0] = '\0';
      if (snd_ctl_card_info(ctl, card_info) >= 0) {
        const char *name = snd_ctl_card_info_get_name(card_info);
        if (name != NULL && name[0] != '\0') {
          snprintf(card_name, sizeof(card_name), "%s", name);
        }
      }

      int device = -1;
      while (1) {
        if (snd_ctl_pcm_next_device(ctl, &device) < 0 || device < 0) {
          break;
        }

        int has_playback = 0;
        int has_capture = 0;
        char device_name[256];
        device_name[0] = '\0';

        snd_pcm_info_t *pcm_info = NULL;
        snd_pcm_info_alloca(&pcm_info);
        snd_pcm_info_set_device(pcm_info, (unsigned int)device);
        snd_pcm_info_set_subdevice(pcm_info, 0);

        snd_pcm_info_set_stream(pcm_info, SND_PCM_STREAM_PLAYBACK);
        if (snd_ctl_pcm_info(ctl, pcm_info) >= 0) {
          has_playback = 1;
          const char *name = snd_pcm_info_get_name(pcm_info);
          if (name != NULL && name[0] != '\0') {
            snprintf(device_name, sizeof(device_name), "%s", name);
          }
        }

        snd_pcm_info_set_device(pcm_info, (unsigned int)device);
        snd_pcm_info_set_subdevice(pcm_info, 0);
        snd_pcm_info_set_stream(pcm_info, SND_PCM_STREAM_CAPTURE);
        if (snd_ctl_pcm_info(ctl, pcm_info) >= 0) {
          has_capture = 1;
          if (device_name[0] == '\0') {
            const char *name = snd_pcm_info_get_name(pcm_info);
            if (name != NULL && name[0] != '\0') {
              snprintf(device_name, sizeof(device_name), "%s", name);
            }
          }
        }

        if (!has_playback && !has_capture) {
          continue;
        }

        char dir_tag = '?';
        if (has_playback && has_capture) {
          dir_tag = 'd';
        } else if (has_playback) {
          dir_tag = 'o';
        } else if (has_capture) {
          dir_tag = 'i';
        }

        char first_line[512];
        if (card_name[0] != '\0' && device_name[0] != '\0') {
          snprintf(first_line, sizeof(first_line), "%s, %s", card_name, device_name);
        } else if (card_name[0] != '\0') {
          snprintf(first_line, sizeof(first_line), "%s", card_name);
        } else if (device_name[0] != '\0') {
          snprintf(first_line, sizeof(first_line), "%s", device_name);
        } else {
          snprintf(first_line, sizeof(first_line), "Card %d", card);
        }

        for (int i = 0; i < 2; i++) {
          const char *prefix = (i == 0) ? "hw" : "plughw";
          char id[64];
          snprintf(id, sizeof(id), "%s:CARD=%d,DEV=%d", prefix, card, device);
          const char *second_line = (i == 0)
                                        ? "Direct hardware device without any conversions"
                                        : "Hardware device with all software conversions";
          char desc[1024];
          snprintf(desc, sizeof(desc), "%s\n%s", first_line, second_line);
          buf_append_device_line(buf, len, cap, id, dir_tag, desc);
        }
      }
      snd_ctl_close(ctl);
    }

    if (snd_card_next(&card) < 0) {
      break;
    }
  }
}

static void alsa_append_proc_pcm(char **buf, size_t *len, size_t *cap) {
  if (buf == NULL || len == NULL || cap == NULL) {
    return;
  }

  FILE *f = fopen("/proc/asound/pcm", "r");
  if (f == NULL) {
    return;
  }
  char line[512];
  while (fgets(line, (int)sizeof(line), f) != NULL) {
    unsigned int card = 0, dev = 0;
    if (sscanf(line, "%u-%u:", &card, &dev) != 2) {
      continue;
    }
    int playback = (strstr(line, "playback") != NULL) ? 1 : 0;
    int capture = (strstr(line, "capture") != NULL) ? 1 : 0;
    char dir_tag = '?';
    if (playback > 0 && capture > 0) {
      dir_tag = 'd';
    } else if (playback > 0) {
      dir_tag = 'o';
    } else if (capture > 0) {
      dir_tag = 'i';
    }

    for (int i = 0; i < 2; i++) {
      const char *prefix = (i == 0) ? "hw" : "plughw";
      char id[64];
      snprintf(id, sizeof(id), "%s:CARD=%u,DEV=%u", prefix, card, dev);
      buf_append_device_line(buf, len, cap, id, dir_tag, NULL);
    }
  }
  fclose(f);
}
#endif

moonbit_bytes_t moon_cpal_alsa_devices_utf8(void) {
#if defined(__linux__)
  char *buf = NULL;
  size_t len = 0;
  size_t cap = 0;

  // Always include a "default" device first.
  buf_append_device_line(&buf, &len, &cap, "default", 'd', NULL);

  // Mirror upstream CPAL style: include both hint devices (virtual/plugins) and physical devices
  // (hw:/plughw:) and dedupe by PCM id.
  alsa_append_hint_names(&buf, &len, &cap);
  size_t before_physical = len;
  alsa_append_physical_devices(&buf, &len, &cap);
  // Keep `/proc/asound/pcm` as a fallback when ctl probing returns nothing.
  if (len == before_physical) {
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
// ALSA supported config query (binary)
// -----------------------------------------------------------------------------
//
// Exported format (little-endian):
// - i32 status (0 on success, negative errno-style on failure)
// - u32 record_count
// - repeated records of 6 u32 values:
//   (sample_format_tag, channels, min_rate, max_rate, buffer_min, buffer_max)
//
// sample_format_tag:
// - 1 => F32 (SND_PCM_FORMAT_FLOAT_LE)
// - 2 => I16 (SND_PCM_FORMAT_S16_LE)
// - 3 => U16 (SND_PCM_FORMAT_U16_LE)
// - 4 => U8  (SND_PCM_FORMAT_U8)
// - 5 => I32 (SND_PCM_FORMAT_S32_LE)
// - 6 => U32 (SND_PCM_FORMAT_U32_LE)
// - 7 => I24 (SND_PCM_FORMAT_S24_LE)
// - 8 => U24 (SND_PCM_FORMAT_U24_LE)
// - 9 => F64 (SND_PCM_FORMAT_FLOAT64_LE)
// - 10 => I8 (SND_PCM_FORMAT_S8)
//
// On non-Linux platforms, returns an empty bytes value.
// On Linux, always returns at least 8 bytes. On error, `record_count` is 0 and `status` is set.

static void write_u32_le(uint8_t *dst, uint32_t v) {
  dst[0] = (uint8_t)(v & 0xFFu);
  dst[1] = (uint8_t)((v >> 8) & 0xFFu);
  dst[2] = (uint8_t)((v >> 16) & 0xFFu);
  dst[3] = (uint8_t)((v >> 24) & 0xFFu);
}

static void write_i32_le(uint8_t *dst, int32_t v) { write_u32_le(dst, (uint32_t)v); }

static moonbit_bytes_t alsa_status_only(int32_t status) {
  moonbit_bytes_t out = moonbit_make_bytes_raw(8);
  if (out == NULL) {
    return moonbit_make_bytes_raw(0);
  }
  uint8_t *p = (uint8_t *)out;
  write_i32_le(p + 0, status);
  write_u32_le(p + 4, 0u);
  return out;
}

moonbit_bytes_t moon_cpal_alsa_supported_configs_bin(uint8_t *device_id_utf8,
                                                    int32_t device_id_len,
                                                    uint32_t is_input) {
#if defined(__linux__)
  if (device_id_utf8 == NULL || device_id_len <= 0) {
    moonbit_decref(device_id_utf8);
    return alsa_status_only(-22 /* EINVAL */);
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
    return alsa_status_only((int32_t)err);
  }

  snd_pcm_hw_params_t *hw = NULL;
  if (snd_pcm_hw_params_malloc(&hw) < 0 || hw == NULL) {
    snd_pcm_close(pcm);
    return alsa_status_only(-12 /* ENOMEM */);
  }
  err = snd_pcm_hw_params_any(pcm, hw);
  if (err < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return alsa_status_only((int32_t)err);
  }

  // Supported formats: keep in sync with the MoonBit stream builder.
  uint32_t fmt_tags[10];
  size_t fmt_count = 0;
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_FLOAT_LE) == 0) {
    fmt_tags[fmt_count++] = 1u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_S16_LE) == 0) {
    fmt_tags[fmt_count++] = 2u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_U16_LE) == 0) {
    fmt_tags[fmt_count++] = 3u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_U8) == 0) {
    fmt_tags[fmt_count++] = 4u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_S32_LE) == 0) {
    fmt_tags[fmt_count++] = 5u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_U32_LE) == 0) {
    fmt_tags[fmt_count++] = 6u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_S24_LE) == 0) {
    fmt_tags[fmt_count++] = 7u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_U24_LE) == 0) {
    fmt_tags[fmt_count++] = 8u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_FLOAT64_LE) == 0) {
    fmt_tags[fmt_count++] = 9u;
  }
  if (snd_pcm_hw_params_test_format(pcm, hw, SND_PCM_FORMAT_S8) == 0) {
    fmt_tags[fmt_count++] = 10u;
  }
  if (fmt_count == 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return alsa_status_only(-22 /* EINVAL */);
  }

  unsigned int min_rate = 0, max_rate = 0;
  int dir = 0;
  if (snd_pcm_hw_params_get_rate_min(hw, &min_rate, &dir) < 0 ||
      snd_pcm_hw_params_get_rate_max(hw, &max_rate, &dir) < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return alsa_status_only(-5 /* EIO */);
  }
  // `min_rate`/`max_rate` may be reported as very large values by some virtual devices
  // (e.g. "null" plugin). We serialize as u32 but decode into signed Int on the MoonBit
  // side, so clamp to i32::MAX to avoid negative values after decoding.
  if (min_rate == 0) {
    min_rate = 1;
  }
  if (min_rate > 0x7FFFFFFFu) {
    min_rate = 0x7FFFFFFFu;
  }
  if (max_rate > 0x7FFFFFFFu) {
    max_rate = 0x7FFFFFFFu;
  }
  if (max_rate < min_rate) {
    max_rate = min_rate;
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
    return alsa_status_only(-5 /* EIO */);
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
    return alsa_status_only(-22 /* EINVAL */);
  }

  snd_pcm_uframes_t min_buf = 0, max_buf = 0;
  if (snd_pcm_hw_params_get_buffer_size_min(hw, &min_buf) < 0 ||
      snd_pcm_hw_params_get_buffer_size_max(hw, &max_buf) < 0) {
    snd_pcm_hw_params_free(hw);
    snd_pcm_close(pcm);
    return alsa_status_only(-5 /* EIO */);
  }
  // Clamp into i32 range and avoid a zero-length buffer range (see note above).
  uint32_t buf_min = (min_buf == 0) ? 1u
                                    : (min_buf > 0x7FFFFFFFu ? 0x7FFFFFFFu : (uint32_t)min_buf);
  uint32_t buf_max =
      (max_buf == 0) ? buf_min
                     : (max_buf > 0x7FFFFFFFu ? 0x7FFFFFFFu : (uint32_t)max_buf);
  if (buf_max < buf_min) {
    buf_max = buf_min;
  }

  snd_pcm_hw_params_free(hw);
  snd_pcm_close(pcm);

  uint64_t rec_count64 = (uint64_t)fmt_count * (uint64_t)ch_count * (uint64_t)rate_count;
  if (rec_count64 == 0 || rec_count64 > 1000000u) {
    return alsa_status_only(-22 /* EINVAL */);
  }
  uint32_t rec_count = (uint32_t)rec_count64;

  size_t out_len = 8u + (size_t)rec_count * 24u;
  moonbit_bytes_t out = moonbit_make_bytes_raw((int32_t)out_len);
  if (out == NULL) {
    return moonbit_make_bytes_raw(0);
  }

  uint8_t *p = (uint8_t *)out;
  write_i32_le(p + 0, 0);
  write_u32_le(p + 4, rec_count);
  p += 8;
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
