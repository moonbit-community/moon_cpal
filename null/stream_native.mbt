///|
/// Null streams (native target).
///
/// This implementation is used for portable unit tests and for exercising the callback-thread
/// model without relying on system audio devices.

///|
#borrow(out_handles)
#owned(data_callback, error_callback)
extern "C" fn null_stream_build_output(
  sample_rate : Double,
  channels : UInt,
  sample_format_tag : UInt,
  buffer_frames : UInt,
  call_data_callback : FuncRef[
    (
      (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
      UInt,
      FixedArray[Byte],
      Int64,
      Int,
      Int64,
      Int,
    ) -> Unit,
  ],
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  call_error_callback : FuncRef[
    ((@moon_cpal.StreamError) -> Unit, Int, Int) -> Unit,
  ],
  error_callback : (@moon_cpal.StreamError) -> Unit,
  out_handles : FixedArray[UInt64],
  out_len : Int,
) -> Int = "moon_cpal_null_stream_build_output"

///|
#borrow(out_handles)
#owned(data_callback, error_callback)
extern "C" fn null_stream_build_input(
  sample_rate : Double,
  channels : UInt,
  sample_format_tag : UInt,
  buffer_frames : UInt,
  call_data_callback : FuncRef[
    (
      (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
      UInt,
      FixedArray[Byte],
      Int64,
      Int,
      Int64,
      Int,
    ) -> Unit,
  ],
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  call_error_callback : FuncRef[
    ((@moon_cpal.StreamError) -> Unit, Int, Int) -> Unit,
  ],
  error_callback : (@moon_cpal.StreamError) -> Unit,
  out_handles : FixedArray[UInt64],
  out_len : Int,
) -> Int = "moon_cpal_null_stream_build_input"

///|
extern "C" fn null_stream_owner_new(handle : UInt64) -> StreamOwner = "moon_cpal_null_stream_owner_new"

///|
#borrow(owner)
extern "C" fn null_stream_owner_play(owner : StreamOwner) -> Int = "moon_cpal_null_stream_owner_play"

///|
#borrow(owner)
extern "C" fn null_stream_owner_pause(owner : StreamOwner) -> Int = "moon_cpal_null_stream_owner_pause"

///|
#borrow(owner)
extern "C" fn null_stream_owner_close(owner : StreamOwner) -> Int = "moon_cpal_null_stream_owner_close"

///|
fn format_tag_from_sample_format(fmt : @moon_cpal.SampleFormat) -> UInt? {
  match fmt {
    @moon_cpal.SampleFormat::F32 => Some((1 : UInt))
    @moon_cpal.SampleFormat::I16 => Some((2 : UInt))
    @moon_cpal.SampleFormat::U16 => Some((3 : UInt))
    @moon_cpal.SampleFormat::U8 => Some((4 : UInt))
    @moon_cpal.SampleFormat::I8 => Some((5 : UInt))
    @moon_cpal.SampleFormat::I24 => Some((6 : UInt))
    @moon_cpal.SampleFormat::U24 => Some((7 : UInt))
    @moon_cpal.SampleFormat::I32 => Some((8 : UInt))
    @moon_cpal.SampleFormat::U32 => Some((9 : UInt))
    @moon_cpal.SampleFormat::I64 => Some((10 : UInt))
    @moon_cpal.SampleFormat::U64 => Some((11 : UInt))
    @moon_cpal.SampleFormat::F64 => Some((12 : UInt))
    _ => None
  }
}

///|
fn[A] raise_build_status(
  op : String,
  status : Int,
) -> A raise @moon_cpal.BuildStreamError {
  if status == -22 {
    raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  raise @moon_cpal.build_stream_error_backend_specific(
    "\{op} (status \{status})",
  )
}

///|
fn[A] raise_play_status(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PlayStreamError {
  if status != 0 {
    raise @moon_cpal.play_stream_error_device_not_available()
  }
  raise @moon_cpal.play_stream_error_backend_specific(
    "\{op} (status \{status})",
  )
}

///|
fn[A] raise_pause_status(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PauseStreamError {
  if status != 0 {
    raise @moon_cpal.pause_stream_error_device_not_available()
  }
  raise @moon_cpal.pause_stream_error_backend_specific(
    "\{op} (status \{status})",
  )
}

///|
fn validate_config_or_raise(
  config : @moon_cpal.StreamConfig,
) -> Unit raise @moon_cpal.BuildStreamError {
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  match config.buffer_size {
    Default => ()
    Fixed(n) =>
      if n <= 0 {
        raise @moon_cpal.build_stream_error_invalid_argument()
      }
  }
}

///|
fn buffer_frames_from_config(config : @moon_cpal.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => (128 : UInt)
    Fixed(n) => n.reinterpret_as_uint()
  }
}

///|
pub fn Device::build_output_stream(
  _self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  Device::build_output_stream_raw(
    _self,
    config,
    @moon_cpal.SampleFormat::F32,
    data_callback,
    error_callback,
    _timeout,
  )
}

///|
pub fn Device::build_output_stream_raw(
  _self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  validate_config_or_raise(config)
  let frames = buffer_frames_from_config(config)
  let tag = match format_tag_from_sample_format(sample_format) {
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
    Some(t) => t
  }
  let out = FixedArray::make(1, (0 : UInt64))
  let status = null_stream_build_output(
    config.sample_rate.to_double(),
    config.channels.reinterpret_as_uint(),
    tag,
    frames,
    call_output_data_callback_fr,
    data_callback,
    call_stream_error_callback_fr,
    error_callback,
    out,
    out.length(),
  )
  if status != 0 {
    raise_build_status("null_stream_build_output", status)
  }
  let handle = out[0]
  if handle == (0 : UInt64) {
    raise_build_status("null_stream_build_output", -22)
  }
  { kind: StreamKind::Output, handle, owner: null_stream_owner_new(handle) }
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  Device::build_input_stream_raw(
    _self,
    config,
    @moon_cpal.SampleFormat::F32,
    data_callback,
    error_callback,
    _timeout,
  )
}

///|
pub fn Device::build_input_stream_raw(
  _self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  validate_config_or_raise(config)
  let frames = buffer_frames_from_config(config)
  let tag = match format_tag_from_sample_format(sample_format) {
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
    Some(t) => t
  }
  let out = FixedArray::make(1, (0 : UInt64))
  let status = null_stream_build_input(
    config.sample_rate.to_double(),
    config.channels.reinterpret_as_uint(),
    tag,
    frames,
    call_input_data_callback_fr,
    data_callback,
    call_stream_error_callback_fr,
    error_callback,
    out,
    out.length(),
  )
  if status != 0 {
    raise_build_status("null_stream_build_input", status)
  }
  let handle = out[0]
  if handle == (0 : UInt64) {
    raise_build_status("null_stream_build_input", -22)
  }
  { kind: StreamKind::Input, handle, owner: null_stream_owner_new(handle) }
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  let status = null_stream_owner_play(self.owner)
  if status != 0 {
    raise_play_status("null_stream_owner_play", status)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  let status = null_stream_owner_pause(self.owner)
  if status != 0 {
    raise_pause_status("null_stream_owner_pause", status)
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  ignore(null_stream_owner_close(self.owner))
}
