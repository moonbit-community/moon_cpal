///|
/// Null backend stream stubs.
///
/// These allow the platform API to expose build/play/pause on all targets without doing any
/// real audio I/O.

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
  { _unit: () }
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  { _unit: () }
}

///|
pub fn Stream::play(_self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  ()
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  ()
}
