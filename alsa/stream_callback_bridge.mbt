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
/// Trampolines used to bridge native ALSA stream worker threads (C) to MoonBit closures.

///|
fn sample_format_from_tag(tag : UInt) -> @core.SampleFormat {
  match tag {
    1 => @core.SampleFormat::F32
    2 => @core.SampleFormat::I16
    3 => @core.SampleFormat::U16
    4 => @core.SampleFormat::U8
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
    1 => "snd_pcm_writei"
    2 => "snd_pcm_readi"
    3 => "snd_pcm_open"
    4 => "snd_pcm_hw_params"
    5 => "pthread_create"
    6 => "xrun"
    _ => "AlsaStream"
  }
  error_callback(alsa_stream_error_from_errno(status, op))
}

///|
fn alsa_stream_error_from_errno(status : Int, op : String) -> @core.StreamError {
  // Best-effort errno mapping (Linux): match common CPAL error variants.
  //
  // Note: `status` is typically a negative errno value (e.g. -ENODEV, -EPIPE).
  if status == -2 || status == -1 || status == -13 || status == -19 {
    // ENOENT / EPERM / EACCES / ENODEV
    @core.stream_error_device_not_available()
  } else if status == -5 || status == -77 || status == -86 {
    // EIO / EBADFD / ESTRPIPE
    @core.stream_error_stream_invalidated()
  } else if status == -32 {
    // EPIPE (XRUN)
    @core.stream_error_buffer_underrun()
  } else {
    @core.stream_error_backend_specific("\{op} (errno \{status})")
  }
}

///|
let call_stream_error_callback_fr : FuncRef[
  ((@core.StreamError) -> Unit, Int, Int) -> Unit,
] = fn(error_callback, op_tag, status) {
  call_stream_error_callback(error_callback, op_tag, status)
}
