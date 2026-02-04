///|
/// WASAPI backend (Windows).
///
/// This backend provides device enumeration, default/supported configs (best-effort), and
/// real stream I/O via a native C implementation (callback-thread model).

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
pub fn Host::devices(_self : Host) -> Array[Device] {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Windows {
    let bytes = devices_utf8()
    let s = @moon_cpal.utf8_bytes_to_string(bytes, bytes.length())
    let out : Array[Device] = []
    for v in s[:].split("\n"[:]) {
      let id = v.trim().to_string()
      if id.length() > 0 {
        out.push({ id, })
      }
    }
    if out.length() > 0 {
      return out
    }
    // Best-effort fallback: include the default endpoint id if enumeration yielded nothing.
    match default_device_id_utf8(false) {
      None => []
      Some(id) => [{ id, }]
    }
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Windows {
    match default_device_id_utf8(false) {
      None => None
      Some(id) => Some({ id, })
    }
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Windows {
    match default_device_id_utf8(true) {
      None => None
      Some(id) => Some({ id, })
    }
  } else {
    None
  }
}

///|
pub fn Device::name(_self : Device) -> String {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    return _self.id
  }
  match device_name_utf8(_self.id) {
    None => _self.id
    Some(s) => s
  }
}

///|
fn wasapi_ascii_upper(s : String) -> String {
  let b = Bytes::makei(s.length(), fn(i) {
    let cu = s.code_unit_at(i).to_int()
    if cu >= 97 && cu <= 122 { // a-z
      (cu - 32).to_byte()
    } else {
      cu.to_byte()
    }
  })
  @moon_cpal.utf8_bytes_to_string(b, b.length())
}

///|
fn wasapi_interface_type_from_enumerator(
  enumerator_name : String,
) -> @moon_cpal.InterfaceType? {
  match wasapi_ascii_upper(enumerator_name.trim().to_string()) {
    "HDAUDIO" => Some(@moon_cpal.InterfaceType::built_in())
    "USB" => Some(@moon_cpal.InterfaceType::usb())
    "BTHENUM" => Some(@moon_cpal.InterfaceType::bluetooth())
    "MMDEVAPI" | "SW" => Some(@moon_cpal.InterfaceType::virtual_())
    _ => None
  }
}

///|
fn wasapi_interface_type_from_jack_subtype(
  jack_subtype : String,
) -> @moon_cpal.InterfaceType? {
  match wasapi_ascii_upper(jack_subtype.trim().to_string()) {
    "{D9E55EA0-0C89-4692-84FF-EB3C4B0D172F}" =>
      Some(@moon_cpal.InterfaceType::hdmi())
    "{E47E4031-3EA6-418D-8F9B-B73843CCB2AD}" =>
      Some(@moon_cpal.InterfaceType::display_port())
    "{DFF21CE1-F70F-11D0-B917-00A0C9223196}" =>
      Some(@moon_cpal.InterfaceType::spdif())
    _ => None
  }
}

///|
fn wasapi_types_from_form_factor(
  form_factor : UInt,
) -> (@moon_cpal.DeviceType, @moon_cpal.InterfaceType?) {
  match form_factor.reinterpret_as_int() {
    // RemoteNetworkDevice
    0 =>
      (
        @moon_cpal.DeviceType::unknown(),
        Some(@moon_cpal.InterfaceType::network()),
      )
    // Speakers
    1 => (@moon_cpal.DeviceType::speaker(), None)
    // LineLevel
    2 =>
      (@moon_cpal.DeviceType::unknown(), Some(@moon_cpal.InterfaceType::line()))
    // Headphones
    3 => (@moon_cpal.DeviceType::headphones(), None)
    // Microphone
    4 => (@moon_cpal.DeviceType::microphone(), None)
    // Headset
    5 => (@moon_cpal.DeviceType::headset(), None)
    // Handset
    6 => (@moon_cpal.DeviceType::handset(), None)
    // UnknownDigitalPassthrough
    7 => (@moon_cpal.DeviceType::unknown(), None)
    // SPDIF
    8 =>
      (
        @moon_cpal.DeviceType::unknown(),
        Some(@moon_cpal.InterfaceType::spdif()),
      )
    // DigitalAudioDisplayDevice
    9 =>
      (@moon_cpal.DeviceType::unknown(), Some(@moon_cpal.InterfaceType::hdmi()))
    _ => (@moon_cpal.DeviceType::unknown(), None)
  }
}

///|
pub fn Device::description(
  _self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
  let dev_desc = device_property_utf8(_self.id, 2)
  let friendly = device_property_utf8(_self.id, 6)
  let name = match dev_desc {
    Some(s) if s.trim().length() > 0 => s
    _ =>
      match friendly {
        Some(s) if s.trim().length() > 0 => s
        _ => Device::name(_self)
      }
  }
  if name.length() == 0 {
    raise @moon_cpal.device_name_error_backend_specific(
      "wasapi device description: empty name",
    )
  }
  let direction = match data_flow_tag(_self.id) {
    Some(1) => @moon_cpal.DeviceDirection::input()
    Some(2) => @moon_cpal.DeviceDirection::output()
    _ => @moon_cpal.DeviceDirection::unknown()
  }
  let manufacturer = device_property_utf8(_self.id, 1)
  let interface_name = device_property_utf8(_self.id, 3)
  let enumerator_name = device_property_utf8(_self.id, 4)
  let jack_subtype = device_property_utf8(_self.id, 5)
  let (device_type, interface_type_seed) = match
    device_form_factor_u32(_self.id) {
    Some(ff) => wasapi_types_from_form_factor(ff)
    None => (@moon_cpal.DeviceType::unknown(), None)
  }
  let mut interface_type_opt = interface_type_seed
  match enumerator_name {
    Some(s) =>
      match wasapi_interface_type_from_enumerator(s) {
        Some(it) => interface_type_opt = Some(it)
        None => ()
      }
    None => ()
  }
  match jack_subtype {
    Some(s) =>
      match wasapi_interface_type_from_jack_subtype(s) {
        Some(it) => interface_type_opt = Some(it)
        None => ()
      }
    None => ()
  }
  let interface_type = match interface_type_opt {
    None => @moon_cpal.InterfaceType::unknown()
    Some(it) => it
  }
  let extended : Array[String] = ["endpoint_id=\{_self.id}"]
  match dev_desc {
    Some(s) => extended.push("device_desc=\{s}")
    None => ()
  }
  match friendly {
    Some(s) if s != name => extended.push("friendly_name=\{s}")
    _ => ()
  }
  match enumerator_name {
    Some(s) => extended.push("enumerator=\{s}")
    None => ()
  }
  match jack_subtype {
    Some(s) => extended.push("jack_subtype=\{s}")
    None => ()
  }
  @moon_cpal.DeviceDescription::new(
    name,
    manufacturer~,
    driver=match interface_name {
      Some(s) if s.trim().length() > 0 => Some(s)
      _ => Some("WASAPI")
    },
    device_type~,
    interface_type~,
    direction~,
    address=Some(_self.id),
    extended~,
  )
}

///|
pub fn Device::id(_self : Device) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::Wasapi, _self.id)
}

