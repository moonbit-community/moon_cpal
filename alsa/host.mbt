// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
  desc : String?
  direction : @core.DeviceDirection
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
fn default_device() -> Device {
  // Mirrors typical ALSA "default" PCM.
  { id: "default", desc: None, direction: @core.DeviceDirection::duplex() }
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
        // Each line is: "<id>\t<dir>\t<desc_escaped>".
        let fields = Array::new()
        for p in id.split("\t") {
          fields.push(p)
        }
        let pcm_id = if fields.length() > 0 {
          fields[0].trim().to_string()
        } else {
          "".to_string()
        }
        if pcm_id.length() == 0 {
          continue
        }
        let dir_tag = if fields.length() > 1 {
          fields[1].trim().to_string()
        } else {
          "?".to_string()
        }
        let desc_esc = if fields.length() > 2 {
          fields[2].to_string()
        } else {
          ""
        }
        let dir = match dir_tag {
          "i" => @core.DeviceDirection::input()
          "o" => @core.DeviceDirection::output()
          "d" => @core.DeviceDirection::duplex()
          _ => @core.DeviceDirection::unknown()
        }
        let desc = if desc_esc.length() == 0 {
          None
        } else {
          Some(unescape(desc_esc))
        }
        out.push({ id: pcm_id, desc, direction: dir })
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
  // Match upstream ALSA: `name()` returns the PCM id.
  _self.id
}

///|
pub fn Device::description(
  _self : Device,
) -> @core.DeviceDescription raise @core.DeviceNameError {
  let name = match _self.desc {
    None => _self.id
    Some(desc) => {
      let mut first = _self.id
      for line in desc[:].split("\n"[:]) {
        let s = line.trim().to_string()
        if s.length() > 0 {
          first = s
          break
        }
      }
      first
    }
  }
  if name.length() == 0 {
    raise @core.device_name_error_backend_specific(
      "alsa device description: empty name",
    )
  }
  let extended : Array[String] = []
  match _self.desc {
    None => ()
    Some(desc) =>
      for line in desc[:].split("\n"[:]) {
        let t = line.trim().to_string()
        if t.length() > 0 {
          extended.push(t)
        }
      }
  }
  @core.DeviceDescription(
    name,
    driver=Some(_self.id),
    device_type=@core.DeviceType::unknown(),
    interface_type=@core.InterfaceType::unknown(),
    direction=_self.direction,
    address=None,
    extended~,
  )
}

///|
pub fn Device::id(_self : Device) -> @core.DeviceId {
  @core.DeviceId(@core.HostId::Alsa, _self.id)
}

///|
pub fn Device::supports_input(_self : Device) -> Bool {
  match _self.direction {
    @core.DeviceDirection::Input => true
    @core.DeviceDirection::Duplex => true
    @core.DeviceDirection::Unknown => true
    _ => false
  }
}

///|
pub fn Device::supports_output(_self : Device) -> Bool {
  match _self.direction {
    @core.DeviceDirection::Output => true
    @core.DeviceDirection::Duplex => true
    @core.DeviceDirection::Unknown => true
    _ => false
  }
}

///|
fn unescape(s : String) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < s.length() {
    let cu = s.code_unit_at(i).to_int()
    if cu == 92 && i + 1 < s.length() {
      let n = s.code_unit_at(i + 1).to_int()
      if n == 110 {
        sb.write_char((10 : Int).unsafe_to_char())
        i = i + 2
        continue
      }
      if n == 116 {
        sb.write_char((9 : Int).unsafe_to_char())
        i = i + 2
        continue
      }
      if n == 92 {
        sb.write_char((92 : Int).unsafe_to_char())
        i = i + 2
        continue
      }
    }
    sb.write_char(cu.unsafe_to_char())
    i = i + 1
  }
  sb.to_string()
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  if @core.native_os() != @core.NativeOs::Linux {
    return []
  }
  if !_self.supports_input() {
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
  if !_self.supports_output() {
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
  if !_self.supports_input() {
    raise @core.default_stream_config_error_stream_type_not_supported()
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
  if !_self.supports_output() {
    raise @core.default_stream_config_error_stream_type_not_supported()
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
    1 => Some(@core.SampleFormat::I8)
    2 => Some(@core.SampleFormat::U8)
    3 => Some(@core.SampleFormat::I16)
    4 => Some(@core.SampleFormat::U16)
    5 => Some(@core.SampleFormat::I24)
    6 => Some(@core.SampleFormat::U24)
    7 => Some(@core.SampleFormat::I32)
    8 => Some(@core.SampleFormat::U32)
    9 => Some(@core.SampleFormat::F32)
    10 => Some(@core.SampleFormat::F64)
    11 => Some(@core.SampleFormat::DsdU8)
    12 => Some(@core.SampleFormat::DsdU16)
    13 => Some(@core.SampleFormat::DsdU32)
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
          @core.SupportedStreamConfigRange(ch, min_sr, max_sr, buf, fmt),
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
