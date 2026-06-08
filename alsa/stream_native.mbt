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
/// ALSA streams (Linux, native target).
///
/// Implementation strategy:
/// - One worker thread per stream does blocking ALSA read/write.
/// - The worker thread bridges into the user MoonBit callback via C trampolines.
/// - Buffers are reused; bytes are copied between ALSA buffers and the MoonBit byte array.

///|
#borrow(out_handles)
#owned(device_id_utf8, data_callback, error_callback)
extern "C" fn alsa_stream_build_output(
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
) -> Int = "moon_cpal_alsa_stream_build_output"

///|
#borrow(out_handles)
#owned(device_id_utf8, data_callback, error_callback)
extern "C" fn alsa_stream_build_input(
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
) -> Int = "moon_cpal_alsa_stream_build_input"

///|
extern "C" fn alsa_stream_owner_new(handle : UInt64) -> StreamOwner = "moon_cpal_alsa_stream_owner_new"

///|
#borrow(owner)
extern "C" fn alsa_stream_owner_play(owner : StreamOwner) -> Int = "moon_cpal_alsa_stream_owner_play"

///|
#borrow(owner)
extern "C" fn alsa_stream_owner_pause(owner : StreamOwner) -> Int = "moon_cpal_alsa_stream_owner_pause"

///|
#borrow(owner)
extern "C" fn alsa_stream_owner_close(owner : StreamOwner) -> Int = "moon_cpal_alsa_stream_owner_close"

///|
fn[A] raise_build_errno(
  op : String,
  status : Int,
) -> A raise @core.BuildStreamError {
  raise alsa_build_error_from_errno(status, op)
}

///|
fn[A] raise_play_errno(
  op : String,
  status : Int,
) -> A raise @core.PlayStreamError {
  raise alsa_play_error_from_errno(status, op)
}

///|
fn[A] raise_pause_errno(
  op : String,
  status : Int,
) -> A raise @core.PauseStreamError {
  raise alsa_pause_error_from_errno(status, op)
}

