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
test "jack build error mapping (unit)" {
  if @core.native_os() != Linux {
    inspect(true, content="true")
    return
  }
  inspect(
    jack_build_error_from_status(-19, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-2, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-1, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-13, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-16, "jack_client_open"),
    content="DeviceBusy",
  )
  inspect(
    jack_build_error_from_status(-11, "jack_client_open"),
    content="DeviceBusy",
  )
  inspect(
    jack_build_error_from_status(-22, "jack_client_open"),
    content="InvalidArgument",
  )
}

///|
test "jack stream error mapping (unit)" {
  if @core.native_os() != Linux {
    inspect(true, content="true")
    return
  }
  let slot = FixedArray::make(1, @core.stream_error_backend_specific("init"))
  // jack_client_open failures => device not available.
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, 1)
  inspect(slot[0], content="DeviceNotAvailable")

  // Activation/registration failures => invalidated.
  call_stream_error_callback(fn(e) { slot[0] = e }, 2, -1)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 3, -1)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 4, -1)
  inspect(slot[0], content="StreamInvalidated")

  // Errno-style (op_tag 0) mapping: ENODEV and EPIPE.
  call_stream_error_callback(fn(e) { slot[0] = e }, 0, -19)
  inspect(slot[0], content="DeviceNotAvailable")
  call_stream_error_callback(fn(e) { slot[0] = e }, 0, -32)
  inspect(slot[0], content="StreamInvalidated")

  // JACK notifications.
  call_stream_error_callback(fn(e) { slot[0] = e }, 5, 0)
  inspect(slot[0], content="BufferUnderrun")
  call_stream_error_callback(fn(e) { slot[0] = e }, 6, 48000)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 7, 0)
  match slot[0] {
    BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}
