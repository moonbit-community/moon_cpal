///|
/// Minimal cpal-like host/device surface for macOS.
///
/// The goal is to make it easy to build higher-level APIs later while keeping the
/// current implementation limited to deterministic device discovery.
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  id : DeviceId
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] raise CoreAudioError {
  device_ids().map(fn(id) { { id, } })
}

///|
pub fn Host::default_output_device(
  _self : Host,
) -> Device? raise CoreAudioError {
  match default_output_device_id() {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? raise CoreAudioError {
  match default_input_device_id() {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
pub fn Device::id(self : Device) -> DeviceId {
  self.id
}

///|
pub fn Device::name(self : Device) -> String raise CoreAudioError {
  device_name(self.id)
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise CoreAudioError {
  supported_input_configs(self.id)
}

///|
pub fn Device::supported_output_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise CoreAudioError {
  supported_output_configs(self.id)
}

///|
pub fn Device::default_input_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise DefaultStreamConfigError {
  default_input_config(self.id)
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise DefaultStreamConfigError {
  default_output_config(self.id)
}
