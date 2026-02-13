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
test "wasapi HRESULT mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  // AUDCLNT_E_DEVICE_INVALIDATED (0x88890004)
  inspect(
    wasapi_stream_error_from_hresult(-2004287484, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  // AUDCLNT_E_DEVICE_IN_USE (0x8889000A)
  inspect(
    wasapi_stream_error_from_hresult(-2004287478, "IAudioClientStart"),
    content="DeviceNotAvailable",
  )
  // Other HRESULTs should be backend-specific.
  match wasapi_stream_error_from_hresult(-2004287474, "DeviceInit") {
    @core.StreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  match wasapi_stream_error_from_hresult(-2004287472, "DeviceInit") {
    @core.StreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  inspect(
    wasapi_build_error_from_hresult(-2004287484, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287478, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  match wasapi_build_error_from_hresult(-2004287474, "DeviceInit") {
    @core.BuildStreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  match wasapi_build_error_from_hresult(-2004287472, "DeviceInit") {
    @core.BuildStreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  inspect(
    wasapi_build_error_from_hresult(-2004287480, "IAudioClientInitialize"),
    content="StreamConfigNotSupported",
  )
  inspect(
    wasapi_build_error_from_hresult(-2147024809, "IAudioClientInitialize"),
    content="InvalidArgument",
  )
}

///|
test "wasapi host availability parity (unit)" {
  inspect(
    Host::is_available(default_host()) ==
    (@core.native_os() == @core.NativeOs::Windows),
    content="true",
  )
}

///|
test "wasapi play/pause HRESULT mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  inspect(
    wasapi_play_error_from_hresult(-2004287484, "IAudioClientStart"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_pause_error_from_hresult(-2004287478, "IAudioClientStop"),
    content="DeviceNotAvailable",
  )
  match wasapi_play_error_from_hresult(-1, "PlayOp") {
    @core.PlayStreamError::BackendSpecific(err) =>
      inspect(err.description() == "PlayOp (HRESULT -1)", content="true")
    _ => inspect(false, content="true")
  }
  match wasapi_pause_error_from_hresult(-2, "PauseOp") {
    @core.PauseStreamError::BackendSpecific(err) =>
      inspect(err.description() == "PauseOp (HRESULT -2)", content="true")
    _ => inspect(false, content="true")
  }
}

///|
test "wasapi stream callback op_tag mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let slot = FixedArray::make(1, @core.stream_error_backend_specific("init"))
  call_stream_error_callback(fn(e) { slot[0] = e }, 3, -1)
  match slot[0] {
    @core.StreamError::BackendSpecific(err) =>
      inspect(
        err.description() == "IAudioClientStart (HRESULT -1)",
        content="true",
      )
    _ => inspect(false, content="true")
  }
  call_stream_error_callback(fn(e) { slot[0] = e }, 4, -2)
  match slot[0] {
    @core.StreamError::BackendSpecific(err) =>
      inspect(
        err.description() == "IAudioClientStop (HRESULT -2)",
        content="true",
      )
    _ => inspect(false, content="true")
  }
  call_stream_error_callback(fn(e) { slot[0] = e }, 6, -3)
  match slot[0] {
    @core.StreamError::BackendSpecific(err) =>
      inspect(err.description() == "DeviceInit (HRESULT -3)", content="true")
    _ => inspect(false, content="true")
  }
}
