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
/// Shared WASAPI error mapping helpers (parity with upstream host/wasapi/mod.rs).
///
/// Upstream treats the following HRESULTs as "device not available":
/// - AUDCLNT_E_DEVICE_INVALIDATED (0x88890004)
/// - AUDCLNT_E_DEVICE_IN_USE      (0x8889000A)

///|
fn wasapi_is_device_not_available_hresult(status : Int) -> Bool {
  status == -2004287484 || status == -2004287478
}

///|
fn wasapi_stream_error_from_hresult(
  status : Int,
  op : String,
) -> @core.StreamError {
  if wasapi_is_device_not_available_hresult(status) {
    @core.stream_error_device_not_available()
  } else {
    @core.stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_build_error_from_hresult(
  status : Int,
  op : String,
) -> @core.BuildStreamError {
  // Best-effort mapping from HRESULT to CPAL-like BuildStreamError.
  //
  // - AUDCLNT_E_UNSUPPORTED_FORMAT = 0x88890008 (-2004287480)
  // - AUDCLNT_E_BUFFER_SIZE_ERROR  = 0x88890019 (-2004287463)
  // - E_INVALIDARG                 = 0x80070057 (-2147024809)
  if wasapi_is_device_not_available_hresult(status) {
    @core.build_stream_error_device_not_available()
  } else if status == -2004287480 || status == -2004287463 {
    @core.build_stream_error_stream_config_not_supported()
  } else if status == -2147024809 {
    @core.build_stream_error_invalid_argument()
  } else {
    @core.build_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_play_error_from_hresult(
  status : Int,
  op : String,
) -> @core.PlayStreamError {
  if wasapi_is_device_not_available_hresult(status) {
    @core.play_stream_error_device_not_available()
  } else {
    @core.play_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_pause_error_from_hresult(
  status : Int,
  op : String,
) -> @core.PauseStreamError {
  if wasapi_is_device_not_available_hresult(status) {
    @core.pause_stream_error_device_not_available()
  } else {
    @core.pause_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}
