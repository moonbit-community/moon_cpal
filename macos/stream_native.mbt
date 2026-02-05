///|
/// CoreAudio streams (macOS, native target).
///
/// Implementation strategy:
/// - Use `AudioQueue` to create output/input streams.
/// - Bridge AudioQueue buffers into MoonBit callbacks via C trampolines.
///   - Output callback receives a writable `Data` buffer that will be copied into AudioQueue.
///   - Input callback receives captured bytes copied from AudioQueue.
/// - Timestamps are best-effort: input uses AudioQueue start host time when available; output uses
///   AudioQueue current time host time when available; otherwise fallback to `mach_absolute_time`.

///|
#borrow(out_handles)
#owned(data_callback, error_callback)
extern "C" fn ca_stream_build_output(
  device_id : UInt,
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
) -> Int = "moon_cpal_ca_stream_build_output"

///|
#borrow(out_handles)
#owned(data_callback, error_callback)
extern "C" fn ca_stream_build_input(
  device_id : UInt,
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
) -> Int = "moon_cpal_ca_stream_build_input"

///|
extern "C" fn ca_stream_owner_new(handle : UInt64) -> StreamOwner = "moon_cpal_ca_stream_owner_new"

///|
#borrow(owner)
extern "C" fn ca_stream_owner_play(owner : StreamOwner) -> Int = "moon_cpal_ca_stream_owner_play"

///|
#borrow(owner)
extern "C" fn ca_stream_owner_pause(owner : StreamOwner) -> Int = "moon_cpal_ca_stream_owner_pause"

///|
#borrow(owner)
extern "C" fn ca_stream_owner_close(owner : StreamOwner) -> Int = "moon_cpal_ca_stream_owner_close"

///|
fn[A] raise_build_osstatus(
  op : String,
  status : Int,
) -> A raise @core.BuildStreamError {
  match osstatus_kind(status) {
    1 => raise @core.build_stream_error_device_not_available()
    2 => raise @core.build_stream_error_stream_config_not_supported()
    4 => raise @core.build_stream_error_invalid_argument()
    _ =>
      raise @core.build_stream_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}

///|
fn[A] raise_play_osstatus(
  op : String,
  status : Int,
) -> A raise @core.PlayStreamError {
  match osstatus_kind(status) {
    1 => raise @core.play_stream_error_device_not_available()
    _ =>
      raise @core.play_stream_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}

///|
fn[A] raise_pause_osstatus(
  op : String,
  status : Int,
) -> A raise @core.PauseStreamError {
  match osstatus_kind(status) {
    1 => raise @core.pause_stream_error_device_not_available()
    _ =>
      raise @core.pause_stream_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}

///|

///|

///|
fn format_tag_from_range(r : @core.SupportedStreamConfigRange) -> UInt? {
  match r.sample_format() {
    @core.SampleFormat::F32 => Some((1 : UInt))
    @core.SampleFormat::I16 => Some((2 : UInt))
    _ => None
  }
}

///|
fn format_tag_from_sample_format(fmt : @core.SampleFormat) -> UInt? {
  match fmt {
    @core.SampleFormat::F32 => Some((1 : UInt))
    @core.SampleFormat::I16 => Some((2 : UInt))
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
fn validate_buffer_size_or_raise(
  r : @core.SupportedStreamConfigRange,
  config : @core.StreamConfig,
) -> Unit raise @core.BuildStreamError {
  match config.buffer_size {
    Default => ()
    Fixed(n) => {
      if n < 0 {
        raise @core.build_stream_error_invalid_argument()
      }
      if !r.buffer_size().contains(n) {
        raise @core.build_stream_error_stream_config_not_supported()
      }
    }
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
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  let ranges = try self.supported_output_configs() catch {
    CoreAudioError(op, status) => raise_build_osstatus(op, status)
    DeviceNotAvailable(op, status) => raise_build_osstatus(op, status)
  } noraise {
    rs => rs
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(r, config)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = ca_stream_build_output(
    self.id,
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
    raise_build_osstatus("ca_stream_build_output", st)
  }
  {
    kind: StreamKind::Output,
    handle: out[0],
    owner: ca_stream_owner_new(out[0]),
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
  let ranges = try self.supported_output_configs() catch {
    CoreAudioError(op, status) => raise_build_osstatus(op, status)
    DeviceNotAvailable(op, status) => raise_build_osstatus(op, status)
  } noraise {
    rs => rs
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
  if config.channels <= 0 || config.sample_rate <= 0 {
    raise @core.build_stream_error_invalid_argument()
  }
  let fmt_tag = match format_tag_from_sample_format(sample_format) {
    Some(t) => t
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  let ranges = try self.supported_input_configs() catch {
    CoreAudioError(op, status) => raise_build_osstatus(op, status)
    DeviceNotAvailable(op, status) => raise_build_osstatus(op, status)
  } noraise {
    rs => rs
  }
  let r = match find_matching_range_for_format(ranges, config, sample_format) {
    Some(r) => r
    None => raise @core.build_stream_error_stream_config_not_supported()
  }
  validate_buffer_size_or_raise(r, config)
  let out = FixedArray::make(1, (0 : UInt64))
  let st = ca_stream_build_input(
    self.id,
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
    raise_build_osstatus("ca_stream_build_input", st)
  }
  {
    kind: StreamKind::Input,
    handle: out[0],
    owner: ca_stream_owner_new(out[0]),
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
  let ranges = try self.supported_input_configs() catch {
    CoreAudioError(op, status) => raise_build_osstatus(op, status)
    DeviceNotAvailable(op, status) => raise_build_osstatus(op, status)
  } noraise {
    rs => rs
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
  if self.handle == 0 {
    raise @core.play_stream_error_backend_specific("invalid stream handle")
  }
  let st = ca_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_osstatus("ca_stream_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  if self.handle == 0 {
    raise @core.pause_stream_error_backend_specific("invalid stream handle")
  }
  let st = ca_stream_owner_pause(self.owner)
  if st < 0 {
    raise_pause_osstatus("ca_stream_pause", st)
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  if self.handle == 0 {
    return
  }
  ca_stream_owner_close(self.owner) |> ignore
}
