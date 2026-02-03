///|
/// Best-effort OS detection for native builds.
///
/// Moon's conditional compilation in `moon.pkg.json` can distinguish backend/mode but not OS,
/// so we expose a tiny native helper implemented in C.

///|
pub enum NativeOs {
  Unknown
  Macos
  Windows
  Linux
} derive(Show, Eq)

///|
extern "C" fn native_os_tag() -> Int = "moon_cpal_os_tag"

///|
pub fn native_os() -> NativeOs {
  match native_os_tag() {
    1 => NativeOs::Macos
    2 => NativeOs::Windows
    3 => NativeOs::Linux
    _ => NativeOs::Unknown
  }
}
