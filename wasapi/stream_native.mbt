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
/// WASAPI streams (Windows, native target).
///
/// Implementation strategy:
/// - One worker thread per stream drives the WASAPI event loop.
/// - The worker thread calls into MoonBit callbacks via C trampolines.

///|
#borrow(out_handles)
#owned(device_id_utf8, data_callback, error_callback)
extern "C" fn wasapi_stream_build_output(
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
) -> Int = "moon_cpal_wasapi_stream_build_output"

///|
#borrow(out_handles)
#owned(device_id_utf8, data_callback, error_callback)
extern "C" fn wasapi_stream_build_input(
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
) -> Int = "moon_cpal_wasapi_stream_build_input"

///|
extern "C" fn wasapi_stream_owner_new(handle : UInt64) -> StreamOwner = "moon_cpal_wasapi_stream_owner_new"

///|
#borrow(owner)
extern "C" fn wasapi_stream_owner_play(owner : StreamOwner) -> Int = "moon_cpal_wasapi_stream_owner_play"

///|
#borrow(owner)
extern "C" fn wasapi_stream_owner_pause(owner : StreamOwner) -> Int = "moon_cpal_wasapi_stream_owner_pause"

///|
#borrow(owner)
extern "C" fn wasapi_stream_owner_close(owner : StreamOwner) -> Int = "moon_cpal_wasapi_stream_owner_close"

///|
fn[A] raise_build_hresult(
  op : String,
  status : Int,
) -> A raise @core.BuildStreamError {
  raise wasapi_build_error_from_hresult(status, op)
}

///|
fn[A] raise_play_hresult(
  op : String,
  status : Int,
) -> A raise @core.PlayStreamError {
  raise wasapi_play_error_from_hresult(status, op)
}

///|
fn[A] raise_pause_hresult(
  op : String,
  status : Int,
) -> A raise @core.PauseStreamError {
  raise wasapi_pause_error_from_hresult(status, op)
}

