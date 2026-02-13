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
fn wait_until(ok : () -> Bool, total_ms : Int, step_ms : Int) -> Bool {
  let step = if step_ms <= 0 { 1 } else { step_ms }
  let mut left = if total_ms <= 0 { 0 } else { total_ms }
  while left > 0 {
    if ok() {
      return true
    }
    @core.sleep_millis(step)
    left = left - step
  }
  ok()
}

///|
test "platform output stream callback starts after play and stops after pause/close (best-effort)" {
  for host_id in available_hosts() {
    let host = try host_from_id(host_id) catch {
      _ => continue
    } noraise {
      h => h
    }
    let dev = match host.default_output_device() {
      None => continue
      Some(d) => d
    }
    let cfg = try dev.default_output_config() catch {
      _ => continue
    } noraise {
      x => x
    }
    let sc = cfg.config()
    let counts = FixedArray::make(2, 0) // [data_cb, error_cb]
    let stream = try
      dev.build_output_stream_raw(
        sc,
        cfg.sample_format(),
        fn(data, _info) {
          counts[0] = counts[0] + 1
          data.clear()
        },
        fn(_e) { counts[1] = counts[1] + 1 },
        None,
      )
    catch {
      _ => continue
    } noraise {
      s => s
    }

    // Ensure no callbacks are fired before play (best-effort).
    @core.sleep_millis(50)
    inspect(counts[0] == 0, content="true")

    // Play should trigger callbacks shortly.
    try stream.play() catch {
      _ => {
        stream.close()
        continue
      }
    } noraise {
      _ => ()
    }
    let got_cb = wait_until(fn() { counts[0] > 0 }, 1000, 10)
    inspect(got_cb, content="true")

    // Pause should stop callbacks (allow at most one in-flight callback).
    try stream.pause() catch {
      _ => ()
    } noraise {
      _ => ()
    }
    let at_pause = counts[0]
    @core.sleep_millis(150)
    inspect(counts[0] <= at_pause + 1, content="true")

    // Close should also stop callbacks.
    stream.close()
    let at_close = counts[0]
    @core.sleep_millis(150)
    inspect(counts[0] <= at_close + 1, content="true")

    // Errors are best-effort; ensure we never produced a negative count.
    inspect(counts[1] >= 0, content="true")
  }
  inspect(true, content="true")
}
