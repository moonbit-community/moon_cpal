///|
/// CPAL-like host/device surface for macOS (CoreAudio).
///
/// Includes device enumeration, config queries and native stream I/O (AudioQueue) with
/// MoonBit callback bridging.
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
pub fn Host::default_output_device(_self : Host) -> Device? {
  match default_output_device_id() {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  match default_input_device_id() {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
pub fn Device::name(self : Device) -> String raise CoreAudioError {
  device_name(self.id)
}

///|
pub fn Device::id(self : Device) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::CoreAudio, self.id.to_string())
}

///|
fn coreaudio_interface_type_from_tag(tag : Int) -> @moon_cpal.InterfaceType {
  match tag {
    1 => @moon_cpal.InterfaceType::built_in()
    2 => @moon_cpal.InterfaceType::usb()
    3 => @moon_cpal.InterfaceType::bluetooth()
    4 => @moon_cpal.InterfaceType::pci()
    5 => @moon_cpal.InterfaceType::fire_wire()
    6 => @moon_cpal.InterfaceType::thunderbolt()
    7 => @moon_cpal.InterfaceType::hdmi()
    10 => @moon_cpal.InterfaceType::network()
    11 => @moon_cpal.InterfaceType::virtual_()
    12 => @moon_cpal.InterfaceType::display_port()
    13 => @moon_cpal.InterfaceType::aggregate()
    _ => @moon_cpal.InterfaceType::unknown()
  }
}

///|
pub fn Device::description(
  self : Device,
) -> @moon_cpal.DeviceDescription raise CoreAudioError {
  let name = device_name(self.id)
  let in_ch = ca_input_channel_count(self.id)
  let out_ch = ca_output_channel_count(self.id)
  let has_in = in_ch > 0
  let has_out = out_ch > 0
  let direction = if has_in && has_out {
    @moon_cpal.DeviceDirection::duplex()
  } else if has_in {
    @moon_cpal.DeviceDirection::input()
  } else if has_out {
    @moon_cpal.DeviceDirection::output()
  } else {
    @moon_cpal.DeviceDirection::unknown()
  }
  let device_type = match direction {
    @moon_cpal.DeviceDirection::Input => @moon_cpal.DeviceType::microphone()
    @moon_cpal.DeviceDirection::Output => @moon_cpal.DeviceType::speaker()
    _ => @moon_cpal.DeviceType::unknown()
  }
  let manufacturer = device_manufacturer(self.id)
  let uid = device_uid(self.id)
  let interface_type = coreaudio_interface_type_from_tag(
    device_interface_type_tag(self.id),
  )
  let transport = device_transport_type_u32(self.id)
  let address = match uid {
    Some(s) if s.trim().length() > 0 => Some(s)
    _ => Some(self.id.to_string())
  }
  let extended : Array[String] = ["AudioDeviceID=\{self.id}"]
  match uid {
    Some(s) if s.trim().length() > 0 => extended.push("uid=\{s}")
    _ => ()
  }
  if transport != 0 {
    extended.push("transport_type_u32=\{transport}")
  }
  @moon_cpal.DeviceDescription::new(
    name,
    manufacturer~,
    driver=Some("CoreAudio"),
    device_type~,
    interface_type~,
    direction~,
    address~,
    extended~,
  )
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
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  default_input_config(self.id)
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  default_output_config(self.id)
}
