# Upstream Reference

This repository tracks the RustAudio `cpal` crate as the reference behavior/source.

- Upstream repo: RustAudio/cpal
- Pinned commit (local checkout in `cpal-reference/`): `6627959add25299a4e6077f45eb69721cfaaa14f`

Notes:
- The MoonBit port started with a deterministic, testable “pure core” slice (config heuristics,
  timestamps, sample helpers) and has since grown to include native audio backends.
- `cpal-reference/` is kept as a read-only upstream checkout used as the behavior/source reference.
