///|
fn main {
  // Keep imports "used" on non-native targets to avoid warnings.
  ignore(@alsa.default_host())
  ignore(@moon_cpal.native_os())
  println("alsa_stream_smoke: native-only")
}
