///|
/// Device metadata and description types.
///
/// Ported from upstream `cpal/src/device_description.rs`.

///|
pub enum DeviceType {
  Speaker
  Microphone
  Headphones
  Headset
  Earpiece
  Handset
  HearingAid
  Dock
  Tuner
  Virtual
  Unknown
} derive(Show, Eq)

///|
pub fn DeviceType::speaker() -> DeviceType {
  Speaker
}

///|
pub fn DeviceType::microphone() -> DeviceType {
  Microphone
}

///|
pub fn DeviceType::headphones() -> DeviceType {
  Headphones
}

///|
pub fn DeviceType::headset() -> DeviceType {
  Headset
}

///|
pub fn DeviceType::earpiece() -> DeviceType {
  Earpiece
}

///|
pub fn DeviceType::handset() -> DeviceType {
  Handset
}

///|
pub fn DeviceType::hearing_aid() -> DeviceType {
  HearingAid
}

///|
pub fn DeviceType::dock() -> DeviceType {
  Dock
}

///|
pub fn DeviceType::tuner() -> DeviceType {
  Tuner
}

///|
pub fn DeviceType::virtual_() -> DeviceType {
  Virtual
}

///|
pub fn DeviceType::unknown() -> DeviceType {
  Unknown
}

///|
pub enum InterfaceType {
  BuiltIn
  Usb
  Bluetooth
  Pci
  FireWire
  Thunderbolt
  Hdmi
  Line
  Spdif
  Network
  Virtual
  DisplayPort
  Aggregate
  Unknown
} derive(Show, Eq)

///|
pub fn InterfaceType::built_in() -> InterfaceType {
  BuiltIn
}

///|
pub fn InterfaceType::usb() -> InterfaceType {
  Usb
}

///|
pub fn InterfaceType::bluetooth() -> InterfaceType {
  Bluetooth
}

///|
pub fn InterfaceType::pci() -> InterfaceType {
  Pci
}

///|
pub fn InterfaceType::fire_wire() -> InterfaceType {
  FireWire
}

///|
pub fn InterfaceType::thunderbolt() -> InterfaceType {
  Thunderbolt
}

///|
pub fn InterfaceType::hdmi() -> InterfaceType {
  Hdmi
}

///|
pub fn InterfaceType::line() -> InterfaceType {
  Line
}

///|
pub fn InterfaceType::spdif() -> InterfaceType {
  Spdif
}

///|
pub fn InterfaceType::network() -> InterfaceType {
  Network
}

///|
pub fn InterfaceType::virtual_() -> InterfaceType {
  Virtual
}

///|
pub fn InterfaceType::display_port() -> InterfaceType {
  DisplayPort
}

///|
pub fn InterfaceType::aggregate() -> InterfaceType {
  Aggregate
}

///|
pub fn InterfaceType::unknown() -> InterfaceType {
  Unknown
}

///|
pub enum DeviceDirection {
  Input
  Output
  Duplex
  Unknown
} derive(Show, Eq)

///|
pub fn DeviceDirection::input() -> DeviceDirection {
  Input
}

///|
pub fn DeviceDirection::output() -> DeviceDirection {
  Output
}

///|
pub fn DeviceDirection::duplex() -> DeviceDirection {
  Duplex
}

///|
pub fn DeviceDirection::unknown() -> DeviceDirection {
  Unknown
}

///|
pub struct DeviceDescription {
  name : String
  manufacturer : String?
  driver : String?
  device_type : DeviceType
  interface_type : InterfaceType
  direction : DeviceDirection
  address : String?
  extended : Array[String]
} derive(Show, Eq)

///|
pub fn DeviceDescription::new(
  name : String,
  manufacturer~ : String? = None,
  driver~ : String? = None,
  device_type~ : DeviceType = DeviceType::Unknown,
  interface_type~ : InterfaceType = InterfaceType::Unknown,
  direction~ : DeviceDirection = DeviceDirection::Unknown,
  address~ : String? = None,
  extended~ : Array[String] = [],
) -> DeviceDescription {
  {
    name,
    manufacturer,
    driver,
    device_type,
    interface_type,
    direction,
    address,
    extended,
  }
}

///|
pub fn DeviceDescription::name(self : DeviceDescription) -> String {
  self.name
}

///|
pub fn DeviceDescription::manufacturer(self : DeviceDescription) -> String? {
  self.manufacturer
}

///|
pub fn DeviceDescription::driver(self : DeviceDescription) -> String? {
  self.driver
}

///|
pub fn DeviceDescription::device_type(self : DeviceDescription) -> DeviceType {
  self.device_type
}

///|
pub fn DeviceDescription::interface_type(
  self : DeviceDescription,
) -> InterfaceType {
  self.interface_type
}

///|
pub fn DeviceDescription::direction(self : DeviceDescription) -> DeviceDirection {
  self.direction
}

///|
pub fn DeviceDescription::supports_input(self : DeviceDescription) -> Bool {
  match self.direction {
    Input | Duplex => true
    _ => false
  }
}

///|
pub fn DeviceDescription::supports_output(self : DeviceDescription) -> Bool {
  match self.direction {
    Output | Duplex => true
    _ => false
  }
}

///|
pub fn DeviceDescription::address(self : DeviceDescription) -> String? {
  self.address
}

///|
pub fn DeviceDescription::extended(self : DeviceDescription) -> Array[String] {
  self.extended
}

///|
pub fn DeviceType::to_string(self : DeviceType) -> String {
  match self {
    Speaker => "Speaker"
    Microphone => "Microphone"
    Headphones => "Headphones"
    Headset => "Headset"
    Earpiece => "Earpiece"
    Handset => "Handset"
    HearingAid => "Hearing Aid"
    Dock => "Dock"
    Tuner => "Tuner"
    Virtual => "Virtual"
    Unknown => "Unknown"
  }
}

///|
pub fn InterfaceType::to_string(self : InterfaceType) -> String {
  match self {
    BuiltIn => "Built-in"
    Usb => "USB"
    Bluetooth => "Bluetooth"
    Pci => "PCI"
    FireWire => "FireWire"
    Thunderbolt => "Thunderbolt"
    Hdmi => "HDMI"
    Line => "Line"
    Spdif => "S/PDIF"
    Network => "Network"
    Virtual => "Virtual"
    DisplayPort => "DisplayPort"
    Aggregate => "Aggregate"
    Unknown => "Unknown"
  }
}

///|
pub fn DeviceDirection::to_string(self : DeviceDirection) -> String {
  match self {
    Input => "Input"
    Output => "Output"
    Duplex => "Duplex"
    Unknown => "Unknown"
  }
}

///|
pub fn DeviceDescription::to_string(self : DeviceDescription) -> String {
  let sb = StringBuilder::new()
  sb.write_string(self.name)
  match self.manufacturer {
    None => ()
    Some(m) => sb.write_string(" (\{m})")
  }
  if self.device_type != DeviceType::Unknown {
    sb.write_string(" [\{self.device_type.to_string()}]")
  }
  if self.interface_type != InterfaceType::Unknown {
    sb.write_string(" via \{self.interface_type.to_string()}")
  }
  sb.to_string()
}
