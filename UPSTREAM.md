# Upstream Reference

This repository tracks the RustAudio `cpal` crate as the reference behavior/source.

- Upstream repo: RustAudio/cpal
- Pinned commit (local checkout in `cpal-reference/`): `6627959add25299a4e6077f45eb69721cfaaa14f`

Notes:
- The initial MoonBit port focuses on the "pure core" parts that are deterministic and testable
  (e.g. config heuristics and timestamp arithmetic).
- Platform audio backends (ALSA/CoreAudio/WASAPI/...) are out of scope for the first slice.

