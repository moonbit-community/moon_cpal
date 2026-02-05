///|
/// Hosts available on the native target.
pub fn available_hosts() -> Array[HostId] {
  // This list is OS-dependent and mirrors the platform layer's runtime availability filtering.
  match native_os() {
    NativeOs::Macos => [CoreAudio]
    // Match upstream ordering: JACK before ALSA.
    NativeOs::Linux => [Jack, Alsa]
    NativeOs::Windows => [Wasapi]
    // Match upstream: Null exists as a fallback host, but is not "available".
    NativeOs::Unknown => []
  }
}
