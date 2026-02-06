<!--
// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
-->

# moon_cpal

MoonBit port of RustAudio `cpal` (native-only).

Pinned upstream reference: see `UPSTREAM.md`.

## Status

- `Milky2018/moon_cpal`: public CPAL-like API (native-only): host/device/stream + core type re-exports.
- `Milky2018/moon_cpal/core`: pure core types/errors (configs, heuristics, timestamps, sample helpers).
- `Milky2018/moon_cpal/platform`: dynamic dispatch host/device/stream (backend selection).
- `Milky2018/moon_cpal/spec`: root API implementation backed by `platform`.
- `Milky2018/moon_cpal/traits`: CPAL-like `HostTrait`/`DeviceTrait`/`StreamTrait` implemented for the root types.
- Native backends (real I/O, callback-thread model):
  - macOS: CoreAudio (AudioQueue)
  - Linux: ALSA + JACK
  - Windows: WASAPI

Note: `moon.mod.json` sets `preferred-target: native`. Non-native targets are not supported.

## Native Link Strategy (`moon_cc`)

- The project uses `scripts/moon_cc.sh` (and CI-built `scripts/moon_cc.c`) as the native C/C++ wrapper.
- Reason: current Moon package metadata cannot express OS-conditional native linker flags for one package graph (`-framework` vs `-lasound/-ljack` vs `-lole32/...`) while this module keeps all native backends available in one API surface.
- The wrapper strips non-target linker flags and injects a stub `main` only for Moon's per-package library link checks.
- Downstream dependency smoke (`ci/downstream_smoke`) validates that `Milky2018/moon_cpal` compiles as a dependency across Linux/macOS/Windows with this strategy.

## Run unit tests (native)

```
moon test --target native
```

## Enumerate hosts/devices (native)

```
moon run --target native cmd/enumerate
```

## Stream smoke tests (native)

macOS:

```
moon run --target native cmd/macos_smoke
```

```
moon run --target native cmd/macos_stream_smoke
```

Linux:

```
moon run --target native cmd/alsa_stream_smoke
moon run --target native cmd/jack_stream_smoke
```

Windows:

```
moon run --target native cmd/wasapi_stream_smoke
```
