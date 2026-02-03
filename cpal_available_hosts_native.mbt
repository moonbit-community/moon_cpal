///|
/// Hosts available on the native target.
pub fn available_hosts() -> Array[HostId] {
  // This list is OS-dependent.
  match native_os() {
    NativeOs::Macos => [CoreAudio, Null]
    NativeOs::Linux => [Alsa, Null]
    NativeOs::Windows => [Wasapi, Null]
    NativeOs::Unknown => [Null]
  }
}
