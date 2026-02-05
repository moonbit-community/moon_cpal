///|
/// Null device stream builders.
///
/// Upstream null backend uses `unimplemented!()` for stream building and supported config queries.
/// In MoonBit we represent this as backend-specific errors.

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @core.StreamConfig,
  _data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_output_stream: unimplemented",
  )
}

///|
pub fn Device::build_output_stream_raw(
  _self : Device,
  _config : @core.StreamConfig,
  _sample_format : @core.SampleFormat,
  _data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_output_stream_raw: unimplemented",
  )
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  _config : @core.StreamConfig,
  _data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_input_stream: unimplemented",
  )
}

///|
pub fn Device::build_input_stream_raw(
  _self : Device,
  _config : @core.StreamConfig,
  _sample_format : @core.SampleFormat,
  _data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_input_stream_raw: unimplemented",
  )
}
