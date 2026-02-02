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
/// May occur when attempting to request the default input or output stream config from a device.
pub suberror DefaultStreamConfigError {
  DeviceNotAvailable
  DeviceBusy
  StreamTypeNotSupported
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
/// Error that can happen when enumerating the list of supported configs.
pub suberror SupportedStreamConfigsError {
  DeviceNotAvailable
  DeviceBusy
  InvalidArgument
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

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
pub suberror PlayStreamError {
  DeviceNotAvailable
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub suberror PauseStreamError {
  DeviceNotAvailable
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

///|
pub suberror StreamError {
  DeviceNotAvailable
  StreamInvalidated
  BufferUnderrun
  BackendSpecific(BackendSpecificError)
} derive(Show, Eq)

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
