///|
/// Null device stream builders.
///
/// Upstream null backend uses `unimplemented!()` for stream building and supported config queries.
/// In MoonBit we represent this as backend-specific errors.

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific(
    "null build_output_stream: unimplemented",
  )
}

///|
pub fn Device::build_output_stream_raw(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _sample_format : @moon_cpal.SampleFormat,
  _data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific(
    "null build_output_stream_raw: unimplemented",
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
    "null build_input_stream: unimplemented",
  )
}

///|
pub fn Device::build_input_stream_raw(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _sample_format : @moon_cpal.SampleFormat,
  _data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific(
    "null build_input_stream_raw: unimplemented",
  )
}
