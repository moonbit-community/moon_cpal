///|
pub suberror CoreAudioError {
  CoreAudioError(String, Int)
  DeviceNotAvailable(String, Int)
}

///|
/// Error type for `default_*_config` queries.
///
/// This mirrors the intent of cpal's `DefaultStreamConfigError` (device missing vs unsupported
/// stream format) while keeping OSStatus available for debugging.
pub suberror DefaultStreamConfigError {
  DeviceNotAvailable
  StreamTypeNotSupported
  BackendSpecific(String, Int)
}

///|
fn[A] raise_osstatus(op : String, status : Int) -> A raise CoreAudioError {
  match osstatus_kind(status) {
    1 => raise CoreAudioError::DeviceNotAvailable(op, status)
    _ => raise CoreAudioError(op, status)
  }
}

///|
fn[A] raise_default_osstatus(
  op : String,
  status : Int,
) -> A raise DefaultStreamConfigError {
  match osstatus_kind(status) {
    1 => raise DefaultStreamConfigError::DeviceNotAvailable
    2 => raise DefaultStreamConfigError::StreamTypeNotSupported
    _ => raise DefaultStreamConfigError::BackendSpecific(op, status)
  }
}
