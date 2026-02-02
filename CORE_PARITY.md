# Core parity checklist (cpal subset)

Pinned upstream: `cpal-reference/` at commit `6627959add25299a4e6077f45eb69721cfaaa14f` (see `UPSTREAM.md`).

This file tracks the **deterministic, portable “pure core”** slice we are porting from upstream
`cpal-reference/src/lib.rs`. Platform backends and raw audio buffer handling are intentionally
out of scope for this checklist.

## Ported (MoonBit)

From `cpal-reference/src/lib.rs`:

- `BufferSize` (Default, Fixed)
  - MoonBit: `cpal_types.mbt`
- `StreamConfig` (channels, sample_rate, buffer_size)
  - MoonBit: `cpal_types.mbt`
- `SupportedBufferSize` (Range, Unknown)
  - MoonBit: `cpal_types.mbt`
- `SupportedStreamConfig`
  - constructor + accessors + `config()` (drops supported buffer range, uses `BufferSize::Default`)
  - MoonBit: `cpal_types.mbt`
- `SupportedStreamConfigRange`
  - constructor + accessors
  - `with_sample_rate(sample_rate)` (panics if out of range)
  - `try_with_sample_rate(sample_rate)` (returns `Option`)
  - `with_max_sample_rate()`
  - default selection heuristic `cmp_default_heuristics`
  - MoonBit: `cpal_types.mbt`, `cpal_heuristics.mbt`
- `COMMON_SAMPLE_RATES`
  - MoonBit: `common_sample_rates()` in `cpal_types.mbt`
- `StreamInstant` + minimal non-negative `Duration`
  - `duration_since`, `add`, `sub`
  - MoonBit: `cpal_time.mbt`
- Timestamp callback info
  - `InputStreamTimestamp`, `OutputStreamTimestamp`
  - `InputCallbackInfo`, `OutputCallbackInfo`
  - MoonBit: `cpal_callback_info.mbt`

From `cpal-reference/src/samples_formats.rs`:

- `SampleFormat` helpers
  - `sample_size`, `bits_per_sample`, `is_int`, `is_uint`, `is_float`, `is_dsd`, `to_debug_string`
  - MoonBit: `cpal_sample_format.mbt`

## Missing (planned)

From `cpal-reference/src/lib.rs`:

- (none for the current deterministic core slice)

## Out of scope (for the initial slice)

From `cpal-reference/src/lib.rs`:

- `Data` (raw dynamically-typed audio buffer) and host-facing stream build APIs.
- Sample traits (`Sample`, `FromSample`, `SizedSample`) and `I24`/`U24` sample newtypes.

## Known compatibility deltas

- Integer widths differ: upstream uses `u16`/`u32` for channel/rate/frame counts; MoonBit uses `Int`.
  For this initial slice we only target behavior-level parity for deterministic logic.
