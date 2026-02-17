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

## Latest Changes

- `0.11.1`: `spec.Data` now exposes the full numeric write API for raw output callbacks:
  - `write_i8`, `write_u8`, `write_u16`, `write_i16`
  - `write_u24`, `write_i24`, `write_u32`, `write_i32`
  - `write_f32`, `write_u64`, `write_i64`, `write_f64`
- This matches the `core.Data` write surface and unblocks downstream handling of more `SampleFormat` values in `build_output_stream_raw`.

## Native Link Strategy (`build.js`)

- The project uses Moon's prebuild hook (`--moonbit-unstable-prebuild`) with `build.js` to emit per-OS `link_configs`.
- This mirrors the `tonyfettes/raylib` style: keep `moon.pkg` files free of hard-coded cross-platform linker flag unions and let `build.js` choose the active platform link set.
- Linux/macOS/Windows now receive only their own native link requirements.
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
