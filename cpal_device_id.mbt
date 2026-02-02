///|
/// Cross-platform device identifiers (HostId + backend-specific identifier string).
///
/// Ported from upstream `cpal::DeviceId` and its parsing/display behavior.

///|
pub suberror DeviceIdError {
  UnsupportedPlatform
  BackendSpecific(String)
} derive(Show, Eq)

///|
pub struct DeviceId {
  host_id : HostId
  device_id : String
} derive(Show, Eq)

///|
pub fn DeviceId::new(host_id : HostId, device_id : String) -> DeviceId {
  { host_id, device_id }
}

///|
pub fn DeviceId::host_id(self : DeviceId) -> HostId {
  self.host_id
}

///|
pub fn DeviceId::device_id(self : DeviceId) -> String {
  self.device_id
}

///|
pub fn DeviceId::to_string(self : DeviceId) -> String {
  "\{self.host_id.to_string()}:\{self.device_id}"
}

///|
pub fn DeviceId::from_string(s : String) -> DeviceId raise DeviceIdError {
  let parts = Array::new()
  for p in s.split(":") {
    parts.push(p)
  }
  if parts.length() < 2 || parts[0].is_empty() {
    raise DeviceIdError::BackendSpecific(
      "Failed to parse device ID (expected \"host:device_id\")",
    )
  }
  let host_id = match HostId::from_view(parts[0]) {
    Some(h) => h
    None => raise DeviceIdError::UnsupportedPlatform
  }
  let dev = StringBuilder::new()
  for i = 1; i < parts.length(); i = i + 1 {
    if i > 1 {
      dev.write_char(':')
    }
    dev.write_stringview(parts[i])
  }
  if dev.is_empty() {
    raise DeviceIdError::BackendSpecific(
      "Failed to parse device ID (expected \"host:device_id\")",
    )
  }
  DeviceId::new(host_id, dev.to_string())
}
