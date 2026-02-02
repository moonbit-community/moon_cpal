///|
/// CoreAudio stream stubs (macOS).
///
/// Real stream I/O will be implemented under `moon_cpal-uao.3.*`. For now we expose the
/// public surface so the platform wrapper can compile end-to-end.

///|
pub struct Stream {
  _unit : Unit
} derive(Show, Eq)

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific(
    "CoreAudio output stream is not implemented yet",
  )
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific(
    "CoreAudio input stream is not implemented yet",
  )
}

///|
pub fn Stream::play(_self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  raise @moon_cpal.play_stream_error_backend_specific(
    "CoreAudio stream play is not implemented yet",
  )
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  raise @moon_cpal.pause_stream_error_backend_specific(
    "CoreAudio stream pause is not implemented yet",
  )
}
