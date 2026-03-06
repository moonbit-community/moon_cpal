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
/// Native FFI hooks for ALSA.
///
/// Note: on Linux, device enumeration prefers libasound (`snd_device_name_hint`) and falls back
/// to `/proc/asound/pcm` parsing.

///|
extern "C" fn alsa_devices_utf8() -> Bytes = "moon_cpal_alsa_devices_utf8"

///|
/// Query supported stream configs for a device.
///
/// Return value is a little-endian binary blob:
/// - i32 status (0 on success, negative errno-style on failure)
/// - u32 record_count
/// - repeated records of 6 u32 values:
///   (sample_format_tag, channels, min_rate, max_rate, buffer_min, buffer_max)
///
/// sample_format_tag:
/// - 1 => I8
/// - 2 => U8
/// - 3 => I16
/// - 4 => U16
/// - 5 => I24
/// - 6 => U24
/// - 7 => I32
/// - 8 => U32
/// - 9 => F32
/// - 10 => F64
/// - 11 => DsdU8
/// - 12 => DsdU16
/// - 13 => DsdU32
///
/// On non-Linux platforms this returns an empty bytes value.
/// On Linux this always returns at least 8 bytes; on error, `record_count` is 0 and `status` is set.

///|
#owned(device_id_utf8)
extern "C" fn alsa_supported_configs_bin(
  device_id_utf8 : Bytes,
  device_id_len : Int,
  is_input : UInt,
) -> Bytes = "moon_cpal_alsa_supported_configs_bin"

///|
pub fn devices_utf8() -> Bytes {
  alsa_devices_utf8()
}

///|
pub fn supported_configs_bin(id : String, is_input : Bool) -> Bytes {
  if id.length() == 0 {
    return Bytes::make(0, (0 : Int).to_byte())
  }
  let b = @core.string_to_ascii_bytes(id)
  alsa_supported_configs_bin(
    b,
    b.length(),
    if is_input {
      (1 : UInt)
    } else {
      (0 : UInt)
    },
  )
}
