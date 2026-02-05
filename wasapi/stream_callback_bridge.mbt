///|
/// Trampolines used to bridge native WASAPI stream worker threads (C) to MoonBit closures.

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
    1 => "IAudioRenderClient"
    2 => "IAudioCaptureClient"
    3 => "IAudioClientStart"
    4 => "IAudioClientStop"
    5 => "CoInitializeEx"
    6 => "DeviceInit"
    _ => "WasapiStream"
  }
  error_callback(wasapi_stream_error_from_hresult(status, op))
}

///|
fn wasapi_stream_error_from_hresult(
  status : Int,
  op : String,
) -> @core.StreamError {
  // Match upstream WASAPI mapping:
  // - AUDCLNT_E_DEVICE_INVALIDATED and AUDCLNT_E_DEVICE_IN_USE -> DeviceNotAvailable
  //
  // Note: we pass HRESULT as a signed 32-bit int from C.
  // AUDCLNT_E_DEVICE_INVALIDATED = 0x88890004 (-2004287484)
  // AUDCLNT_E_DEVICE_IN_USE     = 0x8889000A (-2004287478)
  if status == -2004287484 || status == -2004287478 {
    @core.stream_error_device_not_available()
  } else {
    @core.stream_error_backend_specific("\{op} (HRESULT \{status})")
  }
}

///|
let call_stream_error_callback_fr : FuncRef[
  ((@core.StreamError) -> Unit, Int, Int) -> Unit,
] = fn(error_callback, op_tag, status) {
  call_stream_error_callback(error_callback, op_tag, status)
}
