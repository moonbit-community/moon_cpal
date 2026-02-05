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
/// JACK stream bindings (Linux-only).

///|
#borrow(out_handles)
#owned(device_id_utf8, data_callback, error_callback)
extern "C" fn jack_stream_build_output(
  device_id_utf8 : Bytes,
  device_id_len : Int,
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
) -> Int = "moon_cpal_jack_stream_build_output"

///|
#borrow(out_handles)
#owned(device_id_utf8, data_callback, error_callback)
extern "C" fn jack_stream_build_input(
  device_id_utf8 : Bytes,
  device_id_len : Int,
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
) -> Int = "moon_cpal_jack_stream_build_input"

///|
extern "C" fn jack_stream_owner_new(handle : UInt64) -> StreamOwner = "moon_cpal_jack_stream_owner_new"

///|
#borrow(owner)
extern "C" fn jack_stream_owner_play(owner : StreamOwner) -> Int = "moon_cpal_jack_stream_owner_play"

///|
#borrow(owner)
extern "C" fn jack_stream_owner_pause(owner : StreamOwner) -> Int = "moon_cpal_jack_stream_owner_pause"

///|
#borrow(owner)
extern "C" fn jack_stream_owner_close(owner : StreamOwner) -> Int = "moon_cpal_jack_stream_owner_close"

///|
fn[A] raise_build_error(
  op : String,
  status : Int,
) -> A raise @core.BuildStreamError {
  raise jack_build_error_from_status(status, op)
}

///|
fn jack_build_error_from_status(
  status : Int,
  op : String,
) -> @core.BuildStreamError {
  // Best-effort errno-like mapping (Linux).
  if status == -2 || status == -1 || status == -13 || status == -19 {
    // ENOENT / EPERM / EACCES / ENODEV
    @core.build_stream_error_device_not_available()
  } else if status == -16 || status == -11 {
    // EBUSY / EAGAIN
    @core.build_stream_error_device_busy()
  } else if status == -22 {
    // EINVAL
    @core.build_stream_error_invalid_argument()
  } else {
    @core.build_stream_error_backend_specific("\{op}: \{status}")
  }
}

///|
fn[A] raise_play_error(
  op : String,
  status : Int,
) -> A raise @core.PlayStreamError {
  raise @core.play_stream_error_backend_specific("\{op}: \{status}")
}

///|
fn[A] raise_pause_error(
  op : String,
  status : Int,
) -> A raise @core.PauseStreamError {
  raise @core.pause_stream_error_backend_specific("\{op}: \{status}")
}

///|
fn buffer_frames_from_config(config : @core.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => 0
    Fixed(n) => if n > 0 { n.reinterpret_as_uint() } else { 0 }
  }
}

///|
fn validate_buffer_size_or_raise(
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
      match default_server_config() {
        None => ()
        Some((_sr, buf)) =>
          if n != buf {
            raise @core.build_stream_error_stream_config_not_supported()
          }
      }
    }
  }
}

///|
fn validate_sample_format_or_raise(
  sample_format : @core.SampleFormat,
) -> Unit raise @core.BuildStreamError {
  if sample_format != @core.SampleFormat::F32 {
    raise @core.build_stream_error_stream_config_not_supported()
  }
}

///|
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  if @core.native_os() != @core.NativeOs::Linux {
    raise_build_error("jack build_output_stream_raw", -1)
  }
  if self.direction != @core.DeviceDirection::output() {
    raise @core.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(config)
  validate_sample_format_or_raise(sample_format)
  let fmt_tag = (1 : UInt)
  let dev = @core.string_to_utf8_bytes(self.id)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = jack_stream_build_output(
    dev,
    dev.length(),
    config.sample_rate.to_double(),
    config.channels.reinterpret_as_uint(),
    fmt_tag,
    buffer_frames_from_config(config),
    call_output_data_callback_fr,
    data_callback,
    call_stream_error_callback_fr,
    error_callback,
    out,
    1,
  )
  if st < 0 {
    raise_build_error("jack_stream_build_output", st)
  }
  {
    kind: StreamKind::Output,
    handle: out[0],
    owner: jack_stream_owner_new(out[0]),
  }
}

///|
pub fn Device::build_output_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  Device::build_output_stream_raw(
    self,
    config,
    @core.SampleFormat::F32,
    data_callback,
    error_callback,
    _timeout,
  )
}

///|
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  if @core.native_os() != @core.NativeOs::Linux {
    raise_build_error("jack build_input_stream_raw", -1)
  }
  if self.direction != @core.DeviceDirection::input() {
    raise @core.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(config)
  validate_sample_format_or_raise(sample_format)
  let fmt_tag = (1 : UInt)
  let dev = @core.string_to_utf8_bytes(self.id)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = jack_stream_build_input(
    dev,
    dev.length(),
    config.sample_rate.to_double(),
    config.channels.reinterpret_as_uint(),
    fmt_tag,
    buffer_frames_from_config(config),
    call_input_data_callback_fr,
    data_callback,
    call_stream_error_callback_fr,
    error_callback,
    out,
    1,
  )
  if st < 0 {
    raise_build_error("jack_stream_build_input", st)
  }
  {
    kind: StreamKind::Input,
    handle: out[0],
    owner: jack_stream_owner_new(out[0]),
  }
}

///|
pub fn Device::build_input_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  Device::build_input_stream_raw(
    self,
    config,
    @core.SampleFormat::F32,
    data_callback,
    error_callback,
    _timeout,
  )
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  let st = jack_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_error("jack_stream_owner_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  let st = jack_stream_owner_pause(self.owner)
  if st < 0 {
    raise_pause_error("jack_stream_owner_pause", st)
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  if self.handle == 0 {
    return
  }
  jack_stream_owner_close(self.owner) |> ignore
}
