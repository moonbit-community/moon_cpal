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
