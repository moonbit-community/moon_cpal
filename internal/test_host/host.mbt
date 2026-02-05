///|
/// Internal deterministic test backend.
///
/// This backend is used only for unit tests that validate callback ordering and timing semantics
/// without requiring real audio devices.

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
  "test_host"
}

///|
pub fn Device::description(_self : Device) -> @moon_cpal.DeviceDescription {
  @moon_cpal.DeviceDescription::new(
    "Test Device",
    driver=Some("TestHost"),
    device_type=@moon_cpal.DeviceType::virtual_(),
    interface_type=@moon_cpal.InterfaceType::virtual_(),
    direction=@moon_cpal.DeviceDirection::unknown(),
  )
}

///|
pub fn Device::id(_self : Device) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::Null, "test_host")
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
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
  Device::default_input_config(_self)
}
