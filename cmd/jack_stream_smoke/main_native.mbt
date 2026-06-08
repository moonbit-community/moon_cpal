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

///|
extern "C" fn sleep_ms(ms : Int) -> Unit = "moon_cpal_sleep_ms"

///|
fn fill_silence_f32(data : @core.Data) -> Unit {
  let bytes = data.bytes()
  let mut off = 0
  while off + 4 <= bytes.length() {
    bytes.unsafe_write_uint32_le(off, 0)
    off += 4
  }
}

///|
fn main {
  if @core.native_os() != Linux {
    println("jack_stream_smoke: Linux-only (native)")
    return
  }
  let host = @jack.default_host()
  let devices = host.devices()
  println("devices: \{devices.length()}")
  for d in devices {
    println("  - \{d.name()}")
  }
  let out_dev = match host.default_output_device() {
    None => {
      println("no default device")
      panic()
    }
    Some(d) => d
  }
  let supported_cfg = try out_dev.default_output_config() catch {
    e => {
      println("default output config failed: \{e}")
      panic()
    }
  } noraise {
    supported => supported
  }
  let cfg = supported_cfg.config()

  // Validate BufferSize::Fixed semantics: for JACK, the server controls buffer size.
  // A mismatched fixed buffer request must be rejected.
  match supported_cfg.buffer_size() {
    Unknown => ()
    Range(min=mn, max=mx) => {
      // JACK should report a fixed buffer size range.
      if mn != mx || mn <= 0 {
        println(
          "unexpected JACK buffer size range: \{supported_cfg.buffer_size()}",
        )
        panic()
      }
      let fixed_ok = @moon_cpal.StreamConfig::StreamConfig(
        cfg.channels,
        cfg.sample_rate,
        @moon_cpal.BufferSize::fixed(mn),
      )
      let fixed_bad = @moon_cpal.StreamConfig::StreamConfig(
        cfg.channels,
        cfg.sample_rate,
        @moon_cpal.BufferSize::fixed(mn + 1),
      )

      // Should succeed.
      let s_ok = try
        out_dev.build_output_stream(
          fixed_ok,
          fn(data, _info) {
            if data.len() != mn * cfg.channels {
              println(
                "fixed output callback len mismatch: got=\{data.len()} expected=\{mn * cfg.channels}",
              )
              panic()
            }
            fill_silence_f32(data)
          },
          fn(_err) {  },
          None,
        )
      catch {
        e => {
          println("fixed buffer (expected ok) build failed: \{e}")
          panic()
        }
      } noraise {
        s => s
      }
      s_ok.close()

      // Should fail.
      let _ = try
        out_dev.build_output_stream(
          fixed_bad,
          fn(data, _info) { fill_silence_f32(data) },
          fn(_err) {  },
          None,
        )
      catch {
        // expected
        _ => ()
      } noraise {
        s => {
          s.close()
          println("fixed buffer (expected fail) unexpectedly succeeded")
          panic()
        }
      }
    }
  }

  // Output stream should always produce callbacks once the server is running.
  let calls : Array[Int] = [0]
  let last_cb : Array[@moon_cpal.StreamInstant?] = [None]
  let out = try
    out_dev.build_output_stream(
      cfg,
      fn(data, info) {
        calls[0] = calls[0] + 1
        let now = info.timestamp().callback()
        match last_cb[0] {
          None => last_cb[0] = Some(now)
          Some(prev) => {
            if now.duration_since(prev) is None {
              println("non-monotonic output callback timestamp")
              panic()
            }
            last_cb[0] = Some(now)
          }
        }
        fill_silence_f32(data)
      },
      fn(err) { println("stream error: \{err}") },
      None,
    )
  catch {
    e => {
      println("output stream build failed: \{e}")
      panic()
    }
  } noraise {
    s => s
  }
  try out.play() catch {
    e => {
      println("output stream play failed: \{e}")
      out.close()
      panic()
    }
  } noraise {
    _ => ()
  }
  sleep_ms(1000)
  try out.pause() catch {
    e => println("output stream pause failed: \{e}")
  } noraise {
    _ => ()
  }
  let paused = calls[0]
  sleep_ms(200)
  if calls[0] > paused + 1 {
    println(
      "output callbacks continued after pause (before=\{paused} after=\{calls[0]})",
    )
    out.close()
    panic()
  }
  out.close()
  println("output callbacks: \{calls[0]}")
  if calls[0] <= 0 {
    println("no callbacks (is jackd running?)")
    panic()
  }

  // Input: best-effort. With the dummy driver this should still tick.
  let in_dev = match host.default_input_device() {
    None => {
      println("no default input device")
      return
    }
    Some(d) => d
  }
  let in_calls : Array[Int] = [0]
  let in_stream = try
    in_dev.build_input_stream(
      cfg,
      fn(_data, _info) { in_calls[0] = in_calls[0] + 1 },
      fn(err) { println("stream error: \{err}") },
      None,
    )
  catch {
    e => {
      println("input stream build failed: \{e}")
      return
    }
  } noraise {
    s => s
  }
  try in_stream.play() catch {
    e => {
      println("input stream play failed: \{e}")
      in_stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  sleep_ms(1000)
  try in_stream.pause() catch {
    e => println("input stream pause failed: \{e}")
  } noraise {
    _ => ()
  }
  let paused = in_calls[0]
  sleep_ms(200)
  if in_calls[0] > paused + 1 {
    println(
      "input callbacks continued after pause (before=\{paused} after=\{in_calls[0]})",
    )
    in_stream.close()
    panic()
  }
  in_stream.close()
  println("input callbacks: \{in_calls[0]}")
}
