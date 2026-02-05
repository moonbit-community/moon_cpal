///|
/// Hosts available on the native target.
pub fn available_hosts() -> Array[HostId] {
  // This list is OS-dependent.
  match native_os() {
    NativeOs::Macos => [CoreAudio]
    NativeOs::Linux => [Alsa, Jack]
    NativeOs::Windows => [Wasapi]
    NativeOs::Unknown => [Null]
  }
}
