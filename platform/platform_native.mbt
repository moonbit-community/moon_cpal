///|
pub fn default_host() -> Host {
  Host::CoreAudio(@macos.default_host())
}

///|
pub fn host_from_id(id : @moon_cpal.HostId) -> Host? {
  match id {
    CoreAudio => Some(Host::CoreAudio(@macos.default_host()))
    Null => Some(Host::Null(@null.default_host()))
    _ => None
  }
}
