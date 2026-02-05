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
) -> A raise @moon_cpal.BuildStreamError {
  raise alsa_build_error_from_errno(status, op)
}

///|
fn[A] raise_play_errno(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PlayStreamError {
  raise alsa_play_error_from_errno(status, op)
}

///|
fn[A] raise_pause_errno(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PauseStreamError {
  raise alsa_pause_error_from_errno(status, op)
}

///|
fn alsa_build_error_from_errno(
  status : Int,
  op : String,
) -> @moon_cpal.BuildStreamError {
  // Best-effort errno mapping (Linux).
  if status == -2 || status == -1 || status == -13 || status == -19 || status == -524 {
    // ENOENT / EPERM / EACCES / ENODEV / ENOTSUPP
    @moon_cpal.build_stream_error_device_not_available()
  } else if status == -16 || status == -11 {
    // EBUSY / EAGAIN
    @moon_cpal.build_stream_error_device_busy()
  } else if status == -22 {
    // EINVAL
    @moon_cpal.build_stream_error_invalid_argument()
  } else {
    @moon_cpal.build_stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
fn build_error_from_supported_configs_error(
  e : @moon_cpal.SupportedStreamConfigsError,
) -> @moon_cpal.BuildStreamError {
  match e {
    @moon_cpal.SupportedStreamConfigsError::DeviceNotAvailable =>
      @moon_cpal.build_stream_error_device_not_available()
    @moon_cpal.SupportedStreamConfigsError::DeviceBusy =>
      @moon_cpal.build_stream_error_device_busy()
    @moon_cpal.SupportedStreamConfigsError::InvalidArgument =>
      @moon_cpal.build_stream_error_invalid_argument()
    @moon_cpal.SupportedStreamConfigsError::BackendSpecific(err) =>
      @moon_cpal.build_stream_error_backend_specific(err.description())
  }
}

///|
fn alsa_play_error_from_errno(
  status : Int,
  op : String,
) -> @moon_cpal.PlayStreamError {
  if status == -2 || status == -1 || status == -13 || status == -19 {
    @moon_cpal.play_stream_error_device_not_available()
  } else {
    @moon_cpal.play_stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
fn alsa_pause_error_from_errno(
  status : Int,
  op : String,
) -> @moon_cpal.PauseStreamError {
  if status == -2 || status == -1 || status == -13 || status == -19 {
    @moon_cpal.pause_stream_error_device_not_available()
  } else {
    @moon_cpal.pause_stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
fn format_tag_from_range(r : @moon_cpal.SupportedStreamConfigRange) -> UInt? {
  match r.sample_format() {
    @moon_cpal.SampleFormat::F32 => Some((1 : UInt))
    @moon_cpal.SampleFormat::I16 => Some((2 : UInt))
    _ => None
  }
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
fn choose_default_range(
  ranges : Array[@moon_cpal.SupportedStreamConfigRange],
  config : @moon_cpal.StreamConfig,
) -> @moon_cpal.SupportedStreamConfigRange? {
  let sr = config.sample_rate
  let ch = config.channels
  let mut best : @moon_cpal.SupportedStreamConfigRange? = None
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
fn buffer_frames_from_config(config : @moon_cpal.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => 0
    Fixed(n) => if n > 0 { n.reinterpret_as_uint() } else { 0 }
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
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise_build_errno("alsa build_output_stream_raw", -1)
  }
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  let ranges = try self.supported_output_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(r, config)
  let dev = @moon_cpal.string_to_ascii_bytes(self.id)
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
  {
    kind: StreamKind::Output,
    handle: out[0],
    owner: alsa_stream_owner_new(out[0]),
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
  let ranges = try self.supported_output_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match choose_default_range(ranges, config) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
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
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise_build_errno("alsa build_input_stream_raw", -1)
  }
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @moon_cpal.build_stream_error_invalid_argument()
  }
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  let ranges = try self.supported_input_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(r, config)
  let dev = @moon_cpal.string_to_ascii_bytes(self.id)
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
  {
    kind: StreamKind::Input,
    handle: out[0],
    owner: alsa_stream_owner_new(out[0]),
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
  let ranges = try self.supported_input_configs() catch {
    e => raise build_error_from_supported_configs_error(e)
  } noraise {
    xs => xs
  }
  let r = match choose_default_range(ranges, config) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
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
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  let st = alsa_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_errno("alsa_stream_owner_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
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
