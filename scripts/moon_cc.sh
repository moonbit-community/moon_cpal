#!/usr/bin/env bash
set -euo pipefail

# A small compiler wrapper for Moon native builds.
#
# Motivation:
# - Moon's `moon.pkg.json` conditional compilation currently supports backend/mode but not OS.
# - Some packages (e.g. `macos`) need darwin-only link flags like `-framework ...`.
# - This wrapper strips `-framework` flags on non-Darwin platforms so the module can build.
#
# The underlying compiler can be overridden via:
# - MOON_REAL_CC
# - CC

REAL_CC="${MOON_REAL_CC:-${CC:-cc}}"
OS="$(uname -s 2>/dev/null || echo unknown)"

is_darwin=0
is_windows=0
is_linux=0

if [[ "$OS" == "Darwin" ]]; then
  is_darwin=1
elif [[ "$OS" == "Linux" ]]; then
  is_linux=1
elif [[ "$OS" == MINGW* || "$OS" == MSYS* || "$OS" == CYGWIN* ]]; then
  is_windows=1
fi

# Moon currently links per-package "executables" for packages that specify `link.native`,
# even when the package is a library and has no `main`. That breaks `moon build --target native`
# with an undefined symbol error for `_main`.
#
# Workaround: when we detect a per-package link output like:
#   .../_build/native/.../build/<pkg>/<pkg>.exe
# (excluding `cmd/*` binaries), we inject a tiny stub `main` object into the link.
#
# This keeps `moon build` green without affecting the actual library archives (`lib*.a`) or
# real binaries (`cmd/*`), which already provide `main`.
out_path=""
prev=""
for arg in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    out_path="$arg"
    prev=""
    continue
  fi
  if [[ "$arg" == "-o" ]]; then
    prev="-o"
  fi
done

need_stub_main=0
if [[ -n "$out_path" && "$out_path" == *"/_build/"* && "$out_path" == *"/build/"* && "$out_path" == *.exe ]]; then
  if [[ "$out_path" != *"/build/cmd/"* ]]; then
    exe_base="${out_path##*/}"
    exe_base="${exe_base%.exe}"
    exe_dir="${out_path%/*}"
    pkg_dir="${exe_dir##*/}"
    if [[ "$pkg_dir" == "$exe_base" ]]; then
      need_stub_main=1
    fi
  fi
fi

# We cannot express OS constraints in `moon.pkg.json`, so packages may carry OS-specific
# linker flags. Filter them out on non-matching OSes.
filtered=()
skip_next=0
for arg in "$@"; do
  if [[ $skip_next -eq 1 ]]; then
    skip_next=0
    continue
  fi

  # Darwin frameworks
  if [[ $is_darwin -eq 0 && "$arg" == "-framework" ]]; then
    skip_next=1
    continue
  fi
  if [[ $is_darwin -eq 0 && "$arg" == -Wl,-framework,* ]]; then
    continue
  fi

  # Linux-only libs (ALSA)
  if [[ $is_linux -eq 0 && "$arg" == "-lasound" ]]; then
    continue
  fi
  # Linux-only libs (JACK)
  if [[ $is_linux -eq 0 && "$arg" == "-ljack" ]]; then
    continue
  fi
  # Some toolchains pass `-Wl,-lxxx` sometimes; keep it simple and handle common direct flags only.

  # Windows-only libs (WASAPI/COM)
  if [[ $is_windows -eq 0 ]]; then
    case "$arg" in
      -lole32|-luuid|-lmmdevapi|-lavrt)
        continue
        ;;
    esac
  fi
  # Avoid passing pthread flags to Windows toolchains.
  if [[ $is_windows -eq 1 ]]; then
    case "$arg" in
      -pthread|-lpthread)
        continue
        ;;
    esac
  fi

  filtered+=("$arg")
done

if [[ $need_stub_main -eq 1 ]]; then
  root="${out_path%%/_build/*}"
  stub_c="$root/_build/moon_cc_stub_main.c"
  stub_o="$root/_build/moon_cc_stub_main.o"
  mkdir -p "$root/_build"
  if [[ ! -f "$stub_o" ]]; then
    printf '%s\n' 'int main(void) { return 0; }' >"$stub_c"
    "$REAL_CC" -c "$stub_c" -o "$stub_o"
  fi
  filtered+=("$stub_o")
fi

if [[ ${#filtered[@]} -eq 0 ]]; then
  exec "$REAL_CC"
fi

exec "$REAL_CC" "${filtered[@]}"
