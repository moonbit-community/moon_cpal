///|
/// Native FFI hooks for JACK.
///
/// For config queries we connect a short-lived JACK client to read the server sample rate and
/// buffer size. On non-Linux platforms this returns empty bytes.

///|
extern "C" fn jack_default_config_bin() -> Bytes = "moon_cpal_jack_default_config_bin"

///|
fn u32_le_to_int(b : Bytes, off : Int) -> Int {
  if off + 4 > b.length() {
    return 0
  }
  let b0 = b[off].to_int()
  let b1 = b[off + 1].to_int()
  let b2 = b[off + 2].to_int()
  let b3 = b[off + 3].to_int()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
pub fn default_server_config() -> (Int, Int)? {
  let b = jack_default_config_bin()
  if b.length() < 8 {
    return None
  }
  let sr = u32_le_to_int(b, 0)
  let buf = u32_le_to_int(b, 4)
  if sr <= 0 || buf <= 0 {
    None
  } else {
    Some((sr, buf))
  }
}
