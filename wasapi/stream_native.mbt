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
) -> A raise @moon_cpal.BuildStreamError {
  raise wasapi_build_error_from_hresult(status, op)
}

///|
fn[A] raise_play_hresult(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PlayStreamError {
  raise wasapi_play_error_from_hresult(status, op)
}

///|
fn[A] raise_pause_hresult(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PauseStreamError {
  raise wasapi_pause_error_from_hresult(status, op)
}

///|
fn wasapi_build_error_from_hresult(
  status : Int,
  op : String,
) -> @moon_cpal.BuildStreamError {
  // Best-effort mapping. The WASAPI C layer passes HRESULT as signed 32-bit int.
  //
  // Known values:
  // - AUDCLNT_E_DEVICE_INVALIDATED = 0x88890004 (-2004287484)
  // - AUDCLNT_E_DEVICE_IN_USE     = 0x8889000A (-2004287478)
  // - AUDCLNT_E_UNSUPPORTED_FORMAT= 0x88890008 (-2004287480)
  // - AUDCLNT_E_BUFFER_SIZE_ERROR = 0x88890019 (-2004287463)
  // - AUDCLNT_E_ENDPOINT_CREATE_FAILED = 0x8889000E (-2004287474)
  // - AUDCLNT_E_SERVICE_NOT_RUNNING   = 0x88890010 (-2004287472)
  // - E_INVALIDARG                = 0x80070057 (-2147024809)
  if status == -2004287484 || status == -2004287474 || status == -2004287472 {
    @moon_cpal.build_stream_error_device_not_available()
  } else if status == -2004287478 {
    @moon_cpal.build_stream_error_device_busy()
  } else if status == -2004287480 || status == -2004287463 {
    @moon_cpal.build_stream_error_stream_config_not_supported()
  } else if status == -2147024809 {
    @moon_cpal.build_stream_error_invalid_argument()
  } else {
    @moon_cpal.build_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_play_error_from_hresult(
  status : Int,
  op : String,
) -> @moon_cpal.PlayStreamError {
  if status == -2004287484 || status == -2004287478 || status == -2004287474 || status == -2004287472 {
    @moon_cpal.play_stream_error_device_not_available()
  } else {
    @moon_cpal.play_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn wasapi_pause_error_from_hresult(
  status : Int,
  op : String,
) -> @moon_cpal.PauseStreamError {
  if status == -2004287484 || status == -2004287478 || status == -2004287474 || status == -2004287472 {
    @moon_cpal.pause_stream_error_device_not_available()
  } else {
    @moon_cpal.pause_stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
fn choose_format_tag(
  ranges : Array[@moon_cpal.SupportedStreamConfigRange],
  config : @moon_cpal.StreamConfig,
) -> UInt? {
  let sr = config.sample_rate
  let ch = config.channels
  for r in ranges {
    if r.channels() == ch &&
      r.min_sample_rate() <= sr &&
      sr <= r.max_sample_rate() {
      return match r.sample_format() {
        @moon_cpal.SampleFormat::F32 => Some((1 : UInt))
        @moon_cpal.SampleFormat::I16 => Some((2 : UInt))
        _ => None
      }
    }
  }
  None
}

///|
fn format_tag_from_sample_format(fmt : @moon_cpal.SampleFormat) -> UInt? {
  match fmt {
    @moon_cpal.SampleFormat::F32 => Some((1 : UInt))
    @moon_cpal.SampleFormat::I16 => Some((2 : UInt))
    _ => None
  }
}

///|
fn find_matching_range_for_format(
  ranges : Array[@moon_cpal.SupportedStreamConfigRange],
  config : @moon_cpal.StreamConfig,
  fmt : @moon_cpal.SampleFormat,
) -> @moon_cpal.SupportedStreamConfigRange? {
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
  ranges : Array[@moon_cpal.SupportedStreamConfigRange],
  config : @moon_cpal.StreamConfig,
) -> @moon_cpal.SampleFormat? {
  let sr = config.sample_rate
  let ch = config.channels
  let mut best : @moon_cpal.SupportedStreamConfigRange? = None
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
fn buffer_frames_from_config(config : @moon_cpal.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => 0
    Fixed(n) => if n > 0 { n.reinterpret_as_uint() } else { 0 }
  }
}

///|
fn validate_buffer_size_or_raise(
  r : @moon_cpal.SupportedStreamConfigRange,
  config : @moon_cpal.StreamConfig,
) -> Unit raise @moon_cpal.BuildStreamError {
  match config.buffer_size {
    Default => ()
    Fixed(n) => {
      if n <= 0 {
        raise @moon_cpal.build_stream_error_invalid_argument()
      }
      if !r.buffer_size().contains(n) {
        raise @moon_cpal.build_stream_error_stream_config_not_supported()
      }
    }
  }
}

///|
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    raise_build_hresult("wasapi build_output_stream_raw", -1)
  }
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  let ranges = self.supported_output_configs()
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(r, config)
  let dev = @moon_cpal.string_to_utf8_bytes(self.id)
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
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  let ranges = self.supported_output_configs()
  let fmt = match choose_default_sample_format(ranges, config) {
    Some(f) => f
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  Device::build_output_stream_raw(
    self, config, fmt, data_callback, error_callback, _timeout,
  )
}

///|
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    raise_build_hresult("wasapi build_input_stream_raw", -1)
  }
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  let ranges = self.supported_input_configs()
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(r, config)
  let dev = @moon_cpal.string_to_utf8_bytes(self.id)
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
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  let ranges = self.supported_input_configs()
  let fmt = match choose_default_sample_format(ranges, config) {
    Some(f) => f
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
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
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    raise_build_hresult("wasapi build_loopback_input_stream", -1)
  }
  // We pass a special sentinel id to the C layer to enable loopback.
  let dev = @moon_cpal.string_to_utf8_bytes("loopback")
  let ranges = _self.supported_input_configs()
  let fmt_tag = match choose_format_tag(ranges, config) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
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
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  let st = wasapi_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_hresult("wasapi_stream_owner_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
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
