# moon_cpal

MoonBit port of RustAudio `cpal` (native-only).

Pinned upstream reference: see `UPSTREAM.md`.

## Status

- `Milky2018/moon_cpal`: core CPAL-like types (configs, heuristics, timestamps, sample helpers).
- `Milky2018/moon_cpal/spec`: CPAL-like host/device/stream API backed by `platform` dynamic dispatch.
- Native backends (real I/O, callback-thread model):
  - macOS: CoreAudio (AudioQueue)
  - Linux: ALSA + JACK
  - Windows: WASAPI

Note: `moon.mod.json` sets `preferred-target: native`. Non-native targets are not supported.

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
