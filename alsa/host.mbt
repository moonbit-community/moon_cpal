///|
/// ALSA backend (Linux).
///
/// Configuration queries are best-effort and are implemented via libasound `hw_params` probing.

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
      return [default_device()]
    }

    // Try to filter out entries that cannot be opened for either capture or playback.
    // Keep "default" even if probing fails, as it is a stable virtual device id.
    let filtered : Array[Device] = []
    for d in out {
      if d.id == "default" {
        filtered.push(d)
        continue
      }
      let has_out = supported_configs_bin(d.id, false).length() > 0
      let has_in = supported_configs_bin(d.id, true).length() > 0
      if has_out || has_in {
        filtered.push(d)
      }
    }
    if filtered.length() == 0 {
      [default_device()]
    } else {
      filtered
    }
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    let ds = Host::devices(_self)
    // Prefer "default" when it actually supports output.
    for d in ds {
      if d.id == "default" && d.supported_output_configs().length() > 0 {
        return Some(d)
      }
    }
    // Otherwise pick the first device that reports any output configs.
    for d in ds {
      if d.supported_output_configs().length() > 0 {
        return Some(d)
      }
    }
    None
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    let ds = Host::devices(_self)
    for d in ds {
      if d.id == "default" && d.supported_input_configs().length() > 0 {
        return Some(d)
      }
    }
    for d in ds {
      if d.supported_input_configs().length() > 0 {
        return Some(d)
      }
    }
    None
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
pub fn Device::description(
  _self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
  let name = Device::name(_self)
  if name.length() == 0 {
    raise @moon_cpal.device_name_error_backend_specific(
      "alsa device description: empty name",
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
  let device_type = match direction {
    @moon_cpal.DeviceDirection::Input => @moon_cpal.DeviceType::microphone()
    @moon_cpal.DeviceDirection::Output => @moon_cpal.DeviceType::speaker()
    _ => @moon_cpal.DeviceType::unknown()
  }
  @moon_cpal.DeviceDescription::new(
    name,
    driver=Some("ALSA"),
    device_type~,
    interface_type=@moon_cpal.InterfaceType::unknown(),
    direction~,
    address=Some(_self.id),
    extended=["alsa_id=\{_self.id}"],
  )
}

///|
pub fn Device::id(_self : Device) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::Alsa, _self.id)
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
  supported_configs(_self, true)
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
  supported_configs(_self, false)
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
  default_config(_self, true)
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
  default_config(_self, false)
}

///|
fn u32_le_to_int(b : Bytes, off : Int) -> Int {
  if off + 4 > b.length() {
    return 0
  }
  let b0 = b[off].to_int()
  let b1 = b[off + 1].to_int()
  let b2 = b[off + 2].to_int()
  let b3 = b[off + 3].to_int()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn sample_format_from_bin_tag(tag : Int) -> @moon_cpal.SampleFormat? {
  match tag {
    1 => Some(@moon_cpal.SampleFormat::F32)
    2 => Some(@moon_cpal.SampleFormat::I16)
    _ => None
  }
}

///|
fn parse_supported_configs_bin(
  b : Bytes,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if b.length() < 4 {
    return []
  }
  let n = u32_le_to_int(b, 0)
  if n <= 0 {
    return []
  }
  let out : Array[@moon_cpal.SupportedStreamConfigRange] = []
  let mut off = 4
  for _i in 0..<n {
    if off + 24 > b.length() {
      break
    }
    let tag = u32_le_to_int(b, off)
    let ch = u32_le_to_int(b, off + 4)
    let min_sr = u32_le_to_int(b, off + 8)
    let max_sr = u32_le_to_int(b, off + 12)
    let buf_min = u32_le_to_int(b, off + 16)
    let buf_max = u32_le_to_int(b, off + 20)
    off = off + 24
    match sample_format_from_bin_tag(tag) {
      None => ()
      Some(fmt) => {
        let buf = @moon_cpal.SupportedBufferSize::Range(
          min=if buf_min > 0 { buf_min } else { 1 },
          max=if buf_max >= buf_min && buf_max > 0 { buf_max } else { buf_min },
        )
        out.push(
          @moon_cpal.SupportedStreamConfigRange::new(
            ch, min_sr, max_sr, buf, fmt,
          ),
        )
      }
    }
  }
  out
}

///|
fn supported_configs(
  d : Device,
  is_input : Bool,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  let b = supported_configs_bin(d.id, is_input)
  parse_supported_configs_bin(b)
}

///|
fn default_config(
  d : Device,
  is_input : Bool,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  let ranges = supported_configs(d, is_input)
  if ranges.length() == 0 {
    raise @moon_cpal.default_stream_config_error_stream_type_not_supported()
  }

  // Mirror upstream ALSA default selection:
  // - Choose the "best" supported range using heuristics.
  // - Use 44100Hz when within the chosen range, otherwise the max sample rate.
  let mut best = ranges[0]
  for r in ranges {
    if r.cmp_default_heuristics(best) > 0 {
      best = r
    }
  }
  let hz_44100 = 44100
  if best.min_sample_rate() <= hz_44100 && hz_44100 <= best.max_sample_rate() {
    best.with_sample_rate(hz_44100)
  } else {
    best.with_max_sample_rate()
  }
}
