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
  if @core.native_os() == @core.NativeOs::Linux {
    let bytes = devices_utf8()
    let s = @core.utf8_bytes_to_string(bytes, bytes.length())
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
    out
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @core.native_os() == @core.NativeOs::Linux {
    // Match upstream CPAL ALSA host: always return the "default" PCM, even though the actual
    // availability of output formats can only be determined by attempting to open a stream.
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @core.native_os() == @core.NativeOs::Linux {
    // Match upstream CPAL ALSA host: always return the "default" PCM (see above).
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Device::name(_self : Device) -> String {
  if @core.native_os() != @core.NativeOs::Linux {
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
) -> @core.DeviceDescription raise @core.DeviceNameError {
  let name = Device::name(_self)
  if name.length() == 0 {
    raise @core.device_name_error_backend_specific(
      "alsa device description: empty name",
    )
  }
  let has_in = (try _self.supported_input_configs().length() catch {
      _ => 0
    } noraise {
      x => x
    }) >
    0
  let has_out = (try _self.supported_output_configs().length() catch {
      _ => 0
    } noraise {
      x => x
    }) >
    0
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
  @core.DeviceDescription::new(
    name,
    driver=Some("ALSA"),
    device_type~,
    interface_type=@core.InterfaceType::unknown(),
    direction~,
    address=Some(_self.id),
    extended=["alsa_id=\{_self.id}"],
  )
}

///|
pub fn Device::id(_self : Device) -> @core.DeviceId {
  @core.DeviceId::new(@core.HostId::Alsa, _self.id)
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  if @core.native_os() != @core.NativeOs::Linux {
    return []
  }
  supported_configs(_self, true)
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  if @core.native_os() != @core.NativeOs::Linux {
    return []
  }
  supported_configs(_self, false)
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  if @core.native_os() != @core.NativeOs::Linux {
    raise @core.default_stream_config_error_backend_specific(
      "alsa default_input_config: not available on this OS",
    )
  }
  default_config(_self, true)
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  if @core.native_os() != @core.NativeOs::Linux {
    raise @core.default_stream_config_error_backend_specific(
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
fn i32_le_to_int(b : Bytes, off : Int) -> Int {
  // `Int` is i32 on native targets; our `u32_le_to_int` already reconstructs the 32-bit
  // bit-pattern, which naturally yields an i32 value (including negative errno-style values).
  u32_le_to_int(b, off)
}

///|
fn sample_format_from_bin_tag(tag : Int) -> @core.SampleFormat? {
  match tag {
    1 => Some(@core.SampleFormat::F32)
    2 => Some(@core.SampleFormat::I16)
    _ => None
  }
}

///|
fn parse_supported_configs_bin(
  b : Bytes,
) -> Array[@core.SupportedStreamConfigRange] {
  if b.length() < 8 {
    return []
  }
  // Header: i32 status, u32 record_count.
  let n = u32_le_to_int(b, 4)
  if n <= 0 {
    return []
  }
  let out : Array[@core.SupportedStreamConfigRange] = []
  let mut off = 8
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
        let buf = @core.SupportedBufferSize::Range(
          min=if buf_min > 0 { buf_min } else { 1 },
          max=if buf_max >= buf_min && buf_max > 0 { buf_max } else { buf_min },
        )
        out.push(
          @core.SupportedStreamConfigRange::new(ch, min_sr, max_sr, buf, fmt),
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
) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  let b = supported_configs_bin(d.id, is_input)
  if b.length() == 0 {
    return []
  }
  if b.length() < 8 {
    raise @core.supported_stream_configs_error_backend_specific(
      "alsa supported_configs: malformed header",
    )
  }
  let status = i32_le_to_int(b, 0)
  if status != 0 {
    if status == -19 {
      raise @core.supported_stream_configs_error_device_not_available()
    } else if status == -16 {
      raise @core.supported_stream_configs_error_device_busy()
    } else if status == -22 {
      raise @core.supported_stream_configs_error_invalid_argument()
    } else {
      raise @core.supported_stream_configs_error_backend_specific(
        "alsa supported_configs: errno \{status}",
      )
    }
  }
  parse_supported_configs_bin(b)
}

///|
fn default_config(
  d : Device,
  is_input : Bool,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  let ranges = try supported_configs(d, is_input) catch {
    @core.SupportedStreamConfigsError::DeviceNotAvailable =>
      raise @core.default_stream_config_error_device_not_available()
    @core.SupportedStreamConfigsError::DeviceBusy =>
      raise @core.default_stream_config_error_device_busy()
    @core.SupportedStreamConfigsError::InvalidArgument =>
      raise @core.default_stream_config_error_stream_type_not_supported()
    @core.SupportedStreamConfigsError::BackendSpecific(err) =>
      raise @core.default_stream_config_error_backend_specific(
        err.description(),
      )
  } noraise {
    xs => xs
  }
  if ranges.length() == 0 {
    raise @core.default_stream_config_error_stream_type_not_supported()
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
