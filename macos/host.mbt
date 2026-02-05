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
pub fn Device::id(self : Device) -> @core.DeviceId {
  match device_uid(self.id) {
    Some(uid) if uid.trim().length() > 0 =>
      @core.DeviceId::new(@core.HostId::CoreAudio, uid)
    _ => @core.DeviceId::new(@core.HostId::CoreAudio, self.id.to_string())
  }
}

///|
fn coreaudio_interface_type_from_tag(tag : Int) -> @core.InterfaceType {
  match tag {
    1 => @core.InterfaceType::built_in()
    2 => @core.InterfaceType::usb()
    3 => @core.InterfaceType::bluetooth()
    4 => @core.InterfaceType::pci()
    5 => @core.InterfaceType::fire_wire()
    6 => @core.InterfaceType::thunderbolt()
    7 => @core.InterfaceType::hdmi()
    10 => @core.InterfaceType::network()
    11 => @core.InterfaceType::virtual_()
    12 => @core.InterfaceType::display_port()
    13 => @core.InterfaceType::aggregate()
    _ => @core.InterfaceType::unknown()
  }
}

///|
pub fn Device::description(
  self : Device,
) -> @core.DeviceDescription raise CoreAudioError {
  let name = device_name(self.id)
  let in_ch = ca_input_channel_count(self.id)
  let out_ch = ca_output_channel_count(self.id)
  let has_in = in_ch > 0
  let has_out = out_ch > 0
  let direction = if has_in && has_out {
    @core.DeviceDirection::duplex()
  } else if has_in {
    @core.DeviceDirection::input()
  } else if has_out {
    @core.DeviceDirection::output()
  } else {
    @core.DeviceDirection::unknown()
  }
  let device_type = match direction {
    @core.DeviceDirection::Input => @core.DeviceType::microphone()
    @core.DeviceDirection::Output => @core.DeviceType::speaker()
    _ => @core.DeviceType::unknown()
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
  @core.DeviceDescription::new(
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
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  supported_input_configs(self.id)
}

///|
pub fn Device::supported_output_configs(
  self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  supported_output_configs(self.id)
}

///|
pub fn Device::default_input_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  default_input_config(self.id)
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  default_output_config(self.id)
}
