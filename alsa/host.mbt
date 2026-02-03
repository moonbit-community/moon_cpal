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
  id : String
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
fn default_device() -> Device {
  // Mirrors typical ALSA "default" PCM.
  { id: "default" }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    [default_device()]
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Device::name(_self : Device) -> String {
  _self.id
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
