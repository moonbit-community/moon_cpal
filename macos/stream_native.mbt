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
) -> A raise @moon_cpal.BuildStreamError {
  match osstatus_kind(status) {
    1 => raise @moon_cpal.build_stream_error_device_not_available()
    2 => raise @moon_cpal.build_stream_error_stream_config_not_supported()
    4 => raise @moon_cpal.build_stream_error_invalid_argument()
    _ =>
      raise @moon_cpal.build_stream_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}

///|
fn[A] raise_play_osstatus(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PlayStreamError {
  match osstatus_kind(status) {
    1 => raise @moon_cpal.play_stream_error_device_not_available()
    _ =>
      raise @moon_cpal.play_stream_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}

///|
fn[A] raise_pause_osstatus(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PauseStreamError {
  match osstatus_kind(status) {
    1 => raise @moon_cpal.pause_stream_error_device_not_available()
    _ =>
      raise @moon_cpal.pause_stream_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}

///|
///|
fn find_matching_range(
  ranges : Array[@moon_cpal.SupportedStreamConfigRange],
  config : @moon_cpal.StreamConfig,
) -> @moon_cpal.SupportedStreamConfigRange? {
  let sr = config.sample_rate
  let ch = config.channels
  for r in ranges {
    if r.channels() == ch &&
      r.min_sample_rate() <= sr &&
      sr <= r.max_sample_rate() {
      return Some(r)
    }
  }
  None
}

///|
fn format_tag_from_range(
  r : @moon_cpal.SupportedStreamConfigRange,
) -> UInt? {
  match r.sample_format() {
    @moon_cpal.SampleFormat::F32 => Some((1 : UInt))
    @moon_cpal.SampleFormat::I16 => Some((2 : UInt))
    _ => None
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
fn buffer_frames_from_config(config : @moon_cpal.StreamConfig) -> UInt {
  match config.buffer_size {
    Default => 0
    Fixed(n) => if n > 0 { n.reinterpret_as_uint() } else { 0 }
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
  let ranges = try self.supported_output_configs() catch {
    CoreAudioError(op, status) => raise_build_osstatus(op, status)
    DeviceNotAvailable(op, status) => raise_build_osstatus(op, status)
  } noraise {
    rs => rs
  }
  let r = match find_matching_range(ranges, config) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  let fmt_tag = match format_tag_from_range(r) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
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
pub fn Device::build_input_stream(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let ranges = try self.supported_input_configs() catch {
    CoreAudioError(op, status) => raise_build_osstatus(op, status)
    DeviceNotAvailable(op, status) => raise_build_osstatus(op, status)
  } noraise {
    rs => rs
  }
  let r = match find_matching_range(ranges, config) {
    Some(r) => r
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
  }
  let fmt_tag = match format_tag_from_range(r) {
    Some(t) => t
    None => raise @moon_cpal.build_stream_error_stream_config_not_supported()
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
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  if self.handle == 0 {
    raise @moon_cpal.play_stream_error_backend_specific("invalid stream handle")
  }
  let st = ca_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_osstatus("ca_stream_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  if self.handle == 0 {
    raise @moon_cpal.pause_stream_error_backend_specific(
      "invalid stream handle",
    )
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
