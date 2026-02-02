///|
pub suberror CoreAudioError {
  CoreAudioError(String, Int)
  DeviceNotAvailable(String, Int)
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
) -> A raise @moon_cpal.DefaultStreamConfigError {
  match osstatus_kind(status) {
    1 => raise @moon_cpal.default_stream_config_error_device_not_available()
    2 =>
      raise @moon_cpal.default_stream_config_error_stream_type_not_supported()
    _ =>
      raise @moon_cpal.default_stream_config_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}
