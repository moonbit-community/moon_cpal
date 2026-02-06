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

- `lib.rs` — **PARTIAL** (root API now re-exports platform + core via `core/` split; iterator-style APIs implemented via `Iter`; remaining: finish re-export surface + docs)
- `traits.rs` — **PARTIAL** (MoonBit `traits` package exists; iterator return types implemented via `Iter`; remaining: upstream-associated iterator wrapper types if needed)
- `error.rs` — **DONE** (Display-equivalent `to_string` parity + tests)
- `device_description.rs` — **DONE** (`direction_from_counts` parity + tests)
- `samples_formats.rs` — **DONE** (`SampleFormat::to_string` parity)
- `platform/mod.rs` — **PARTIAL**
- `host/mod.rs` — **DONE** (native-only backend module structure + trait surface lives in `traits`)

Native hosts:

- `host/null/mod.rs` — **DONE** (fallback host only; no devices; stream/config APIs are unimplemented; deterministic callback-thread tests live in `internal/test_host`)
- `host/alsa/enumerate.rs` — **PARTIAL** (hints + hw/plughw physical IDs, direction+DESC metadata; still missing alsa-rs style physical probing parity)
- `host/alsa/mod.rs` — **PARTIAL**
- `host/jack/device.rs` — **PARTIAL**
- `host/jack/stream.rs` — **PARTIAL**
- `host/jack/mod.rs` — **PARTIAL**
- `host/wasapi/com.rs` — **DONE** (STA `CoInitializeEx` with `RPC_E_CHANGED_MODE` tolerated; COM lifetime matches upstream)
- `host/wasapi/device.rs` — **DONE** (endpoint ID/default-device enumeration behavior aligned; description/name selection now follows DeviceDesc→FriendlyName fallback with error on missing both; supports_input/output derive from data_flow; mix-format + supported-config range probing covered)
- `host/wasapi/stream.rs` — **DONE** (callback-thread/event model aligned; render-endpoint loopback input semantics aligned; HRESULT mapping coverage extended for build/stream/play/pause paths)
- `host/wasapi/mod.rs` — **DONE** (module-level HRESULT→CPAL mapping unified and reused; host availability API exposed; device enumeration no longer synthesizes fallback default device)
- `host/coreaudio/mod.rs` — **PARTIAL**
- `host/coreaudio/macos/device.rs` — **PARTIAL** (DeviceId now uses UID-only semantics; missing UID now surfaces as DeviceIdError via platform wrapper; supports_input/output now map to native channel-count queries; output-device input path no longer rejects early as StreamConfigNotSupported and now follows loopback-style config selection)
- `host/coreaudio/macos/enumerate.rs` — **DONE** (device ordering follows `kAudioHardwarePropertyDevices`; default input/output device mapping mirrors upstream)
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
