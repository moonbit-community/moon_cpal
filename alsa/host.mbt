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
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    match Host::devices(_self).get(0) {
      None => Some(default_device())
      Some(d) => Some(d)
    }
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    match Host::devices(_self).get(0) {
      None => Some(default_device())
      Some(d) => Some(d)
    }
  } else {
    None
  }
}

///|
pub fn Device::name(_self : Device) -> String {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
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
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
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

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
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

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise @moon_cpal.default_stream_config_error_backend_specific(
      "alsa default_input_config: not available on this OS",
    )
  }
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
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise @moon_cpal.default_stream_config_error_backend_specific(
      "alsa default_output_config: not available on this OS",
    )
  }
  @moon_cpal.SupportedStreamConfig::new(
    2,
    48000,
    @moon_cpal.SupportedBufferSize::Range(min=64, max=2048),
    @moon_cpal.SampleFormat::F32,
  )
}