///|
fn clamp_u32_to_frame_count(u : UInt) -> Int {
  let lim = (2147483647 : Int).reinterpret_as_uint()
  if u <= lim {
    u.reinterpret_as_int()
  } else {
    2147483647
  }
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    return []
  }
  match data_flow_tag(_self.id) {
    Some(2) => return []
    _ => ()
  }
  match supported_configs_u32(_self.id, true) {
    None =>
      match default_config_ex_u32(_self.id, true) {
        None => []
        Some((ch, sr, fmt_tag, bmin, bmax)) => {
          let fmt = match fmt_tag {
            1 => @moon_cpal.SampleFormat::F32
            2 => @moon_cpal.SampleFormat::I16
            _ => @moon_cpal.SampleFormat::F32
          }
          let buf = @moon_cpal.SupportedBufferSize::Range(
            min=clamp_u32_to_frame_count(bmin),
            max=clamp_u32_to_frame_count(bmax),
          )
          [
            @moon_cpal.SupportedStreamConfigRange::new(
              ch.reinterpret_as_int(),
              sr.reinterpret_as_int(),
              sr.reinterpret_as_int(),
              buf,
              fmt,
            ),
          ]
        }
      }
    Some((n, buf)) => {
      let out : Array[@moon_cpal.SupportedStreamConfigRange] = []
      let count = if n < 0 { 0 } else { n }
      let max = if count > 64 { 64 } else { count }
      for i in 0..<max {
        let off = i * 5
        let ch = buf[off + 0]
        let sr = buf[off + 1]
        let fmt_tag = buf[off + 2]
        let bmin = buf[off + 3]
        let bmax = buf[off + 4]
        let fmt = match fmt_tag {
          1 => @moon_cpal.SampleFormat::F32
          2 => @moon_cpal.SampleFormat::I16
          _ => @moon_cpal.SampleFormat::F32
        }
        let b = @moon_cpal.SupportedBufferSize::Range(
          min=clamp_u32_to_frame_count(bmin),
          max=clamp_u32_to_frame_count(bmax),
        )
        out.push(
          @moon_cpal.SupportedStreamConfigRange::new(
            ch.reinterpret_as_int(),
            sr.reinterpret_as_int(),
            sr.reinterpret_as_int(),
            b,
            fmt,
          ),
        )
      }
      out
    }
  }
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    return []
  }
  match data_flow_tag(_self.id) {
    Some(1) => return []
    _ => ()
  }
  match supported_configs_u32(_self.id, false) {
    None =>
      match default_config_ex_u32(_self.id, false) {
        None => []
        Some((ch, sr, fmt_tag, bmin, bmax)) => {
          let fmt = match fmt_tag {
            1 => @moon_cpal.SampleFormat::F32
            2 => @moon_cpal.SampleFormat::I16
            _ => @moon_cpal.SampleFormat::F32
          }
          let buf = @moon_cpal.SupportedBufferSize::Range(
            min=clamp_u32_to_frame_count(bmin),
            max=clamp_u32_to_frame_count(bmax),
          )
          [
            @moon_cpal.SupportedStreamConfigRange::new(
              ch.reinterpret_as_int(),
              sr.reinterpret_as_int(),
              sr.reinterpret_as_int(),
              buf,
              fmt,
            ),
          ]
        }
      }
    Some((n, buf)) => {
      let out : Array[@moon_cpal.SupportedStreamConfigRange] = []
      let count = if n < 0 { 0 } else { n }
      let max = if count > 64 { 64 } else { count }
      for i in 0..<max {
        let off = i * 5
        let ch = buf[off + 0]
        let sr = buf[off + 1]
        let fmt_tag = buf[off + 2]
        let bmin = buf[off + 3]
        let bmax = buf[off + 4]
        let fmt = match fmt_tag {
          1 => @moon_cpal.SampleFormat::F32
          2 => @moon_cpal.SampleFormat::I16
          _ => @moon_cpal.SampleFormat::F32
        }
        let b = @moon_cpal.SupportedBufferSize::Range(
          min=clamp_u32_to_frame_count(bmin),
          max=clamp_u32_to_frame_count(bmax),
        )
        out.push(
          @moon_cpal.SupportedStreamConfigRange::new(
            ch.reinterpret_as_int(),
            sr.reinterpret_as_int(),
            sr.reinterpret_as_int(),
            b,
            fmt,
          ),
        )
      }
      out
    }
  }
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    raise @moon_cpal.default_stream_config_error_backend_specific(
      "wasapi default_input_config: not available on this OS",
    )
  }
  match data_flow_tag(_self.id) {
    Some(2) =>
      raise @moon_cpal.default_stream_config_error_stream_type_not_supported()
    _ => ()
  }
  match default_config_ex_u32(_self.id, true) {
    None =>
      raise @moon_cpal.default_stream_config_error_backend_specific(
        "wasapi default_input_config: query failed",
      )
    Some((ch, sr, fmt_tag, bmin, bmax)) => {
      let fmt = match fmt_tag {
        1 => @moon_cpal.SampleFormat::F32
        2 => @moon_cpal.SampleFormat::I16
        _ => @moon_cpal.SampleFormat::F32
      }
      @moon_cpal.SupportedStreamConfig::new(
        ch.reinterpret_as_int(),
        sr.reinterpret_as_int(),
        @moon_cpal.SupportedBufferSize::Range(
          min=clamp_u32_to_frame_count(bmin),
          max=clamp_u32_to_frame_count(bmax),
        ),
        fmt,
      )
    }
  }
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    raise @moon_cpal.default_stream_config_error_backend_specific(
      "wasapi default_output_config: not available on this OS",
    )
  }
  match data_flow_tag(_self.id) {
    Some(1) =>
      raise @moon_cpal.default_stream_config_error_stream_type_not_supported()
    _ => ()
  }
  match default_config_ex_u32(_self.id, false) {
    None =>
      raise @moon_cpal.default_stream_config_error_backend_specific(
        "wasapi default_output_config: query failed",
      )
    Some((ch, sr, fmt_tag, bmin, bmax)) => {
      let fmt = match fmt_tag {
        1 => @moon_cpal.SampleFormat::F32
        2 => @moon_cpal.SampleFormat::I16
        _ => @moon_cpal.SampleFormat::F32
      }
      @moon_cpal.SupportedStreamConfig::new(
        ch.reinterpret_as_int(),
        sr.reinterpret_as_int(),
        @moon_cpal.SupportedBufferSize::Range(
          min=clamp_u32_to_frame_count(bmin),
          max=clamp_u32_to_frame_count(bmax),
        ),
        fmt,
      )
    }
  }
}
