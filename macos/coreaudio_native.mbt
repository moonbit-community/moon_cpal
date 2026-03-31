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
/// CoreAudio device discovery (macOS, native backend only).
///
/// This is intentionally a small, testable slice: device enumeration and names.
pub type DeviceId = UInt

///|
extern "C" fn ca_default_output_device_id() -> UInt = "moon_cpal_ca_default_output_device_id"

///|
extern "C" fn ca_default_input_device_id() -> UInt = "moon_cpal_ca_default_input_device_id"

///|
extern "C" fn ca_device_count() -> Int = "moon_cpal_ca_device_count"

///|
#borrow(out)
extern "C" fn ca_get_devices(out : FixedArray[UInt], max : Int) -> Int = "moon_cpal_ca_get_devices"

///|
extern "C" fn ca_device_name_utf8_len(device_id : UInt) -> Int = "moon_cpal_ca_device_name_utf8_len"

///|
#borrow(out)
extern "C" fn ca_device_name_utf8(
  device_id : UInt,
  out : Bytes,
  out_len : Int,
) -> Int = "moon_cpal_ca_device_name_utf8"

///|
extern "C" fn ca_device_uid_utf8_len(device_id : UInt) -> Int = "moon_cpal_ca_device_uid_utf8_len"

///|
#borrow(out)
extern "C" fn ca_device_uid_utf8(
  device_id : UInt,
  out : Bytes,
  out_len : Int,
) -> Int = "moon_cpal_ca_device_uid_utf8"

///|
extern "C" fn ca_device_manufacturer_utf8_len(device_id : UInt) -> Int = "moon_cpal_ca_device_manufacturer_utf8_len"

///|
#borrow(out)
extern "C" fn ca_device_manufacturer_utf8(
  device_id : UInt,
  out : Bytes,
  out_len : Int,
) -> Int = "moon_cpal_ca_device_manufacturer_utf8"

///|
extern "C" fn ca_device_transport_type_u32(device_id : UInt) -> UInt = "moon_cpal_ca_device_transport_type_u32"

///|
extern "C" fn ca_device_is_aggregate(device_id : UInt) -> Int = "moon_cpal_ca_device_is_aggregate"

///|
extern "C" fn ca_device_interface_type_tag(device_id : UInt) -> Int = "moon_cpal_ca_device_interface_type_tag"

///|
extern "C" fn ca_input_channel_count(device_id : UInt) -> Int = "moon_cpal_ca_input_channel_count"

///|
extern "C" fn ca_output_channel_count(device_id : UInt) -> Int = "moon_cpal_ca_output_channel_count"

///|
extern "C" fn ca_input_sample_rate_ranges_count(device_id : UInt) -> Int = "moon_cpal_ca_input_sample_rate_ranges_count"

///|
extern "C" fn ca_output_sample_rate_ranges_count(device_id : UInt) -> Int = "moon_cpal_ca_output_sample_rate_ranges_count"

///|
#borrow(out_mins, out_maxs)
extern "C" fn ca_input_sample_rate_ranges(
  device_id : UInt,
  out_mins : FixedArray[Double],
  out_maxs : FixedArray[Double],
  max : Int,
) -> Int = "moon_cpal_ca_input_sample_rate_ranges"

///|
#borrow(out_mins, out_maxs)
extern "C" fn ca_output_sample_rate_ranges(
  device_id : UInt,
  out_mins : FixedArray[Double],
  out_maxs : FixedArray[Double],
  max : Int,
) -> Int = "moon_cpal_ca_output_sample_rate_ranges"

///|
#borrow(out)
extern "C" fn ca_buffer_frame_size_range(
  device_id : UInt,
  out : FixedArray[UInt],
  out_len : Int,
) -> Int = "moon_cpal_ca_buffer_frame_size_range"

///|
#borrow(out)
extern "C" fn ca_default_stream_config(
  device_id : UInt,
  input : Int,
  out : FixedArray[UInt],
  out_len : Int,
) -> Int = "moon_cpal_ca_default_stream_config"

///|
extern "C" fn ca_set_nominal_sample_rate(
  device_id : UInt,
  sample_rate : Double,
) -> Int = "moon_cpal_ca_set_nominal_sample_rate"

///|
extern "C" fn ca_osstatus_kind(status : Int) -> Int = "moon_cpal_ca_osstatus_kind"

///|
fn osstatus_kind(status : Int) -> Int {
  ca_osstatus_kind(status)
}

