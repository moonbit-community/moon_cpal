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
fn default_device() -> Device {
  { id: "default" }
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
    if out.length() == 0 {
      [default_device()]
    } else {
      out
    }
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Windows {
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Windows {
    Some(default_device())
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
pub fn Device::description(
  _self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
  let name = Device::name(_self)
  if name.length() == 0 {
    raise @moon_cpal.device_name_error_backend_specific(
      "wasapi device description: empty name",
    )
  }
  let has_in = _self.supported_input_configs().length() > 0
  let has_out = _self.supported_output_configs().length() > 0
  let direction = if has_in && has_out {
    @moon_cpal.DeviceDirection::duplex()
  } else if has_in {
    @moon_cpal.DeviceDirection::input()
  } else if has_out {
    @moon_cpal.DeviceDirection::output()
  } else {
    @moon_cpal.DeviceDirection::unknown()
  }
  @moon_cpal.DeviceDescription::new(
    name,
    driver=Some("WASAPI"),
    direction=direction,
    address=Some(_self.id),
  )
}

///|
pub fn Device::id(
  _self : Device,
) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::Wasapi, _self.id)
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    return []
  }
  match default_config_u32(_self.id, true) {
    None => {
      // Fallback to conservative stub ranges if query fails.
      let buf = @moon_cpal.SupportedBufferSize::Range(min=64, max=2048)
      [
        @moon_cpal.SupportedStreamConfigRange::new(
          2,
          8000,
          192000,
          buf,
          @moon_cpal.SampleFormat::F32,
        ),
        @moon_cpal.SupportedStreamConfigRange::new(
          2,
          8000,
          192000,
          buf,
          @moon_cpal.SampleFormat::I16,
        ),
      ]
    }
    Some((ch, sr, fmt_tag)) => {
      let fmt = match fmt_tag {
        1 => @moon_cpal.SampleFormat::F32
        2 => @moon_cpal.SampleFormat::I16
        _ => @moon_cpal.SampleFormat::F32
      }
      [
        @moon_cpal.SupportedStreamConfigRange::new(
          ch.reinterpret_as_int(),
          sr.reinterpret_as_int(),
          sr.reinterpret_as_int(),
          @moon_cpal.SupportedBufferSize::Unknown,
          fmt,
        ),
      ]
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
  match default_config_u32(_self.id, false) {
    None => {
      let buf = @moon_cpal.SupportedBufferSize::Range(min=64, max=2048)
      [
        @moon_cpal.SupportedStreamConfigRange::new(
          2,
          8000,
          192000,
          buf,
          @moon_cpal.SampleFormat::F32,
        ),
        @moon_cpal.SupportedStreamConfigRange::new(
          2,
          8000,
          192000,
          buf,
          @moon_cpal.SampleFormat::I16,
        ),
      ]
    }
    Some((ch, sr, fmt_tag)) => {
      let fmt = match fmt_tag {
        1 => @moon_cpal.SampleFormat::F32
        2 => @moon_cpal.SampleFormat::I16
        _ => @moon_cpal.SampleFormat::F32
      }
      [
        @moon_cpal.SupportedStreamConfigRange::new(
          ch.reinterpret_as_int(),
          sr.reinterpret_as_int(),
          sr.reinterpret_as_int(),
          @moon_cpal.SupportedBufferSize::Unknown,
          fmt,
        ),
      ]
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
  match default_config_u32(_self.id, true) {
    None =>
      raise @moon_cpal.default_stream_config_error_backend_specific(
        "wasapi default_input_config: query failed",
      )
    Some((ch, sr, fmt_tag)) => {
      let fmt = match fmt_tag {
        1 => @moon_cpal.SampleFormat::F32
        2 => @moon_cpal.SampleFormat::I16
        _ => @moon_cpal.SampleFormat::F32
      }
      @moon_cpal.SupportedStreamConfig::new(
        ch.reinterpret_as_int(),
        sr.reinterpret_as_int(),
        @moon_cpal.SupportedBufferSize::Unknown,
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
  match default_config_u32(_self.id, false) {
    None =>
      raise @moon_cpal.default_stream_config_error_backend_specific(
        "wasapi default_output_config: query failed",
      )
    Some((ch, sr, fmt_tag)) => {
      let fmt = match fmt_tag {
        1 => @moon_cpal.SampleFormat::F32
        2 => @moon_cpal.SampleFormat::I16
        _ => @moon_cpal.SampleFormat::F32
      }
      @moon_cpal.SupportedStreamConfig::new(
        ch.reinterpret_as_int(),
        sr.reinterpret_as_int(),
        @moon_cpal.SupportedBufferSize::Unknown,
        fmt,
      )
    }
  }
}
