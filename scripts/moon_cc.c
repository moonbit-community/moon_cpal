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
#include <direct.h>
#else
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
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

static int str_ends_with(const char *s, const char *suffix) {
  if (s == NULL || suffix == NULL) {
    return 0;
  }
  size_t ns = strlen(s);
  size_t nf = strlen(suffix);
  if (nf > ns) {
    return 0;
  }
  return strcmp(s + (ns - nf), suffix) == 0;
}

static const char *find_build_marker(const char *path) {
  if (path == NULL) {
    return NULL;
  }
  const char *p = strstr(path, "/_build/");
  if (p != NULL) {
    return p;
  }
  p = strstr(path, "\\_build\\");
  if (p != NULL) {
    return p;
  }
  return NULL;
}

static int path_contains(const char *s, const char *needle) {
  if (s == NULL || needle == NULL) {
    return 0;
  }
  return strstr(s, needle) != NULL;
}

static void make_dir_best_effort(const char *p) {
  if (p == NULL || p[0] == '\0') {
    return;
  }
#if defined(_WIN32)
  _mkdir(p);
#else
  mkdir(p, 0777);
#endif
}

static int file_exists(const char *p) {
  if (p == NULL || p[0] == '\0') {
    return 0;
  }
  FILE *f = fopen(p, "rb");
  if (f == NULL) {
    return 0;
  }
  fclose(f);
  return 1;
}

static int write_file(const char *path, const char *contents) {
  FILE *f = fopen(path, "wb");
  if (f == NULL) {
    return 0;
  }
  size_t n = strlen(contents);
  size_t wrote = fwrite(contents, 1, n, f);
  fclose(f);
  return wrote == n;
}

static int run_compiler(const char *real_cc, char *const *args) {
#if defined(_WIN32)
  int rc = _spawnvp(_P_WAIT, real_cc, (const char *const *)args);
  return (rc == -1) ? 127 : rc;
#else
  pid_t pid = fork();
  if (pid < 0) {
    return 127;
  }
  if (pid == 0) {
    execvp(real_cc, args);
    _exit(127);
  }
  int st = 0;
  if (waitpid(pid, &st, 0) < 0) {
    return 127;
  }
  if (WIFEXITED(st)) {
    return WEXITSTATUS(st);
  }
  return 127;
#endif
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
  // +8 to allow appending a stub main object when needed.
  char **outv = (char **)calloc((size_t)argc + 8, sizeof(char *));
  if (outv == NULL) {
    return 127;
  }

  int outc = 0;
  outv[outc++] = (char *)real_cc;

  const char *out_path = NULL;

  int skip_next = 0;
  for (int i = 1; i < argc; i++) {
    const char *a = argv[i];
    if (a == NULL) {
      continue;
    }

    if (out_path == NULL && i > 0 && str_eq(argv[i - 1], "-o")) {
      out_path = a;
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

  // Moon currently links per-package "executables" for library packages that specify `link.native`,
  // even when they have no `main`. That makes `moon build --target native` fail with an undefined
  // symbol error for `_main`.
  //
  // Workaround: when we detect a per-package output like:
  //   .../_build/native/.../build/<pkg>/<pkg>.exe
  // (excluding `cmd/*` binaries), inject a tiny stub main object into the link.
  int need_stub_main = 0;
  if (out_path != NULL && str_ends_with(out_path, ".exe") && find_build_marker(out_path) != NULL &&
      path_contains(out_path, "/build/") && !path_contains(out_path, "/build/cmd/")) {
    const char *slash = strrchr(out_path, '/');
    const char *bslash = strrchr(out_path, '\\');
    const char *sep = slash;
    if (bslash != NULL && (sep == NULL || bslash > sep)) {
      sep = bslash;
    }
    const char *base = (sep == NULL) ? out_path : sep + 1;
    size_t base_len = strlen(base);
    if (base_len > 4 && strcmp(base + base_len - 4, ".exe") == 0) {
      base_len -= 4;
    }
    // Folder name equals basename: .../build/<pkg>/<pkg>.exe
    const char *dir_end = sep;
    if (dir_end != NULL) {
      const char *dir_sep = dir_end;
      while (dir_sep > out_path && dir_sep[-1] != '/' && dir_sep[-1] != '\\') {
        dir_sep--;
      }
      size_t dir_len = (size_t)(dir_end - dir_sep);
      if (dir_len == base_len && strncmp(dir_sep, base, base_len) == 0) {
        need_stub_main = 1;
      }
    }
  }

  if (need_stub_main) {
    const char *m = find_build_marker(out_path);
    size_t root_len = (size_t)(m - out_path);
    char *root = (char *)calloc(root_len + 1, 1);
    if (root == NULL) {
      return 127;
    }
    memcpy(root, out_path, root_len);
    root[root_len] = '\0';

    char build_dir[4096];
    char stub_c[4096];
    char stub_o[4096];
    snprintf(build_dir, sizeof(build_dir), "%s/_build", root);
    snprintf(stub_c, sizeof(stub_c), "%s/_build/moon_cc_stub_main.c", root);
    snprintf(stub_o, sizeof(stub_o), "%s/_build/moon_cc_stub_main.o", root);
    free(root);

    make_dir_best_effort(build_dir);
    if (!file_exists(stub_o)) {
      if (!write_file(stub_c, "int main(void) { return 0; }\n")) {
        fprintf(stderr, "moon_cc: failed to write stub main source\n");
        return 127;
      }
      char *ccv[6];
      ccv[0] = (char *)real_cc;
      ccv[1] = (char *)"-c";
      ccv[2] = stub_c;
      ccv[3] = (char *)"-o";
      ccv[4] = stub_o;
      ccv[5] = NULL;
      int rc = run_compiler(real_cc, ccv);
      if (rc != 0) {
        fprintf(stderr, "moon_cc: failed to compile stub main (rc=%d)\n", rc);
        return rc;
      }
    }
    outv[outc++] = strdup(stub_o);
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
