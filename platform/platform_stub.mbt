///|
pub fn default_host() -> Host {
  Host::Null(@null.default_host())
}

///|
pub fn host_from_id(id : @moon_cpal.HostId) -> Host? {
  match id {
    Null => Some(Host::Null(@null.default_host()))
    _ => None
  }
}
