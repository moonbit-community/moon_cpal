///|
fn main {
  // Keep imports "used" on non-native targets to avoid warnings.
  ignore(@wasapi.default_host())
  ignore(@moon_cpal.native_os())
  println("wasapi_stream_smoke: native-only")
}
