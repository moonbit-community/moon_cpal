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

if [[ "$OS" != "Darwin" ]]; then
  filtered=()
  skip_next=0
  for arg in "$@"; do
    if [[ $skip_next -eq 1 ]]; then
      skip_next=0
      continue
    fi
    if [[ "$arg" == "-framework" ]]; then
      skip_next=1
      continue
    fi
    # Some toolchains may pass linker flags in the `-Wl,` form.
    if [[ "$arg" == -Wl,-framework,* ]]; then
      continue
    fi
    filtered+=("$arg")
  done
  exec "$REAL_CC" "${filtered[@]}"
else
  exec "$REAL_CC" "$@"
fi

