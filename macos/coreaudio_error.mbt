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
) -> A raise @core.DefaultStreamConfigError {
  match osstatus_kind(status) {
    1 => raise @core.default_stream_config_error_device_not_available()
    2 => raise @core.default_stream_config_error_stream_type_not_supported()
    _ =>
      raise @core.default_stream_config_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}
