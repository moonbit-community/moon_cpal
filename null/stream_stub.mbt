///|
/// Null backend stream stubs (non-native targets).
///
/// On native targets we provide a real callback-thread model implementation in `stream_native.mbt`.
/// These stubs exist only to keep package structure consistent on non-native builds.

///|
pub struct Stream {
  state : FixedArray[Int]
} derive(Show, Eq)

///|
fn Stream::is_closed(self : Stream) -> Bool {
  self.state[0] != 0
}

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if _config.channels <= 0 || _config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  match _config.buffer_size {
    Default => ()
    Fixed(n) =>
      if n <= 0 {
        raise @moon_cpal.build_stream_error_invalid_argument()
      }
  }
  { state: FixedArray::make(1, 0) }
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
  Device::build_output_stream(
    _self, _config, _data_callback, _error_callback, _timeout,
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
  if _config.channels <= 0 || _config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  match _config.buffer_size {
    Default => ()
    Fixed(n) =>
      if n <= 0 {
        raise @moon_cpal.build_stream_error_invalid_argument()
      }
  }
  { state: FixedArray::make(1, 0) }
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
  Device::build_input_stream(
    _self, _config, _data_callback, _error_callback, _timeout,
  )
}

///|
pub fn Stream::play(_self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  if _self.is_closed() {
    raise @moon_cpal.play_stream_error_device_not_available()
  }
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  if _self.is_closed() {
    raise @moon_cpal.pause_stream_error_device_not_available()
  }
}

///|
pub fn Stream::close(_self : Stream) -> Unit {
  _self.state[0] = 1
}
