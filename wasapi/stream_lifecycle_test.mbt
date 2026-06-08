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
fn wait_until(counter : Array[Int], min_count : Int, timeout_ms : Int) -> Bool {
  let mut waited = 0
  while waited < timeout_ms {
    if counter[0] >= min_count {
      return true
    }
    sleep_ms(10)
    waited = waited + 10
  }
  counter[0] >= min_count
}

///|
test "wasapi output stream: no callbacks before play; pause/close stops callbacks (best-effort)" {
  if @core.native_os() != Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  let dev = match host.default_output_device() {
    None => {
      inspect(true, content="true")
      return
    }
    Some(d) => d
  }
  let cfg = try dev.default_output_config() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    supported => supported.config()
  }
  let calls : Array[Int] = [0]
  let errs : Array[Int] = [0]
  let stream = try
    dev.build_output_stream(
      cfg,
      fn(data, _info) {
        calls[0] = calls[0] + 1
        data.clear()
      },
      fn(_err) { errs[0] = errs[0] + 1 },
      None,
    )
  catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    s => s
  }
  sleep_ms(50)
  inspect(calls[0] == 0, content="true")
  try stream.play() catch {
    _ => {
      inspect(true, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  inspect(wait_until(calls, 1, 2000), content="true")
  try stream.pause() catch {
    _ => {
      inspect(true, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  let paused = calls[0]
  sleep_ms(100)
  inspect(calls[0] <= paused + 1, content="true")
  stream.close()
  let closed = calls[0]
  sleep_ms(100)
  inspect(calls[0] <= closed + 1, content="true")
  inspect(errs[0] == 0, content="true")
}
