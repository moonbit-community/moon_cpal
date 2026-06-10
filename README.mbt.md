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

CPAL-like audio I/O for MoonBit (native-only).

## Install

Add dependency in `moon.mod`:

```json
{
  "deps": {
    "Milky2018/moon_cpal": "0.11.7"
  }
}
```

`moon_cpal` supports `native` target only.

## Quick Start (Typed Output Stream)

```moonbit nocheck
let host = @moon_cpal.default_host()
let device = match host.default_output_device() {
  Some(d) => d
  None => fail!("no output device")
}
let cfg = try! device.default_output_config()
let stream_cfg = cfg.config()
let stream = try! device.build_output_stream_f32(
  stream_cfg,
  fn(samples, _info) {
    for i = 0; i < samples.length(); i = i + 1 {
      samples[i] = 0.0
    }
  },
  fn(err) { println("stream error: \{err}") },
  None,
)
try! stream.play()
```

## Quick Start (Raw Output Stream)

Use `build_output_stream_raw` when you need format-specific writes:

```moonbit nocheck
///|
let stream = try! device.build_output_stream_raw(
  stream_cfg,
  cfg.sample_format(),
  fn(data, _info) {
    match data.sample_format() {
      @moon_cpal.SampleFormat::F32 =>
        ignore(data.write_f32(Array::make(data.len(), 0.0)))
      @moon_cpal.SampleFormat::I16 =>
        ignore(data.write_i16(Array::make(data.len(), 0)))
      @moon_cpal.SampleFormat::I24 =>
        ignore(data.write_i24(Array::make(data.len(), @moon_cpal.I24::new(0))))
      _ => data.clear()
    }
  },
  fn(_err) {  },
  None,
)
```

`Data` exposes full numeric write APIs:
`write_i8`, `write_u8`, `write_u16`, `write_i16`, `write_u24`, `write_i24`,
`write_u32`, `write_i32`, `write_f32`, `write_u64`, `write_i64`, `write_f64`.

## Notes

- Use `stream.pause()` / `stream.close()` to control lifecycle.
- Use `default_input_device()` + `build_input_stream_*` for capture.
