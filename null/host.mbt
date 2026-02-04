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
  [Device::new()]
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  Some(Device::new())
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  Some(Device::new())
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
pub fn Device::id(_self : Device) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::Null, "null")
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  // A synthetic set of common ranges, useful for tests and for code paths that want
  // a cross-platform "always available" host.
  let buf = @moon_cpal.SupportedBufferSize::Range(min=64, max=2048)
  let min_sr = 8000
  let max_sr = 192000
  let chans = [1, 2]
  let fmts = [
    @moon_cpal.SampleFormat::F32,
    @moon_cpal.SampleFormat::I16,
    @moon_cpal.SampleFormat::U16,
    @moon_cpal.SampleFormat::U8,
  ]
  let out : Array[@moon_cpal.SupportedStreamConfigRange] = []
  for ch in chans {
    for fmt in fmts {
      out.push(
        @moon_cpal.SupportedStreamConfigRange::new(ch, min_sr, max_sr, buf, fmt),
      )
    }
  }
  out
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  Device::supported_input_configs(_self)
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig {
  @moon_cpal.SupportedStreamConfig::new(
    2,
    48000,
    @moon_cpal.SupportedBufferSize::Range(min=64, max=2048),
    @moon_cpal.SampleFormat::F32,
  )
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig {
  @moon_cpal.SupportedStreamConfig::new(
    2,
    48000,
    @moon_cpal.SupportedBufferSize::Range(min=64, max=2048),
    @moon_cpal.SampleFormat::F32,
  )
}
