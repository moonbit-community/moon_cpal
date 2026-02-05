///|
/// CoreAudio stream stubs (macOS, non-native backends).

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @core.StreamConfig,
  _data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "CoreAudio output stream is not available on non-native targets",
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
    "CoreAudio input stream is not available on non-native targets",
  )
}

///|
pub fn Stream::play(_self : Stream) -> Unit raise @core.PlayStreamError {
  raise @core.play_stream_error_backend_specific(
    "CoreAudio stream play is not available on non-native targets",
  )
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @core.PauseStreamError {
  raise @core.pause_stream_error_backend_specific(
    "CoreAudio stream pause is not available on non-native targets",
  )
}

///|
pub fn Stream::close(_self : Stream) -> Unit {
  ()
}
