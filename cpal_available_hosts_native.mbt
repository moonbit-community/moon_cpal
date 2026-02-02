///|
/// Hosts available on the native target.
pub fn available_hosts() -> Array[HostId] {
  // Current implementation: CoreAudio device discovery (macOS) + always-available Null host.
  [CoreAudio, Null]
}
