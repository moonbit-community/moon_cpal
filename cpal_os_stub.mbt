///|
/// OS detection stub for non-native targets.

///|
pub enum NativeOs {
  Unknown
  Macos
  Windows
  Linux
} derive(Show, Eq)

///|
pub fn native_os() -> NativeOs {
  NativeOs::Unknown
}
