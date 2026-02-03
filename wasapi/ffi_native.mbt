///|
/// Native FFI hooks for WASAPI (Windows).

///|
extern "C" fn wasapi_devices_utf8() -> Bytes = "moon_cpal_wasapi_devices_utf8"

///|
pub fn devices_utf8() -> Bytes {
  wasapi_devices_utf8()
}
