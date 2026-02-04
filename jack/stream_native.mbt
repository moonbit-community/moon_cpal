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
) -> A raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific("\{op}: \{status}")
}

///|
fn[A] raise_play_error(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PlayStreamError {
  raise @moon_cpal.play_stream_error_backend_specific("\{op}: \{status}")
}

///|
fn[A] raise_pause_error(
  op : String,
  status : Int,
) -> A raise @moon_cpal.PauseStreamError {
  raise @moon_cpal.pause_stream_error_backend_specific("\{op}: \{status}")
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
  config : @moon_cpal.StreamConfig,
) -> Unit raise @moon_cpal.BuildStreamError {
  match config.buffer_size {
    Default => ()
    Fixed(n) => {
      if n <= 0 {
        raise @moon_cpal.build_stream_error_invalid_argument()
      }
      match default_server_config() {
        None => ()
        Some((_sr, buf)) =>
          if n != buf {
            raise @moon_cpal.build_stream_error_stream_config_not_supported()
          }
      }
    }
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
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise_build_error("jack build_output_stream", -1)
  }
  validate_buffer_size_or_raise(config)
  // Force F32 for now.
  let fmt_tag = (1 : UInt)
  let dev = @moon_cpal.string_to_utf8_bytes(self.id)
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
pub fn Device::build_input_stream(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise_build_error("jack build_input_stream", -1)
  }
  validate_buffer_size_or_raise(config)
  let fmt_tag = (1 : UInt)
  let dev = @moon_cpal.string_to_utf8_bytes(self.id)
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
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  let st = jack_stream_owner_play(self.owner)
  if st < 0 {
    raise_play_error("jack_stream_owner_play", st)
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
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
