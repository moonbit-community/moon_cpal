///|
/// Platform-level dynamic host/device wrappers.
///
/// This is a small MoonBit analogue of upstream `cpal::platform` dynamic dispatch types.
/// For now, this only wraps:
/// - Null backend (always available)
/// - macOS CoreAudio discovery backend (native only; uses stub on non-native)

///|
pub enum Host {
  Null(@null.Host)
  CoreAudio(@macos.Host)
} derive(Show, Eq)

///|
pub enum Device {
  Null(@null.Device)
  CoreAudio(@macos.Device)
} derive(Show, Eq)

///|
pub fn Host::id(self : Host) -> @moon_cpal.HostId {
  match self {
    Null(_) => @moon_cpal.HostId::Null
    CoreAudio(_) => @moon_cpal.HostId::CoreAudio
  }
}

///|
pub fn available_hosts() -> Array[@moon_cpal.HostId] {
  @moon_cpal.available_hosts()
}

///|
pub fn Host::default_output_device(self : Host) -> Device? {
  match self {
    Null(h) =>
      match h.default_output_device() {
        None => None
        Some(d) => Some(Device::Null(d))
      }
    CoreAudio(h) =>
      match (try? h.default_output_device()) {
        Ok(Some(d)) => Some(Device::CoreAudio(d))
        _ => None
      }
  }
}

///|
pub fn Host::default_input_device(self : Host) -> Device? {
  match self {
    Null(h) =>
      match h.default_input_device() {
        None => None
        Some(d) => Some(Device::Null(d))
      }
    CoreAudio(h) =>
      match (try? h.default_input_device()) {
        Ok(Some(d)) => Some(Device::CoreAudio(d))
        _ => None
      }
  }
}

///|
pub fn Host::devices(self : Host) -> Array[Device] {
  match self {
    Null(h) => h.devices().map(fn(d) { Device::Null(d) })
    CoreAudio(h) =>
      match (try? h.devices()) {
        Ok(ds) => ds.map(fn(d) { Device::CoreAudio(d) })
        Err(_) => []
      }
  }
}

///|
pub fn Device::name(self : Device) -> String {
  match self {
    Null(d) => d.name()
    CoreAudio(d) =>
      match (try? d.name()) {
        Ok(s) => s
        Err(_) => ""
      }
  }
}

///|
pub fn Device::supported_output_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  match self {
    Null(d) => d.supported_output_configs()
    CoreAudio(d) =>
      match (try? d.supported_output_configs()) {
        Ok(xs) => xs
        Err(_) => []
      }
  }
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  match self {
    Null(d) => d.supported_input_configs()
    CoreAudio(d) =>
      match (try? d.supported_input_configs()) {
        Ok(xs) => xs
        Err(_) => []
      }
  }
}

///|
pub fn Device::try_default_output_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig? {
  match self {
    Null(d) =>
      match (try? d.default_output_config()) {
        Ok(cfg) => Some(cfg)
        Err(_) => None
      }
    CoreAudio(d) =>
      match (try? d.default_output_config()) {
        Ok(cfg) => Some(cfg)
        Err(_) => None
      }
  }
}

///|
pub fn Device::try_default_input_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig? {
  match self {
    Null(d) =>
      match (try? d.default_input_config()) {
        Ok(cfg) => Some(cfg)
        Err(_) => None
      }
    CoreAudio(d) =>
      match (try? d.default_input_config()) {
        Ok(cfg) => Some(cfg)
        Err(_) => None
      }
  }
}
