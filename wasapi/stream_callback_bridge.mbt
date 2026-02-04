///|
/// Trampolines used to bridge native WASAPI stream worker threads (C) to MoonBit closures.

///|
fn sample_format_from_tag(tag : UInt) -> @moon_cpal.SampleFormat {
  match tag {
    1 => @moon_cpal.SampleFormat::F32
    2 => @moon_cpal.SampleFormat::I16
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
    1 => "IAudioRenderClient"
    2 => "IAudioCaptureClient"
    3 => "IAudioClientStart"
    4 => "IAudioClientStop"
    5 => "CoInitializeEx"
    6 => "DeviceInit"
    _ => "WasapiStream"
  }
  error_callback(
    @moon_cpal.stream_error_backend_specific("\{op} (HRESULT \{status})"),
  )
}

///|
let call_stream_error_callback_fr : FuncRef[
  ((@moon_cpal.StreamError) -> Unit, Int, Int) -> Unit,
] = fn(error_callback, op_tag, status) {
  call_stream_error_callback(error_callback, op_tag, status)
}
