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
} derive(Show, Eq)

///|
pub fn BackendSpecificError::new(description : String) -> BackendSpecificError {
  { description, }
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
} derive(Show, Eq)

///|
pub fn DefaultStreamConfigError::to_string(
  self : DefaultStreamConfigError,
) -> String {
  match self {
    DefaultStreamConfigError::BackendSpecific(err) => err.to_string()
    DefaultStreamConfigError::DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
    DefaultStreamConfigError::DeviceBusy =>
      "The requested device is temporarily busy. Another application or stream may be using it."
    DefaultStreamConfigError::StreamTypeNotSupported =>
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
} derive(Show, Eq)

///|
pub fn SupportedStreamConfigsError::to_string(
  self : SupportedStreamConfigsError,
) -> String {
  match self {
    SupportedStreamConfigsError::BackendSpecific(err) => err.to_string()
    SupportedStreamConfigsError::DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
    SupportedStreamConfigsError::DeviceBusy =>
      "The requested device is temporarily busy. Another application or stream may be using it."
    SupportedStreamConfigsError::InvalidArgument =>
      "Invalid argument passed to the backend. For example, this happens when trying to read capture capabilities when the device does not support it."
  }
}

///|
/// An error that might occur while attempting to enumerate devices.
pub suberror DevicesError {
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub fn DevicesError::to_string(self : DevicesError) -> String {
  match self {
    DevicesError::BackendSpecific(err) => err.to_string()
  }
}

///|
/// An error that may occur while attempting to retrieve a device name.
pub suberror DeviceNameError {
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub fn DeviceNameError::to_string(self : DeviceNameError) -> String {
  match self {
    DeviceNameError::BackendSpecific(err) => err.to_string()
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
} derive(Show, Eq)

///|
pub fn BuildStreamError::to_string(self : BuildStreamError) -> String {
  match self {
    BuildStreamError::BackendSpecific(err) => err.to_string()
    BuildStreamError::DeviceNotAvailable =>
      "The requested device is no longer available. For example, it has been unplugged."
    BuildStreamError::DeviceBusy =>
      "The requested device is temporarily busy. Another application or stream may be using it."
    BuildStreamError::StreamConfigNotSupported =>
      "The requested stream configuration is not supported by the device."
    BuildStreamError::InvalidArgument =>
      "The requested device does not support this capability (invalid argument)"
    BuildStreamError::StreamIdOverflow =>
      "Adding a new stream ID would cause an overflow"
  }
}

///|
pub suberror PlayStreamError {
  DeviceNotAvailable
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub fn PlayStreamError::to_string(self : PlayStreamError) -> String {
  match self {
    PlayStreamError::BackendSpecific(err) => err.to_string()
    PlayStreamError::DeviceNotAvailable =>
      "the device associated with the stream is no longer available"
  }
}

///|
pub suberror PauseStreamError {
  DeviceNotAvailable
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub fn PauseStreamError::to_string(self : PauseStreamError) -> String {
  match self {
    PauseStreamError::BackendSpecific(err) => err.to_string()
    PauseStreamError::DeviceNotAvailable =>
      "the device associated with the stream is no longer available"
  }
}

///|
pub suberror StreamError {
  DeviceNotAvailable
  StreamInvalidated
  BufferUnderrun
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub fn StreamError::to_string(self : StreamError) -> String {
  match self {
    StreamError::BackendSpecific(err) => err.to_string()
    StreamError::StreamInvalidated =>
      "The stream configuration is no longer valid and must be rebuilt."
    StreamError::BufferUnderrun => "Buffer underrun/overrun occurred."
    StreamError::DeviceNotAvailable =>
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
  BackendSpecific(BackendSpecificError::new(description))
}

///|
pub fn supported_stream_configs_error_device_not_available() -> SupportedStreamConfigsError {
  SupportedStreamConfigsError::DeviceNotAvailable
}

///|
pub fn supported_stream_configs_error_device_busy() -> SupportedStreamConfigsError {
  SupportedStreamConfigsError::DeviceBusy
}

///|
pub fn supported_stream_configs_error_invalid_argument() -> SupportedStreamConfigsError {
  SupportedStreamConfigsError::InvalidArgument
}

///|
pub fn supported_stream_configs_error_backend_specific(
  description : String,
) -> SupportedStreamConfigsError {
  SupportedStreamConfigsError::BackendSpecific(
    BackendSpecificError::new(description),
  )
}

///|
pub fn devices_error_backend_specific(description : String) -> DevicesError {
  DevicesError::BackendSpecific(BackendSpecificError::new(description))
}

///|
pub fn device_name_error_backend_specific(
  description : String,
) -> DeviceNameError {
  DeviceNameError::BackendSpecific(BackendSpecificError::new(description))
}

///|
pub fn build_stream_error_device_not_available() -> BuildStreamError {
  BuildStreamError::DeviceNotAvailable
}

///|
pub fn build_stream_error_device_busy() -> BuildStreamError {
  BuildStreamError::DeviceBusy
}

///|
pub fn build_stream_error_stream_config_not_supported() -> BuildStreamError {
  BuildStreamError::StreamConfigNotSupported
}

///|
pub fn build_stream_error_invalid_argument() -> BuildStreamError {
  BuildStreamError::InvalidArgument
}

///|
pub fn build_stream_error_stream_id_overflow() -> BuildStreamError {
  BuildStreamError::StreamIdOverflow
}

///|
pub fn build_stream_error_backend_specific(
  description : String,
) -> BuildStreamError {
  BuildStreamError::BackendSpecific(BackendSpecificError::new(description))
}

///|
pub fn play_stream_error_device_not_available() -> PlayStreamError {
  PlayStreamError::DeviceNotAvailable
}

///|
pub fn play_stream_error_backend_specific(
  description : String,
) -> PlayStreamError {
  PlayStreamError::BackendSpecific(BackendSpecificError::new(description))
}

///|
pub fn pause_stream_error_device_not_available() -> PauseStreamError {
  PauseStreamError::DeviceNotAvailable
}

///|
pub fn pause_stream_error_backend_specific(
  description : String,
) -> PauseStreamError {
  PauseStreamError::BackendSpecific(BackendSpecificError::new(description))
}

///|
pub fn stream_error_device_not_available() -> StreamError {
  StreamError::DeviceNotAvailable
}

///|
pub fn stream_error_stream_invalidated() -> StreamError {
  StreamError::StreamInvalidated
}

///|
pub fn stream_error_buffer_underrun() -> StreamError {
  StreamError::BufferUnderrun
}

///|
pub fn stream_error_backend_specific(description : String) -> StreamError {
  StreamError::BackendSpecific(BackendSpecificError::new(description))
}