///|
fn alsa_build_error_from_errno(
  status : Int,
  op : String,
) -> @core.BuildStreamError {
  // Best-effort errno mapping (Linux).
  if status == -2 ||
    status == -1 ||
    status == -13 ||
    status == -19 ||
    status == -524 {
    // ENOENT / EPERM / EACCES / ENODEV / ENOTSUPP
    @core.build_stream_error_device_not_available()
  } else if status == -16 || status == -11 {
    // EBUSY / EAGAIN
    @core.build_stream_error_device_busy()
  } else if status == -22 {
    // EINVAL
    @core.build_stream_error_invalid_argument()
  } else {
    @core.build_stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
fn build_error_from_supported_configs_error(
  e : @core.SupportedStreamConfigsError,
) -> @core.BuildStreamError {
  match e {
    DeviceNotAvailable => @core.build_stream_error_device_not_available()
    DeviceBusy => @core.build_stream_error_device_busy()
    InvalidArgument => @core.build_stream_error_invalid_argument()
    BackendSpecific(err) =>
      @core.build_stream_error_backend_specific(err.description())
  }
}

///|
fn alsa_play_error_from_errno(
  status : Int,
  op : String,
) -> @core.PlayStreamError {
  if status == -2 || status == -1 || status == -13 || status == -19 {
    @core.play_stream_error_device_not_available()
  } else {
    @core.play_stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
fn alsa_pause_error_from_errno(
  status : Int,
  op : String,
) -> @core.PauseStreamError {
  if status == -2 || status == -1 || status == -13 || status == -19 {
    @core.pause_stream_error_device_not_available()
  } else {
    @core.pause_stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
fn format_tag_from_range(r : @core.SupportedStreamConfigRange) -> UInt? {
  match r.sample_format() {
    F32 => Some((1 : UInt))
    I16 => Some((2 : UInt))
    U16 => Some((3 : UInt))
    U8 => Some((4 : UInt))
    I32 => Some((5 : UInt))
    U32 => Some((6 : UInt))
    I24 => Some((7 : UInt))
    U24 => Some((8 : UInt))
    F64 => Some((9 : UInt))
    I8 => Some((10 : UInt))
    _ => None
  }
}

///|
fn format_tag_from_sample_format(fmt : @core.SampleFormat) -> UInt? {
  match fmt {
    F32 => Some((1 : UInt))
    I16 => Some((2 : UInt))
    U16 => Some((3 : UInt))
    U8 => Some((4 : UInt))
    I32 => Some((5 : UInt))
    U32 => Some((6 : UInt))
    I24 => Some((7 : UInt))
    U24 => Some((8 : UInt))
    F64 => Some((9 : UInt))
    I8 => Some((10 : UInt))
    _ => None
  }
}

///|
fn find_matching_range_for_format(
  ranges : Array[@core.SupportedStreamConfigRange],
  config : @core.StreamConfig,
  fmt : @core.SampleFormat,
) -> @core.SupportedStreamConfigRange? {
  let sr = config.sample_rate
  let ch = config.channels
  for r in ranges {
    if r.channels() == ch &&
      r.sample_format() == fmt &&
      r.min_sample_rate() <= sr &&
      sr <= r.max_sample_rate() {
      return Some(r)
    }
  }
  None
}

///|
fn choose_default_range(
  ranges : Array[@core.SupportedStreamConfigRange],
  config : @core.StreamConfig,
) -> @core.SupportedStreamConfigRange? {
  let sr = config.sample_rate
  let ch = config.channels
  let mut best : @core.SupportedStreamConfigRange? = None
  for r in ranges {
    if r.channels() == ch &&
      r.min_sample_rate() <= sr &&
      sr <= r.max_sample_rate() &&
      format_tag_from_range(r) != None {
      match best {
        None => best = Some(r)
        Some(b) => if r.cmp_default_heuristics(b) > 0 { best = Some(r) }
      }
    }
  }
  best
}

///|
fn buffer_frames_from_config(config : @core.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => 0
    Fixed(n) => if n > 0 { n.reinterpret_as_uint() } else { 0 }
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
  if @core.native_os() != Linux {
    raise_build_errno("alsa build_output_stream_raw", -1)
  }
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
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  let ranges = try self.supported_output_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  ignore(r)
  let dev = @core.string_to_ascii_bytes(self.id)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = alsa_stream_build_output(
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
    raise_build_errno("alsa_stream_build_output", st)
  }
  { kind: Output, handle: out[0], owner: alsa_stream_owner_new(out[0]) }
}

///|
pub fn Device::build_output_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  let ranges = try self.supported_output_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match choose_default_range(ranges, config) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  Device::build_output_stream_raw(
    self,
    config,
    r.sample_format(),
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
  if @core.native_os() != Linux {
    raise_build_errno("alsa build_input_stream_raw", -1)
  }
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
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  let ranges = try self.supported_input_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  ignore(r)
  let dev = @core.string_to_ascii_bytes(self.id)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = alsa_stream_build_input(
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
    raise_build_errno("alsa_stream_build_input", st)
  }
  { kind: Input, handle: out[0], owner: alsa_stream_owner_new(out[0]) }
}

///|
pub fn Device::build_input_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  let ranges = try self.supported_input_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match choose_default_range(ranges, config) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  Device::build_input_stream_raw(
    self,
    config,
    r.sample_format(),
    data_callback,
    error_callback,
    _timeout,
  )
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  let st = alsa_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_errno("alsa_stream_owner_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  let st = alsa_stream_owner_pause(self.owner)
  if st < 0 {
    raise_pause_errno("alsa_stream_owner_pause", st)
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  if self.handle == 0 {
    return
  }
  alsa_stream_owner_close(self.owner) |> ignore
}