///|
fn utf8_bytes_to_mbt_string(bytes : Bytes, length : Int) -> String {
  let res = StringBuilder::new()
  let len = if length < bytes.length() { length } else { bytes.length() }
  let mut i = 0
  while i < len {
    let mut c = bytes[i].to_int()
    if c < 0x80 {
      res.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 0xE0 {
      if i + 1 >= len {
        break
      }
      c = ((c & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      res.write_char(c.unsafe_to_char())
      i += 2
    } else if c < 0xF0 {
      if i + 2 >= len {
        break
      }
      c = ((c & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      res.write_char(c.unsafe_to_char())
      i += 3
    } else {
      if i + 3 >= len {
        break
      }
      c = ((c & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      c -= 0x10000
      res.write_char(((c >> 10) + 0xD800).unsafe_to_char())
      res.write_char(((c & 0x3FF) + 0xDC00).unsafe_to_char())
      i += 4
    }
  }
  res.to_string()
}

///|
fn get_buffer_frame_size_range(
  device_id : DeviceId,
) -> @core.SupportedBufferSize raise CoreAudioError {
  let out = FixedArray::make(2, (0 : UInt))
  let st = ca_buffer_frame_size_range(device_id, out, 2)
  if st < 0 {
    raise_osstatus("ca_buffer_frame_size_range", st)
  }
  @core.SupportedBufferSize::Range(
    min=out[0].reinterpret_as_int(),
    max=out[1].reinterpret_as_int(),
  )
}

///|
fn get_buffer_frame_size_range_default(
  device_id : DeviceId,
) -> @core.SupportedBufferSize raise @core.DefaultStreamConfigError {
  let out = FixedArray::make(2, (0 : UInt))
  let st = ca_buffer_frame_size_range(device_id, out, 2)
  if st < 0 {
    raise_default_osstatus("ca_buffer_frame_size_range", st)
  }
  @core.SupportedBufferSize::Range(
    min=out[0].reinterpret_as_int(),
    max=out[1].reinterpret_as_int(),
  )
}

///|
fn default_stream_config(
  device_id : DeviceId,
  input~ : Bool,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  // Layout: [sample_rate, channels, sample_format_tag]
  // - sample_format_tag: 1 => F32, 2 => I16, other => unsupported
  let out = FixedArray::make(3, (0 : UInt))
  let st = ca_default_stream_config(
    device_id,
    if input {
      1
    } else {
      0
    },
    out,
    3,
  )
  if st < 0 {
    raise_default_osstatus("ca_default_stream_config", st)
  }
  let sample_rate = out[0].reinterpret_as_int()
  let channels = out[1].reinterpret_as_int()
  let sample_format = match out[2] {
    1 => @core.SampleFormat::F32
    2 => @core.SampleFormat::I16
    _ => raise @core.default_stream_config_error_stream_type_not_supported()
  }
  let buffer_size = get_buffer_frame_size_range_default(device_id)
  @core.SupportedStreamConfig(channels, sample_rate, buffer_size, sample_format)
}

///|
fn set_nominal_sample_rate(
  device_id : DeviceId,
  sample_rate : Int,
) -> Unit raise CoreAudioError {
  if sample_rate <= 0 {
    raise CoreAudioError("ca_set_nominal_sample_rate", -50)
  }
  let st = ca_set_nominal_sample_rate(device_id, sample_rate.to_double())
  if st < 0 {
    raise_osstatus("ca_set_nominal_sample_rate", st)
  }
}

///|
fn sample_rate_ranges(
  device_id : DeviceId,
  input~ : Bool,
) -> Array[(Double, Double)] raise CoreAudioError {
  let n = if input {
    ca_input_sample_rate_ranges_count(device_id)
  } else {
    ca_output_sample_rate_ranges_count(device_id)
  }
  if n < 0 {
    raise_osstatus("ca_sample_rate_ranges_count", n)
  }
  if n == 0 {
    return []
  }
  let mins = FixedArray::make(n, 0.0)
  let maxs = FixedArray::make(n, 0.0)
  let got = if input {
    ca_input_sample_rate_ranges(device_id, mins, maxs, n)
  } else {
    ca_output_sample_rate_ranges(device_id, mins, maxs, n)
  }
  if got < 0 {
    raise_osstatus("ca_sample_rate_ranges", got)
  }
  let got = if got < n { got } else { n }
  let out = Array::new(capacity=got)
  for i in 0..<got {
    out.push((mins[i], maxs[i]))
  }
  out
}

///|
fn supported_configs(
  device_id : DeviceId,
  input~ : Bool,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  let channels = if input {
    ca_input_channel_count(device_id)
  } else {
    ca_output_channel_count(device_id)
  }
  if channels < 0 {
    raise_osstatus(
      if input {
        "ca_input_channel_count"
      } else {
        "ca_output_channel_count"
      },
      channels,
    )
  }
  if channels == 0 {
    return []
  }

  // NOTE: Upstream cpal currently returns F32 for macOS supported configs.
  let sample_format = @core.SampleFormat::F32
  let buffer_size = get_buffer_frame_size_range(device_id)
  let ranges = sample_rate_ranges(device_id, input~)
  if ranges.is_empty() {
    return []
  }
  let mut contains_different = false
  for i in 0..<ranges.length() {
    let (minv, maxv) = ranges[i]
    if minv != maxv {
      contains_different = true
      break
    }
  }
  if contains_different {
    let out = Array::new(capacity=ranges.length())
    for i in 0..<ranges.length() {
      let (minv, maxv) = ranges[i]
      out.push(
        @core.SupportedStreamConfigRange(
          channels,
          minv.to_int(),
          maxv.to_int(),
          buffer_size,
          sample_format,
        ),
      )
    }
    out
  } else {
    let mut min_sr = ranges[0].0.to_int()
    let mut max_sr = ranges[0].1.to_int()
    for i in 0..<ranges.length() {
      let (minv, maxv) = ranges[i]
      let mn = minv.to_int()
      let mx = maxv.to_int()
      if mn < min_sr {
        min_sr = mn
      }
      if mx > max_sr {
        max_sr = mx
      }
    }
    [
      @core.SupportedStreamConfigRange(
        channels, min_sr, max_sr, buffer_size, sample_format,
      ),
    ]
  }
}

///|
pub fn default_output_device_id() -> DeviceId? {
  let id = ca_default_output_device_id()
  if id == 0 {
    None
  } else {
    Some(id)
  }
}

///|
pub fn default_input_device_id() -> DeviceId? {
  let id = ca_default_input_device_id()
  if id == 0 {
    None
  } else {
    Some(id)
  }
}

///|
pub fn device_ids() -> Array[DeviceId] raise CoreAudioError {
  let n = ca_device_count()
  if n < 0 {
    raise_osstatus("ca_device_count", n)
  }
  if n == 0 {
    return []
  }
  let buf = FixedArray::make(n, (0 : UInt))
  let got = ca_get_devices(buf, n)
  if got < 0 {
    raise_osstatus("ca_get_devices", got)
  }
  if got == 0 {
    []
  } else if got == n {
    buf[:].to_array()
  } else {
    buf[:got].to_array()
  }
}

///|
pub fn device_name(device_id : DeviceId) -> String raise CoreAudioError {
  let need = ca_device_name_utf8_len(device_id)
  if need < 0 {
    raise_osstatus("ca_device_name_utf8_len", need)
  }
  let mut out = Bytes::new(need)
  let mut wrote = ca_device_name_utf8(device_id, out, need)
  if wrote < 0 {
    raise_osstatus("ca_device_name_utf8", wrote)
  }
  // Some CoreAudio strings may change between the length probe and the copy.
  // If the buffer was too small, the C stub returns the required length.
  if wrote > out.length() {
    out = Bytes::new(wrote)
    wrote = ca_device_name_utf8(device_id, out, wrote)
    if wrote < 0 {
      raise_osstatus("ca_device_name_utf8 (retry)", wrote)
    }
    if wrote > out.length() {
      raise_osstatus("ca_device_name_utf8 (retry overflow)", -1)
    }
  }
  utf8_bytes_to_mbt_string(out, wrote)
}

///|
pub fn device_uid(device_id : DeviceId) -> String? {
  let need = ca_device_uid_utf8_len(device_id)
  if need <= 0 {
    return None
  }
  let mut out = Bytes::new(need)
  let mut wrote = ca_device_uid_utf8(device_id, out, need)
  if wrote <= 0 {
    return None
  }
  if wrote > out.length() {
    out = Bytes::new(wrote)
    wrote = ca_device_uid_utf8(device_id, out, wrote)
    if wrote <= 0 || wrote > out.length() {
      return None
    }
  }
  Some(utf8_bytes_to_mbt_string(out, wrote))
}

///|
pub fn device_manufacturer(device_id : DeviceId) -> String? {
  let need = ca_device_manufacturer_utf8_len(device_id)
  if need <= 0 {
    return None
  }
  let mut out = Bytes::new(need)
  let mut wrote = ca_device_manufacturer_utf8(device_id, out, need)
  if wrote <= 0 {
    return None
  }
  if wrote > out.length() {
    out = Bytes::new(wrote)
    wrote = ca_device_manufacturer_utf8(device_id, out, wrote)
    if wrote <= 0 || wrote > out.length() {
      return None
    }
  }
  Some(utf8_bytes_to_mbt_string(out, wrote))
}

///|
pub fn device_transport_type_u32(device_id : DeviceId) -> UInt {
  ca_device_transport_type_u32(device_id)
}

///|
pub fn device_is_aggregate(device_id : DeviceId) -> Bool {
  ca_device_is_aggregate(device_id) > 0
}

///|
pub fn device_interface_type_tag(device_id : DeviceId) -> Int {
  ca_device_interface_type_tag(device_id)
}

///|
pub fn supported_input_configs(
  device_id : DeviceId,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  supported_configs(device_id, input=true)
}

///|
pub fn supported_output_configs(
  device_id : DeviceId,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  supported_configs(device_id, input=false)
}

///|
pub fn default_input_config(
  device_id : DeviceId,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  default_stream_config(device_id, input=true)
}

///|
pub fn default_output_config(
  device_id : DeviceId,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  default_stream_config(device_id, input=false)
}
