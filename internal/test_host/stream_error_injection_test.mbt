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
test "test_host stream: injected stream error is delivered once (best-effort)" {
  let host = default_host()
  let dev = match host.default_output_device() {
    None => {
      inspect(false, content="true")
      return
    }
    Some(d) => d
  }
  let cfg = @core.StreamConfig::new(2, 48000, @core.BufferSize::fixed(64))
  let calls : Array[Int] = [0]
  let errs : Array[Int] = [0]
  let calls_at_err : Array[Int] = [0]
  let last = FixedArray::make(1, @core.stream_error_backend_specific("init"))
  let stream = try
    dev.build_output_stream(
      cfg,
      fn(data, _info) {
        calls[0] = calls[0] + 1
        data.clear()
      },
      fn(e) {
        errs[0] = errs[0] + 1
        calls_at_err[0] = calls[0]
        last[0] = e
      },
      None,
    )
  catch {
    _ => {
      inspect(false, content="true")
      return
    }
  } noraise {
    s => s
  }

  // After 2 data callbacks, inject an EPIPE-like xrun error.
  stream.inject_error(2, 0, -32)
  try stream.play() catch {
    _ => {
      inspect(false, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  inspect(wait_until(calls, 2, 2000), content="true")
  inspect(wait_until(errs, 1, 2000), content="true")
  inspect(calls_at_err[0] >= 2, content="true")
  match last[0] {
    @core.StreamError::BufferUnderrun => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  // Should not spam errors.
  sleep_ms(100)
  inspect(errs[0] == 1, content="true")
  stream.close()
}

///|
test "test_host stream: injected device-not-available mapping" {
  let host = default_host()
  let dev = match host.default_input_device() {
    None => {
      inspect(false, content="true")
      return
    }
    Some(d) => d
  }
  let cfg = @core.StreamConfig::new(1, 48000, @core.BufferSize::fixed(64))
  let calls : Array[Int] = [0]
  let errs : Array[Int] = [0]
  let last = FixedArray::make(1, @core.stream_error_backend_specific("init"))
  let stream = try
    dev.build_input_stream(
      cfg,
      fn(_data, _info) { calls[0] = calls[0] + 1 },
      fn(e) {
        errs[0] = errs[0] + 1
        last[0] = e
      },
      None,
    )
  catch {
    _ => {
      inspect(false, content="true")
      return
    }
  } noraise {
    s => s
  }

  // Inject ENODEV after the first callback.
  stream.inject_error(1, 0, -19)
  try stream.play() catch {
    _ => {
      inspect(false, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  inspect(wait_until(calls, 1, 2000), content="true")
  inspect(wait_until(errs, 1, 2000), content="true")
  match last[0] {
    @core.StreamError::DeviceNotAvailable => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  stream.close()
}

///|
test "test_host stream: close prevents pending injected error (best-effort)" {
  let host = default_host()
  let dev = match host.default_output_device() {
    None => {
      inspect(false, content="true")
      return
    }
    Some(d) => d
  }
  let cfg = @core.StreamConfig::new(2, 48000, @core.BufferSize::fixed(64))
  let calls : Array[Int] = [0]
  let errs : Array[Int] = [0]
  let stream = try
    dev.build_output_stream(
      cfg,
      fn(data, _info) {
        calls[0] = calls[0] + 1
        data.clear()
      },
      fn(_e) { errs[0] = errs[0] + 1 },
      None,
    )
  catch {
    _ => {
      inspect(false, content="true")
      return
    }
  } noraise {
    s => s
  }

  // Schedule an error far in the future and close early.
  stream.inject_error(1000, 0, -32)
  try stream.play() catch {
    _ => {
      inspect(false, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  inspect(wait_until(calls, 2, 2000), content="true")
  stream.close()
  sleep_ms(100)
  inspect(errs[0] == 0, content="true")
}
