///|
/// WASAPI stream stubs (Windows).

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
    "wasapi build_output_stream: unimplemented",
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
    "wasapi build_input_stream: unimplemented",
  )
}

///|
pub fn Stream::play(_self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  raise @moon_cpal.play_stream_error_backend_specific(
    "wasapi play: unimplemented",
  )
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  raise @moon_cpal.pause_stream_error_backend_specific(
    "wasapi pause: unimplemented",
  )
}
