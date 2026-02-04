// Cross-platform wrapper for MoonBit native builds.
//
// Why this exists:
// - `moon.pkg.json` supports conditional compilation by backend/mode, not OS.
// - Some packages need OS-specific link flags (e.g. macOS `-framework ...`, Linux `-lasound`).
// - On Windows, a `.sh` wrapper isn't reliably executable when invoked by the native `moon` binary.
//
// In CI we compile this C file to `scripts/moon_cc.sh` (yes: keeping the `.sh` name),
// overwriting the shell script with a native executable. That makes the `cc` override work
// on Windows while preserving local developer UX (the checked-in `.sh` is used locally).
//
// The underlying compiler can be overridden via:
// - MOON_REAL_CC
// - CC

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <process.h>
#else
#include <unistd.h>
#endif

static const char *env_or_empty(const char *k) {
  const char *v = getenv(k);
  return (v == NULL) ? "" : v;
}

static int str_eq(const char *a, const char *b) { return strcmp(a, b) == 0; }

static int str_starts_with(const char *s, const char *prefix) {
  size_t n = strlen(prefix);
  return strncmp(s, prefix, n) == 0;
}

int main(int argc, char **argv) {
  if (argc <= 0 || argv == NULL) {
    return 127;
  }

  const char *real_cc = env_or_empty("MOON_REAL_CC");
  if (real_cc[0] == '\0') {
    real_cc = env_or_empty("CC");
  }
  if (real_cc[0] == '\0') {
    real_cc = "cc";
  }

#if defined(__APPLE__) && defined(__MACH__)
  const int is_darwin = 1;
#else
  const int is_darwin = 0;
#endif

#if defined(__linux__)
  const int is_linux = 1;
#else
  const int is_linux = 0;
#endif

#if defined(_WIN32)
  const int is_windows = 1;
#else
  const int is_windows = 0;
#endif

  // Filter flags.
  //
  // Keep the behavior aligned with `scripts/moon_cc.sh`:
  // - strip `-framework <name>` on non-Darwin
  // - strip `-lasound`/`-ljack` on non-Linux
  // - strip `-lole32/-luuid/-lmmdevapi/-lavrt` on non-Windows
  // - strip `-pthread/-lpthread` on Windows
  char **outv = (char **)calloc((size_t)argc + 1, sizeof(char *));
  if (outv == NULL) {
    return 127;
  }

  int outc = 0;
  outv[outc++] = (char *)real_cc;

  int skip_next = 0;
  for (int i = 1; i < argc; i++) {
    const char *a = argv[i];
    if (a == NULL) {
      continue;
    }

    if (skip_next) {
      skip_next = 0;
      continue;
    }

    // Darwin frameworks
    if (!is_darwin && str_eq(a, "-framework")) {
      skip_next = 1;
      continue;
    }
    if (!is_darwin && str_starts_with(a, "-Wl,-framework,")) {
      continue;
    }

    // Linux-only libs (ALSA)
    if (!is_linux && str_eq(a, "-lasound")) {
      continue;
    }
    // Linux-only libs (JACK)
    if (!is_linux && str_eq(a, "-ljack")) {
      continue;
    }

    // Windows-only libs (WASAPI/COM)
    if (!is_windows) {
      if (str_eq(a, "-lole32") || str_eq(a, "-luuid") || str_eq(a, "-lmmdevapi") || str_eq(a, "-lavrt")) {
        continue;
      }
    }

    // Avoid passing pthread flags to Windows toolchains.
    if (is_windows) {
      if (str_eq(a, "-pthread") || str_eq(a, "-lpthread")) {
        continue;
      }
    }

    outv[outc++] = argv[i];
  }

  outv[outc] = NULL;

#if defined(_WIN32)
  // Use spawn so we can return the compiler's exit code.
  int rc = _spawnvp(_P_WAIT, real_cc, (const char *const *)outv);
  if (rc == -1) {
    fprintf(stderr, "moon_cc: failed to spawn '%s'\n", real_cc);
    return 127;
  }
  return rc;
#else
  execvp(real_cc, outv);
  perror("moon_cc: execvp");
  return 127;
#endif
}
