///|
/// Trampolines used to bridge native JACK worker threads (C) to MoonBit closures.

///|
fn sample_format_from_tag(tag : UInt) -> @moon_cpal.SampleFormat {
  match tag {
    1 => @moon_cpal.SampleFormat::F32
    _ => @moon_cpal.SampleFormat::F32
  }
}

///|
fn call_output_data_callback(
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  sample_format_tag : UInt,
  bytes : FixedArray[Byte],
  callback_secs : Int64,
  callback_nanos : Int,
  playback_secs : Int64,
  playback_nanos : Int,
) -> Unit {
  let fmt = sample_format_from_tag(sample_format_tag)
  let data = @moon_cpal.Data::new(fmt, bytes)
  let callback = @moon_cpal.StreamInstant::new(callback_secs, callback_nanos)
  let playback = @moon_cpal.StreamInstant::new(playback_secs, playback_nanos)
  let ts = @moon_cpal.OutputStreamTimestamp::new(callback, playback)
  let info = @moon_cpal.OutputCallbackInfo::new(ts)
  data_callback(data, info)
}

///|
let call_output_data_callback_fr : FuncRef[
  (
    (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
    UInt,
    FixedArray[Byte],
    Int64,
    Int,
    Int64,
    Int,
  ) -> Unit,
] = fn(
  data_callback,
  sample_format_tag,
  bytes,
  callback_secs,
  callback_nanos,
  playback_secs,
  playback_nanos,
) {
  call_output_data_callback(
    data_callback, sample_format_tag, bytes, callback_secs, callback_nanos, playback_secs,
    playback_nanos,
  )
}

///|
fn call_input_data_callback(
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  sample_format_tag : UInt,
  bytes : FixedArray[Byte],
  callback_secs : Int64,
  callback_nanos : Int,
  capture_secs : Int64,
  capture_nanos : Int,
) -> Unit {
  let fmt = sample_format_from_tag(sample_format_tag)
  let data = @moon_cpal.Data::new(fmt, bytes)
  let callback = @moon_cpal.StreamInstant::new(callback_secs, callback_nanos)
  let capture = @moon_cpal.StreamInstant::new(capture_secs, capture_nanos)
  let ts = @moon_cpal.InputStreamTimestamp::new(callback, capture)
  let info = @moon_cpal.InputCallbackInfo::new(ts)
  data_callback(data, info)
}

///|
let call_input_data_callback_fr : FuncRef[
  (
    (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
    UInt,
    FixedArray[Byte],
    Int64,
    Int,
    Int64,
    Int,
  ) -> Unit,
] = fn(
  data_callback,
  sample_format_tag,
  bytes,
  callback_secs,
  callback_nanos,
  capture_secs,
  capture_nanos,
) {
  call_input_data_callback(
    data_callback, sample_format_tag, bytes, callback_secs, callback_nanos, capture_secs,
    capture_nanos,
  )
}

///|
fn call_stream_error_callback(
  error_callback : (@moon_cpal.StreamError) -> Unit,
  op_tag : Int,
  status : Int,
) -> Unit {
  let op = match op_tag {
    1 => "jack_client_open"
    2 => "jack_activate"
    3 => "jack_port_register"
    4 => "jack_set_process_callback"
    _ => "JackStream"
  }
  let err = if op_tag == 1 && status != 0 {
    // Opening a JACK client failed; most commonly the server is not running or unreachable.
    @moon_cpal.stream_error_device_not_available()
  } else if op_tag == 0 && (status == 2 || status == 19 || status == 111) {
    // ENOENT / ENODEV / ECONNREFUSED
    @moon_cpal.stream_error_device_not_available()
  } else if op_tag == 0 && status == 32 {
    // EPIPE (broken pipe): treat as invalidated.
    @moon_cpal.stream_error_stream_invalidated()
  } else if op_tag == 2 || op_tag == 3 || op_tag == 4 {
    // Activation/registration failures invalidate the stream graph.
    @moon_cpal.stream_error_stream_invalidated()
  } else {
    @moon_cpal.stream_error_backend_specific("\{op} (status \{status})")
  }
  error_callback(err)
}

///|
let call_stream_error_callback_fr : FuncRef[
  ((@moon_cpal.StreamError) -> Unit, Int, Int) -> Unit,
] = fn(error_callback, op_tag, status) {
  call_stream_error_callback(error_callback, op_tag, status)
}
