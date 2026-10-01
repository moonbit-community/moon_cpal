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
test "error display strings (cpal-reference parity)" {
  inspect(
    @core.BackendSpecificError::BackendSpecificError("oops").to_string(),
    content="A backend-specific error has occurred: oops",
  )
  inspect(
    @core.devices_error_backend_specific("oops").to_string(),
    content="A backend-specific error has occurred: oops",
  )
  inspect(
    @core.device_name_error_backend_specific("oops").to_string(),
    content="A backend-specific error has occurred: oops",
  )
  inspect(
    @core.default_stream_config_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    @core.default_stream_config_error_device_busy().to_string(),
    content="The requested device is temporarily busy. Another application or stream may be using it.",
  )
  inspect(
    @core.default_stream_config_error_stream_type_not_supported().to_string(),
    content="The requested stream type is not supported by the device.",
  )
  inspect(
    @core.supported_stream_configs_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    @core.supported_stream_configs_error_device_busy().to_string(),
    content="The requested device is temporarily busy. Another application or stream may be using it.",
  )
  inspect(
    @core.supported_stream_configs_error_invalid_argument().to_string(),
    content="Invalid argument passed to the backend. For example, this happens when trying to read capture capabilities when the device does not support it.",
  )
  inspect(
    @core.build_stream_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    @core.build_stream_error_device_busy().to_string(),
    content="The requested device is temporarily busy. Another application or stream may be using it.",
  )
  inspect(
    @core.build_stream_error_stream_config_not_supported().to_string(),
    content="The requested stream configuration is not supported by the device.",
  )
  inspect(
    @core.build_stream_error_invalid_argument().to_string(),
    content="The requested device does not support this capability (invalid argument)",
  )
  inspect(
    @core.build_stream_error_stream_id_overflow().to_string(),
    content="Adding a new stream ID would cause an overflow",
  )
  inspect(
    @core.play_stream_error_device_not_available().to_string(),
    content="the device associated with the stream is no longer available",
  )
  inspect(
    @core.pause_stream_error_device_not_available().to_string(),
    content="the device associated with the stream is no longer available",
  )
  inspect(
    @core.stream_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    @core.stream_error_stream_invalidated().to_string(),
    content="The stream configuration is no longer valid and must be rebuilt.",
  )
  inspect(
    @core.stream_error_buffer_underrun().to_string(),
    content="Buffer underrun/overrun occurred.",
  )
  inspect(
    @core.host_unavailable().to_string(),
    content="the requested host is unavailable",
  )
  let s1 = try @core.DeviceId::from_string("unknown:abc") catch {
    e => e.to_string()
  } noraise {
    _ => "OK"
  }
  inspect(s1, content="Device IDs are unsupported for this OS")
  let s2 = try @core.DeviceId::from_string("coreaudio") catch {
    e => e.to_string()
  } noraise {
    _ => "OK"
  }
  inspect(
    s2,
    content="A backend-specific error has occurred: Failed to parse device ID from: coreaudio\nCheck if format matches \"host:device_id\"",
  )
}
