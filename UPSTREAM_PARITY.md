# Upstream parity plan (native-only)

Pinned upstream: `cpal-reference/` at commit `6627959add25299a4e6077f45eb69721cfaaa14f` (see `UPSTREAM.md`).

This document tracks **file-by-file parity** with upstream `cpal-reference/src/` for the **native-only**
MoonBit port.

## Scope

- Supported targets: **native-only** (`moon.mod.json` sets `preferred-target: native`).
- In scope: desktop native backends + shared core APIs.
  - Linux: ALSA, JACK
  - macOS: CoreAudio (macOS)
  - Windows: WASAPI
  - Null backend (portable tests)
- Out of scope: non-desktop or non-native backends (AAudio/ASIO/WebAudio/etc).

## Status legend

- **DONE**: matched behavior + tests ported (or equivalent coverage in CI).
- **PARTIAL**: implemented subset; missing behavior/tests.
- **TODO**: not yet ported.

## In-scope upstream files

Top-level:

- `lib.rs` — **PARTIAL** (core types + some heuristics/tests exist; full trait surface pending)
- `error.rs` — **DONE** (Display-equivalent `to_string` parity + tests)
- `device_description.rs` — **DONE** (`direction_from_counts` parity + tests)
- `samples_formats.rs` — **DONE** (`SampleFormat::to_string` parity)
- `platform/mod.rs` — **PARTIAL**
- `host/mod.rs` — **PARTIAL**

Native hosts:

- `host/null/mod.rs` — **PARTIAL** (native callback-thread stream exists; parity details pending)
- `host/alsa/enumerate.rs` — **PARTIAL**
- `host/alsa/mod.rs` — **PARTIAL**
- `host/jack/device.rs` — **PARTIAL**
- `host/jack/stream.rs` — **PARTIAL**
- `host/jack/mod.rs` — **PARTIAL**
- `host/wasapi/com.rs` — **PARTIAL**
- `host/wasapi/device.rs` — **PARTIAL**
- `host/wasapi/stream.rs` — **PARTIAL**
- `host/wasapi/mod.rs` — **PARTIAL**
- `host/coreaudio/mod.rs` — **PARTIAL**
- `host/coreaudio/macos/device.rs` — **PARTIAL**
- `host/coreaudio/macos/enumerate.rs` — **PARTIAL**
- `host/coreaudio/macos/loopback.rs` — **PARTIAL**
- `host/coreaudio/macos/property_listener.rs` — **PARTIAL**
- `host/coreaudio/macos/mod.rs` — **PARTIAL**

## Out-of-scope upstream files (native-only)

The following upstream modules are not planned for this repository’s current scope:

- Android: `host/aaudio/**`
- Windows ASIO: `host/asio/**`
- Web/JS: `host/webaudio/**`, `host/audioworklet/**`, `host/emscripten/**`
- iOS: `host/coreaudio/ios/**`
- Custom host glue: `host/custom/**`

## Upstream test coverage notes

Upstream `#[test]` occurrences in `cpal-reference/` are currently:

- `cpal-reference/src/lib.rs` (heuristics + StreamInstant arithmetic)
- `cpal-reference/src/host/coreaudio/macos/mod.rs` (smoke-style play/record)

We keep equivalent coverage via:

- deterministic unit tests in MoonBit (`cpal_wbtest.mbt`, `cpal_time.mbt` tests)
- CI smoke commands for real I/O:
  - `cmd/macos_stream_smoke`
  - `cmd/alsa_stream_smoke`
  - `cmd/jack_stream_smoke`
  - `cmd/wasapi_stream_smoke`
