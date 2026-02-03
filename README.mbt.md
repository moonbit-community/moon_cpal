# moon_cpal

MoonBit port (initially a pure-core subset) of RustAudio `cpal`.

Pinned upstream reference: see `UPSTREAM.md`.

## Status

- `zhengyu/moon_cpal`: portable "pure core" slice (format heuristics, timestamps, sample-format helpers).
- `zhengyu/moon_cpal/macos`: macOS CoreAudio device discovery (native backend only; uses a C stub).
  - device listing + names
  - supported input/output config ranges (`SupportedStreamConfigRange`) for a device
  - default input/output config (`SupportedStreamConfig`) for a device
  - AudioQueue-backed input/output streams with MoonBit callback bridging (native)

## macOS smoke test (native)

```
moon run --target native cmd/macos_smoke
```

## macOS stream smoke test (native)

```
moon run --target native cmd/macos_stream_smoke
```

Note: framework link flags currently live in the *main* package (see `cmd/macos_smoke/moon.pkg.json`).

## macOS native tests

```
moon test --target native
```
