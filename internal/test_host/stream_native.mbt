// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Deterministic test streams (native target).
///
/// Used for portable unit tests and for exercising the callback-thread model without relying on
/// system audio devices.

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
      (@core.Data, @core.OutputCallbackInfo) -> Unit,
      UInt,
      FixedArray[Byte],
      Int64,
      Int,
      Int64,
      Int,
    ) -> Unit,
  ],
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  call_error_callback : FuncRef[((@core.StreamError) -> Unit, Int, Int) -> Unit],
  error_callback : (@core.StreamError) -> Unit,
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
      (@core.Data, @core.InputCallbackInfo) -> Unit,
      UInt,
      FixedArray[Byte],
      Int64,
      Int,
      Int64,
      Int,
    ) -> Unit,
  ],
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  call_error_callback : FuncRef[((@core.StreamError) -> Unit, Int, Int) -> Unit],
  error_callback : (@core.StreamError) -> Unit,
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
#borrow(owner)
extern "C" fn null_stream_owner_inject_error(
  owner : StreamOwner,
  after_callbacks : Int,
  op_tag : Int,
  status : Int,
) -> Int = "moon_cpal_null_stream_owner_inject_error"

///|
fn format_tag_from_sample_format(fmt : @core.SampleFormat) -> UInt? {
  match fmt {
    @core.SampleFormat::F32 => Some((1 : UInt))
    @core.SampleFormat::I16 => Some((2 : UInt))
    @core.SampleFormat::U16 => Some((3 : UInt))
    @core.SampleFormat::U8 => Some((4 : UInt))
    @core.SampleFormat::I8 => Some((5 : UInt))
    @core.SampleFormat::I24 => Some((6 : UInt))
    @core.SampleFormat::U24 => Some((7 : UInt))
    @core.SampleFormat::I32 => Some((8 : UInt))
    @core.SampleFormat::U32 => Some((9 : UInt))
    @core.SampleFormat::I64 => Some((10 : UInt))
    @core.SampleFormat::U64 => Some((11 : UInt))
    @core.SampleFormat::F64 => Some((12 : UInt))
    _ => None
  }
}

///|
fn[A] raise_build_status(
  op : String,
  status : Int,
) -> A raise @core.BuildStreamError {
  if status == -22 {
    raise @core.build_stream_error_stream_config_not_supported()
  }
  raise @core.build_stream_error_backend_specific("\{op} (status \{status})")
}

///|
fn[A] raise_play_status(
  op : String,
  status : Int,
) -> A raise @core.PlayStreamError {
  if status != 0 {
    raise @core.play_stream_error_device_not_available()
  }
  raise @core.play_stream_error_backend_specific("\{op} (status \{status})")
}

///|
fn[A] raise_pause_status(
  op : String,
  status : Int,
) -> A raise @core.PauseStreamError {
  if status != 0 {
    raise @core.pause_stream_error_device_not_available()
  }
  raise @core.pause_stream_error_backend_specific("\{op} (status \{status})")
}

///|
fn validate_config_or_raise(
  config : @core.StreamConfig,
) -> Unit raise @core.BuildStreamError {
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  match config.buffer_size {
    Default => ()
    Fixed(n) => {
      if n < 0 {
        raise @core.build_stream_error_invalid_argument()
      }
      if n == 0 {
        raise @core.build_stream_error_stream_config_not_supported()
      }
    }
  }
}

///|
fn buffer_frames_from_config(config : @core.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => (128 : UInt)
    Fixed(n) => n.reinterpret_as_uint()
  }
}

///|
pub fn Device::build_output_stream(
  _self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  validate_config_or_raise(config)
  let fmt = @core.SampleFormat::F32
  Device::build_output_stream_raw(
    _self,
    config,
    fmt,
    data_callback,
    error_callback,
    None,
  )
}

///|
pub fn Device::build_output_stream_raw(
  _self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  validate_config_or_raise(config)
  let tag = match format_tag_from_sample_format(sample_format) {
    None => raise @core.build_stream_error_stream_config_not_supported()
    Some(x) => x
  }
  let buf_frames = buffer_frames_from_config(config)
  let handles : FixedArray[UInt64] = FixedArray::make(1, 0)
  let st = null_stream_build_output(
    config.sample_rate.to_double(),
    config.channels.reinterpret_as_uint(),
    tag,
    buf_frames,
    call_output_data_callback_fr,
    data_callback,
    call_stream_error_callback_fr,
    error_callback,
    handles,
    1,
  )
  if st != 0 {
    raise_build_status("test_host build_output_stream", st)
  }
  let h = handles[0]
  if h == 0 {
    raise_build_status("test_host build_output_stream", -1)
  }
  { kind: StreamKind::Output, owner: null_stream_owner_new(h) }
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  validate_config_or_raise(config)
  let fmt = @core.SampleFormat::F32
  Device::build_input_stream_raw(
    _self,
    config,
    fmt,
    data_callback,
    error_callback,
    None,
  )
}

///|
pub fn Device::build_input_stream_raw(
  _self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  validate_config_or_raise(config)
  let tag = match format_tag_from_sample_format(sample_format) {
    None => raise @core.build_stream_error_stream_config_not_supported()
    Some(x) => x
  }
  let buf_frames = buffer_frames_from_config(config)
  let handles : FixedArray[UInt64] = FixedArray::make(1, 0)
  let st = null_stream_build_input(
    config.sample_rate.to_double(),
    config.channels.reinterpret_as_uint(),
    tag,
    buf_frames,
    call_input_data_callback_fr,
    data_callback,
    call_stream_error_callback_fr,
    error_callback,
    handles,
    1,
  )
  if st != 0 {
    raise_build_status("test_host build_input_stream", st)
  }
  let h = handles[0]
  if h == 0 {
    raise_build_status("test_host build_input_stream", -1)
  }
  { kind: StreamKind::Input, owner: null_stream_owner_new(h) }
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  let st = null_stream_owner_play(self.owner)
  if st != 0 {
    raise_play_status("test_host play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  let st = null_stream_owner_pause(self.owner)
  if st != 0 {
    raise_pause_status("test_host pause", st)
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  ignore(null_stream_owner_close(self.owner))
}

///|
/// Internal test hook: schedule an async stream error callback from the worker thread.
///
/// `after_callbacks` is the number of successful data callbacks after which the error will be
/// delivered (best-effort). Errors are delivered at most once per injection request.
pub fn Stream::inject_error(
  self : Stream,
  after_callbacks : Int,
  op_tag : Int,
  status : Int,
) -> Unit {
  ignore(
    null_stream_owner_inject_error(self.owner, after_callbacks, op_tag, status),
  )
}
