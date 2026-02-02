///|
pub suberror CoreAudioError {
  CoreAudioError(String, Int)
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
  raise CoreAudioError(op, status)
}

///|
fn[A] raise_default_osstatus(
  op : String,
  status : Int,
) -> A raise DefaultStreamConfigError {
  raise DefaultStreamConfigError::BackendSpecific(op, status)
}
