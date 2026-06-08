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
/// Cross-platform error types (subset).
///
/// Ported from upstream `cpal/src/error.rs`. Start small and extend as more API is implemented.

///|
pub struct BackendSpecificError {
  description : String
} derive(Debug, Eq)

///|
pub fn BackendSpecificError::BackendSpecificError(
  description : String,
) -> BackendSpecificError {
  { description, }
}

///|
pub fn BackendSpecificError::new(description : String) -> BackendSpecificError {
  BackendSpecificError(description)
}

///|
pub fn BackendSpecificError::description(self : BackendSpecificError) -> String {
  self.description
}

///|
pub fn BackendSpecificError::to_string(self : BackendSpecificError) -> String {
  "A backend-specific error has occurred: \{self.description}"
}

///|
/// May occur when attempting to request the default input or output stream config from a device.
pub suberror DefaultStreamConfigError {
  DeviceNotAvailable
  DeviceBusy
  StreamTypeNotSupported
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn DefaultStreamConfigError::to_string(
  self : DefaultStreamConfigError,
) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
    DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
    DeviceBusy =>
      "The requested device is temporarily busy. Another application or stream may be using it."
    StreamTypeNotSupported =>
      "The requested stream type is not supported by the device."
  }
}

///|
/// Error that can happen when enumerating the list of supported configs.
pub suberror SupportedStreamConfigsError {
  DeviceNotAvailable
  DeviceBusy
  InvalidArgument
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn SupportedStreamConfigsError::to_string(
  self : SupportedStreamConfigsError,
) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
    DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
    DeviceBusy =>
      "The requested device is temporarily busy. Another application or stream may be using it."
    InvalidArgument =>
      "Invalid argument passed to the backend. For example, this happens when trying to read capture capabilities when the device does not support it."
  }
}

///|
/// An error that might occur while attempting to enumerate devices.
pub suberror DevicesError {
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn DevicesError::to_string(self : DevicesError) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
  }
}

///|
/// An error that may occur while attempting to retrieve a device name.
pub suberror DeviceNameError {
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn DeviceNameError::to_string(self : DeviceNameError) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
  }
}

///|
/// Error that can happen when creating a stream.
pub suberror BuildStreamError {
  DeviceNotAvailable
  DeviceBusy
  StreamConfigNotSupported
  InvalidArgument
  StreamIdOverflow
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn BuildStreamError::to_string(self : BuildStreamError) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
    DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
    DeviceBusy =>
      "The requested device is temporarily busy. Another application or stream may be using it."
    StreamConfigNotSupported =>
      "The requested stream configuration is not supported by the device."
    InvalidArgument =>
      "The requested device does not support this capability (invalid argument)"
    StreamIdOverflow => "Adding a new stream ID would cause an overflow"
  }
}

///|
pub suberror PlayStreamError {
  DeviceNotAvailable
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn PlayStreamError::to_string(self : PlayStreamError) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
    DeviceNotAvailable =>
      "the device associated with the stream is no longer available"
  }
}

///|
pub suberror PauseStreamError {
  DeviceNotAvailable
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn PauseStreamError::to_string(self : PauseStreamError) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
    DeviceNotAvailable =>
      "the device associated with the stream is no longer available"
  }
}

///|
pub suberror StreamError {
  DeviceNotAvailable
  StreamInvalidated
  BufferUnderrun
  BackendSpecific(BackendSpecificError)
} derive(Debug, Eq)

///|
pub fn StreamError::to_string(self : StreamError) -> String {
  match self {
    BackendSpecific(err) => err.to_string()
    StreamInvalidated =>
      "The stream configuration is no longer valid and must be rebuilt."
    BufferUnderrun => "Buffer underrun/overrun occurred."
    DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
  }
}

///|
pub fn default_stream_config_error_device_not_available() -> DefaultStreamConfigError {
  DeviceNotAvailable
}

///|
pub fn default_stream_config_error_device_busy() -> DefaultStreamConfigError {
  DeviceBusy
}

///|
pub fn default_stream_config_error_stream_type_not_supported() -> DefaultStreamConfigError {
  StreamTypeNotSupported
}

///|
pub fn default_stream_config_error_backend_specific(
  description : String,
) -> DefaultStreamConfigError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn supported_stream_configs_error_device_not_available() -> SupportedStreamConfigsError {
  DeviceNotAvailable
}

///|
pub fn supported_stream_configs_error_device_busy() -> SupportedStreamConfigsError {
  DeviceBusy
}

///|
pub fn supported_stream_configs_error_invalid_argument() -> SupportedStreamConfigsError {
  InvalidArgument
}

///|
pub fn supported_stream_configs_error_backend_specific(
  description : String,
) -> SupportedStreamConfigsError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn devices_error_backend_specific(description : String) -> DevicesError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn device_name_error_backend_specific(
  description : String,
) -> DeviceNameError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn build_stream_error_device_not_available() -> BuildStreamError {
  DeviceNotAvailable
}

///|
pub fn build_stream_error_device_busy() -> BuildStreamError {
  DeviceBusy
}

///|
pub fn build_stream_error_stream_config_not_supported() -> BuildStreamError {
  StreamConfigNotSupported
}

///|
pub fn build_stream_error_invalid_argument() -> BuildStreamError {
  InvalidArgument
}

///|
pub fn build_stream_error_stream_id_overflow() -> BuildStreamError {
  StreamIdOverflow
}

///|
pub fn build_stream_error_backend_specific(
  description : String,
) -> BuildStreamError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn play_stream_error_device_not_available() -> PlayStreamError {
  DeviceNotAvailable
}

///|
pub fn play_stream_error_backend_specific(
  description : String,
) -> PlayStreamError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn pause_stream_error_device_not_available() -> PauseStreamError {
  DeviceNotAvailable
}

///|
pub fn pause_stream_error_backend_specific(
  description : String,
) -> PauseStreamError {
  BackendSpecific(BackendSpecificError(description))
}

///|
pub fn stream_error_device_not_available() -> StreamError {
  DeviceNotAvailable
}

///|
pub fn stream_error_stream_invalidated() -> StreamError {
  StreamInvalidated
}

///|
pub fn stream_error_buffer_underrun() -> StreamError {
  BufferUnderrun
}

///|
pub fn stream_error_backend_specific(description : String) -> StreamError {
  BackendSpecific(BackendSpecificError(description))
}
