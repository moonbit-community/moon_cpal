///|
/// ALSA backend (Linux).
///
/// This package is currently a stub: it exists so the cross-platform platform wrapper can
/// typecheck on all targets. A real implementation will be added later.

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  _unit : Unit
} derive(Show, Eq)

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
  "alsa"
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
  raise @moon_cpal.default_stream_config_error_backend_specific(
    "alsa default_input_config: unimplemented",
  )
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  raise @moon_cpal.default_stream_config_error_backend_specific(
    "alsa default_output_config: unimplemented",
  )
}
