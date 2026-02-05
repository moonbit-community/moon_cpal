///|
/// Native FFI hooks for ALSA.
///
/// Note: on Linux, device enumeration prefers libasound (`snd_device_name_hint`) and falls back
/// to `/proc/asound/pcm` parsing.

///|
extern "C" fn alsa_devices_utf8() -> Bytes = "moon_cpal_alsa_devices_utf8"

///|
#owned(device_id_utf8)
extern "C" fn alsa_device_name_utf8_len(
  device_id_utf8 : Bytes,
  device_id_len : Int,
) -> Int = "moon_cpal_alsa_device_name_utf8_len"

///|
#borrow(out)
#owned(device_id_utf8)
extern "C" fn alsa_device_name_utf8(
  device_id_utf8 : Bytes,
  device_id_len : Int,
  out : Bytes,
  out_len : Int,
) -> Int = "moon_cpal_alsa_device_name_utf8"

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
/// - 1 => F32
/// - 2 => I16
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
pub fn device_name_utf8(id : String) -> String? {
  if id.length() == 0 {
    return None
  }
  let b1 = @moon_cpal.string_to_utf8_bytes(id)
  let id_len = b1.length()
  let n = alsa_device_name_utf8_len(b1, id_len)
  if n <= 0 {
    return None
  }
  let out = Bytes::make(n, (0 : Int).to_byte())
  let b2 = @moon_cpal.string_to_utf8_bytes(id)
  let used = alsa_device_name_utf8(b2, id_len, out, out.length())
  if used <= 0 {
    return None
  }
  let need = if used > out.length() { out.length() } else { used }
  Some(@moon_cpal.utf8_bytes_to_string(out, need))
}

///|
pub fn supported_configs_bin(id : String, is_input : Bool) -> Bytes {
  if id.length() == 0 {
    return Bytes::make(0, (0 : Int).to_byte())
  }
  let b = @moon_cpal.string_to_ascii_bytes(id)
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