///|
fn wasapi_build_error_from_hresult(
  status : Int,
  op : String,
) -> @core.BuildStreamError {
  // Best-effort mapping. The WASAPI C layer passes HRESULT as signed 32-bit int.
  //
  // Known values:
  // - AUDCLNT_E_DEVICE_INVALIDATED = 0x88890004 (-2004287484)
  // - AUDCLNT_E_DEVICE_IN_USE     = 0x8889000A (-2004287478)
  // - AUDCLNT_E_UNSUPPORTED_FORMAT= 0x88890008 (-2004287480)
  // - AUDCLNT_E_BUFFER_SIZE_ERROR = 0x88890019 (-2004287463)
  // - E_INVALIDARG                = 0x80070057 (-2147024809)
  if status == -2004287484 || status == -2004287478 {
    @core.build_stream_error_device_not_available()
  } else if status == -2004287480 || status == -2004287463 {
    @core.build_stream_error_stream_config_not_supported()
  } else if status == -2147024809 {
    @core.build_stream_error_invalid_argument()
  } else {
    @core.build_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_play_error_from_hresult(
  status : Int,
  op : String,
) -> @core.PlayStreamError {
  if status == -2004287484 || status == -2004287478 {
    @core.play_stream_error_device_not_available()
  } else {
    @core.play_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_pause_error_from_hresult(
  status : Int,
  op : String,
) -> @core.PauseStreamError {
  if status == -2004287484 || status == -2004287478 {
    @core.pause_stream_error_device_not_available()
  } else {
    @core.pause_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn format_tag_from_sample_format(fmt : @core.SampleFormat) -> UInt? {
  match fmt {
    @core.SampleFormat::F32 => Some((1 : UInt))
    @core.SampleFormat::I16 => Some((2 : UInt))
    @core.SampleFormat::U8 => Some((4 : UInt))
    // Match upstream WASAPI supported_formats: i24/u24/i32/i64 use WAVE_FORMAT_EXTENSIBLE.
    @core.SampleFormat::I24 => Some((6 : UInt))
    @core.SampleFormat::U24 => Some((7 : UInt))
    @core.SampleFormat::I32 => Some((8 : UInt))
    @core.SampleFormat::I64 => Some((10 : UInt))
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
fn choose_default_sample_format(
  ranges : Array[@core.SupportedStreamConfigRange],
  config : @core.StreamConfig,
) -> @core.SampleFormat? {
  let sr = config.sample_rate
  let ch = config.channels
  let mut best : @core.SupportedStreamConfigRange? = None
  for r in ranges {
    if r.channels() == ch &&
      r.min_sample_rate() <= sr &&
      sr <= r.max_sample_rate() &&
      format_tag_from_sample_format(r.sample_format()) != None {
      match best {
        None => best = Some(r)
        Some(b) => if r.cmp_default_heuristics(b) > 0 { best = Some(r) }
      }
    }
  }
  match best {
    None => None
    Some(r) => Some(r.sample_format())
  }
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
  if @core.native_os() != @core.NativeOs::Windows {
    raise_build_hresult("wasapi build_output_stream_raw", -1)
  }
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  // Early validation: negative Fixed values are invalid (not representable in upstream CPAL).
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
  let ranges = self.supported_output_configs()
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  ignore(r)
  let dev = @core.string_to_utf8_bytes(self.id)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = wasapi_stream_build_output(
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
    raise_build_hresult("wasapi_stream_build_output", st)
  }
  {
    kind: StreamKind::Output,
    handle: out[0],
    owner: wasapi_stream_owner_new(out[0]),
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
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  let ranges = self.supported_output_configs()
  let fmt = match choose_default_sample_format(ranges, config) {
    Some(f) => f
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  Device::build_output_stream_raw(
    self, config, fmt, data_callback, error_callback, _timeout,
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
  if @core.native_os() != @core.NativeOs::Windows {
    raise_build_hresult("wasapi build_input_stream_raw", -1)
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
  // Match upstream WASAPI semantics: building an input stream on a render endpoint enables
  // loopback capture. Supported input configs are still empty for render endpoints, so we must
  // validate against supported output configs when data_flow indicates render.
  let ranges = match data_flow_tag(self.id) {
    Some(2) => self.supported_output_configs()
    _ => self.supported_input_configs()
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  ignore(r)
  let dev = @core.string_to_utf8_bytes(self.id)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = wasapi_stream_build_input(
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
    raise_build_hresult("wasapi_stream_build_input", st)
  }
  {
    kind: StreamKind::Input,
    handle: out[0],
    owner: wasapi_stream_owner_new(out[0]),
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
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  let ranges = self.supported_input_configs()
  let fmt = match choose_default_sample_format(ranges, config) {
    Some(f) => f
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  Device::build_input_stream_raw(
    self, config, fmt, data_callback, error_callback, _timeout,
  )
}

///|
/// Build a loopback capture stream (Windows-only).
///
/// This captures audio from the default render (output) endpoint using WASAPI loopback mode.
/// It is primarily used by CI smoke tests to validate the input pipeline when no capture
/// devices exist on the machine.
pub fn Device::build_loopback_input_stream(
  _self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  if @core.native_os() != @core.NativeOs::Windows {
    raise_build_hresult("wasapi build_loopback_input_stream", -1)
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

  // Loopback capture uses a render endpoint; validate using output configs.
  let ranges = _self.supported_output_configs()
  let fmt = match choose_default_sample_format(ranges, config) {
    Some(f) => f
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  let fmt_tag = match format_tag_from_sample_format(fmt) {
    Some(t) => t
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  let r = match find_matching_range_for_format(ranges, config, fmt) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  ignore(r)

  // We pass a special sentinel id to the C layer to enable loopback on the default render endpoint.
  let dev = @core.string_to_utf8_bytes("loopback")
  let out = FixedArray::make(1, (0 : UInt64))
  let st = wasapi_stream_build_input(
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
    raise_build_hresult("wasapi_stream_build_input(loopback)", st)
  }
  {
    kind: StreamKind::Input,
    handle: out[0],
    owner: wasapi_stream_owner_new(out[0]),
  }
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  let st = wasapi_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_hresult("wasapi_stream_owner_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  let st = wasapi_stream_owner_pause(self.owner)
  if st < 0 {
    raise_pause_hresult("wasapi_stream_owner_pause", st)
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  if self.handle == 0 {
    return
  }
  wasapi_stream_owner_close(self.owner) |> ignore
}
