///|
/// Trampolines used to bridge native CoreAudio callbacks (C) to user-provided MoonBit closures.
///
/// We pass these functions to C as `FuncRef[...]` (closed function pointers). C stores user closures
/// and calls back into these trampolines with raw buffer bytes and monotonic timestamps.

///|
fn sample_format_from_tag(tag : UInt) -> @core.SampleFormat {
  match tag {
    1 => @core.SampleFormat::F32
    2 => @core.SampleFormat::I16
    _ => @core.SampleFormat::F32
  }
}

///|
fn call_output_data_callback(
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  sample_format_tag : UInt,
  bytes : FixedArray[Byte],
  callback_secs : Int64,
  callback_nanos : Int,
  playback_secs : Int64,
  playback_nanos : Int,
) -> Unit {
  let fmt = sample_format_from_tag(sample_format_tag)
  let data = @core.Data::new(fmt, bytes)
  let callback = @core.StreamInstant::new(callback_secs, callback_nanos)
  let playback = @core.StreamInstant::new(playback_secs, playback_nanos)
  let ts = @core.OutputStreamTimestamp::new(callback, playback)
  let info = @core.OutputCallbackInfo::new(ts)
  data_callback(data, info)
}

///|
let call_output_data_callback_fr : FuncRef[
  (
    (@core.Data, @core.OutputCallbackInfo) -> Unit,
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
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  sample_format_tag : UInt,
  bytes : FixedArray[Byte],
  callback_secs : Int64,
  callback_nanos : Int,
  capture_secs : Int64,
  capture_nanos : Int,
) -> Unit {
  let fmt = sample_format_from_tag(sample_format_tag)
  let data = @core.Data::new(fmt, bytes)
  let callback = @core.StreamInstant::new(callback_secs, callback_nanos)
  let capture = @core.StreamInstant::new(capture_secs, capture_nanos)
  let ts = @core.InputStreamTimestamp::new(callback, capture)
  let info = @core.InputCallbackInfo::new(ts)
  data_callback(data, info)
}

///|
let call_input_data_callback_fr : FuncRef[
  (
    (@core.Data, @core.InputCallbackInfo) -> Unit,
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
  error_callback : (@core.StreamError) -> Unit,
  op_tag : Int,
  status : Int,
) -> Unit {
  let op = match op_tag {
    1 => "AudioQueueEnqueueBuffer"
    2 => "AudioQueueAllocateBuffer"
    3 => "AudioQueueStart"
    4 => "AudioQueuePause"
    _ => "CoreAudioStream"
  }
  let kind = osstatus_kind(status)
  let err = if kind == 1 {
    @core.stream_error_device_not_available()
  } else if kind == 3 {
    @core.stream_error_stream_invalidated()
  } else if kind == 5 {
    @core.stream_error_buffer_underrun()
  } else {
    @core.stream_error_backend_specific("\{op} (OSStatus \{status})")
  }
  error_callback(err)
}

///|
let call_stream_error_callback_fr : FuncRef[
  ((@core.StreamError) -> Unit, Int, Int) -> Unit,
] = fn(error_callback, op_tag, status) {
  call_stream_error_callback(error_callback, op_tag, status)
}
