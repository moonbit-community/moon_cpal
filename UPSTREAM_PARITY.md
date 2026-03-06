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

- `lib.rs` — **DONE** (root API re-exports core/platform/traits surface, including iterator aliases, sample conversion helper, and common sample-rate table)
- `traits.rs` — **DONE** (MoonBit `HostTrait`/`DeviceTrait`/`StreamTrait` surface aligned with typed/raw stream builders and dynamic-dispatch wrappers)
- `error.rs` — **DONE** (Display-equivalent `to_string` parity + tests)
- `device_description.rs` — **DONE** (`direction_from_counts` parity + tests)
- `samples_formats.rs` — **DONE** (`SampleFormat::to_string` parity)
- `platform/mod.rs` — **DONE** (dynamic host/device/stream dispatch layer with `available_hosts`/`all_hosts`/`host_from_id` semantics and parity tests)
- `host/mod.rs` — **DONE** (native-only backend module structure + trait surface lives in `traits`)

Native hosts:

- `host/null/mod.rs` — **DONE** (fallback host only; no devices; stream/config APIs are unimplemented; deterministic callback-thread tests live in `internal/test_host`)
- `host/alsa/enumerate.rs` — **DONE** (hint enumeration + ALSA ctl/card/device physical probing for hw/plughw IDs, direction/description metadata, and `/proc/asound/pcm` fallback)
- `host/alsa/mod.rs` — **DONE** (default/supported config probing via real ALSA hw_params, expanded sample-format coverage, fixed-buffer semantics + errno mapping + lifecycle/callback tests)
- `host/jack/device.rs` — **DONE** (device ID/name/direction + server-derived config ranges + fixed-buffer semantics tests)
- `host/jack/stream.rs` — **DONE** (callback-thread model + timing tests + xrun/sample-rate-change/shutdown error mapping)
- `host/jack/mod.rs` — **DONE** (host/default device behavior aligned with Linux JACK backend model used by this port)
- `host/wasapi/com.rs` — **DONE** (STA `CoInitializeEx` with `RPC_E_CHANGED_MODE` tolerated; COM lifetime matches upstream)
- `host/wasapi/device.rs` — **DONE** (endpoint ID/default-device enumeration behavior aligned; description/name selection now follows DeviceDesc→FriendlyName fallback with error on missing both; supports_input/output derive from data_flow; mix-format + supported-config range probing covered)
- `host/wasapi/stream.rs` — **DONE** (callback-thread/event model aligned; render-endpoint loopback input semantics aligned; HRESULT mapping coverage extended for build/stream/play/pause paths)
- `host/wasapi/mod.rs` — **DONE** (module-level HRESULT→CPAL mapping unified and reused; host availability API exposed; device enumeration no longer synthesizes fallback default device)
- `host/coreaudio/mod.rs` — **DONE** (host/device/stream behaviors aligned for this AudioQueue-based native implementation, including stream invalidation delivery path)
- `host/coreaudio/macos/device.rs` — **DONE** (DeviceId UID semantics, direction/capability mapping, loopback-style output-device capture path, nominal sample-rate set/check + settle wait, and parity tests)
- `host/coreaudio/macos/enumerate.rs` — **DONE** (device ordering follows `kAudioHardwarePropertyDevices`; default input/output device mapping mirrors upstream)
- `host/coreaudio/macos/loopback.rs` — **DONE** (behavioral parity via output-device input-stream construction path in this port; CI/runtime smoke covered)
- `host/coreaudio/macos/property_listener.rs` — **DONE** (device-alive property listener wired in native C path; emits StreamInvalidated semantics via callback bridge)
- `host/coreaudio/macos/mod.rs` — **DONE** (stream build/play/pause/close + smoke/lifecycle coverage aligned with upstream tests intent)

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
- `ci/parity/check.js` differential snapshots against `cpal-reference`, comparing each host's
  full device enumeration plus supported/default config metadata, and default-device
  stream-build acceptance parity (raw builder + stable typed-builder formats)
- CI smoke commands for real I/O:
  - `cmd/macos_stream_smoke`
  - `cmd/alsa_stream_smoke`
  - `cmd/jack_stream_smoke`
  - `cmd/wasapi_stream_smoke`
