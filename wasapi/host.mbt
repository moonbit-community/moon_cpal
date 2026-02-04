///|
/// WASAPI backend (Windows).
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
