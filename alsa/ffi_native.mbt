///|
/// Native FFI hooks for ALSA.
///
/// Note: this is best-effort and currently backed by `/proc/asound/pcm` parsing in C.

///|
extern "C" fn alsa_devices_utf8() -> Bytes = "moon_cpal_alsa_devices_utf8"

///|
pub fn devices_utf8() -> Bytes {
  alsa_devices_utf8()
}
