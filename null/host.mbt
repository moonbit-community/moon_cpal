///|
/// Null host backend.
///
/// This backend is always available and is useful for running cross-platform tests and
/// building code paths where no real audio I/O is desired.

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  _unit : Unit
} derive(Show, Eq)

///|
pub fn Device::new() -> Device {
  { _unit: () }
}

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] {
  []
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  None
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  None
}

///|
pub fn Device::name(_self : Device) -> String {
  "null"
}

///|
pub fn Device::description(
  _self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
  let name = Device::name(_self)
  if name.length() == 0 {
    raise @moon_cpal.device_name_error_backend_specific(
      "null device description: empty name",
    )
  }
  @moon_cpal.DeviceDescription::new(
    name,
    driver=Some("Null"),
    device_type=@moon_cpal.DeviceType::virtual_(),
    interface_type=@moon_cpal.InterfaceType::virtual_(),
    direction=@moon_cpal.DeviceDirection::unknown(),
  )
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  []
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  []
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  raise @moon_cpal.default_stream_config_error_stream_type_not_supported()
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  raise @moon_cpal.default_stream_config_error_stream_type_not_supported()
}
