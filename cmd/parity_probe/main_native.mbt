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
struct ProbeBuffer {
  kind : String
  min_frames : Int
  max_frames : Int
} derive(ToJson)

///|
struct ProbeConfig {
  channels : Int
  sample_rate : Int
  sample_format : String
  buffer : ProbeBuffer
} derive(ToJson)

///|
struct ProbeConfigRange {
  channels : Int
  min_sample_rate : Int
  max_sample_rate : Int
  sample_format : String
  buffer : ProbeBuffer
} derive(ToJson)

///|
struct ProbeBuild {
  raw_ok : Bool
  has_typed_probe : Bool
  typed_kind : String
  typed_ok : Bool
} derive(ToJson)

///|
struct ProbeDevice {
  id_ok : Bool
  id : String
  name_ok : Bool
  name : String
  supports_input : Bool
  supports_output : Bool
  has_default_input_config : Bool
  default_input_config : ProbeConfig
  has_default_output_config : Bool
  default_output_config : ProbeConfig
  supported_input_configs_ok : Bool
  supported_input_configs : Array[ProbeConfigRange]
  supported_output_configs_ok : Bool
  supported_output_configs : Array[ProbeConfigRange]
} derive(ToJson)

///|
struct ProbeHost {
  id : String
  devices_ok : Bool
  devices : Array[ProbeDevice]
  has_default_input_device : Bool
  default_input_device_id_ok : Bool
  default_input_device_id : String
  has_default_input_build_probe : Bool
  default_input_build : ProbeBuild
  has_default_output_device : Bool
  default_output_device_id_ok : Bool
  default_output_device_id : String
  has_default_output_build_probe : Bool
  default_output_build : ProbeBuild
} derive(ToJson)

///|
struct ProbeSnapshot {
  all_hosts : Array[String]
  available_hosts : Array[String]
  default_host : String
  hosts : Array[ProbeHost]
} derive(ToJson)

///|
fn empty_buffer() -> ProbeBuffer {
  { kind: "unknown", min_frames: 0, max_frames: 0 }
}

///|
fn empty_config() -> ProbeConfig {
  { channels: 0, sample_rate: 0, sample_format: "", buffer: empty_buffer() }
}

///|
fn empty_build() -> ProbeBuild {
  { raw_ok: false, has_typed_probe: false, typed_kind: "", typed_ok: false }
}

///|
fn probe_buffer(b : @moon_cpal.SupportedBufferSize) -> ProbeBuffer {
  match b {
    @moon_cpal.SupportedBufferSize::Unknown => empty_buffer()
    @moon_cpal.SupportedBufferSize::Range(min=mn, max=mx) =>
      { kind: "range", min_frames: mn, max_frames: mx }
  }
}

///|
fn probe_config(cfg : @moon_cpal.SupportedStreamConfig) -> ProbeConfig {
  {
    channels: cfg.channels(),
    sample_rate: cfg.sample_rate(),
    sample_format: cfg.sample_format().to_string(),
    buffer: probe_buffer(cfg.buffer_size()),
  }
}

///|
fn probe_config_range(
  cfg : @moon_cpal.SupportedStreamConfigRange,
) -> ProbeConfigRange {
  {
    channels: cfg.channels(),
    min_sample_rate: cfg.min_sample_rate(),
    max_sample_rate: cfg.max_sample_rate(),
    sample_format: cfg.sample_format().to_string(),
    buffer: probe_buffer(cfg.buffer_size()),
  }
}

///|
fn probe_device_id(d : @moon_cpal.Device) -> (Bool, String) {
  try d.id() catch {
    _ => (false, "")
  } noraise {
    did => (true, did.to_string())
  }
}

///|
fn fill_output_f32_silence(xs : Array[Float]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = 0.0
    i = i + 1
  }
}

///|
fn fill_output_i16_silence(xs : Array[Int16]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = Int16::from_int(0)
    i = i + 1
  }
}

///|
fn fill_output_u16_silence(xs : Array[UInt16]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = (0x8000 : Int).to_uint16()
    i = i + 1
  }
}

///|
fn fill_output_u8_silence(xs : Array[Byte]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = Int::to_byte(0x80)
    i = i + 1
  }
}

///|
fn typed_probe_kind(sample_format : @moon_cpal.SampleFormat) -> (Bool, String) {
  match sample_format {
    @moon_cpal.SampleFormat::F32 => (true, "f32")
    @moon_cpal.SampleFormat::I16 => (true, "i16")
    @moon_cpal.SampleFormat::U16 => (true, "u16")
    @moon_cpal.SampleFormat::U8 => (true, "u8")
    _ => (false, "")
  }
}

///|
fn probe_raw_output_build(
  d : @moon_cpal.Device,
  cfg : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
) -> Bool {
  try
    d.build_output_stream_raw(
      cfg,
      sample_format,
      fn(data, _info) { data.clear() },
      fn(_err) {  },
      None,
    )
  catch {
    _ => false
  } noraise {
    st => {
      st.close()
      true
    }
  }
}

///|
fn probe_raw_input_build(
  d : @moon_cpal.Device,
  cfg : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
) -> Bool {
  try
    d.build_input_stream_raw(
      cfg,
      sample_format,
      fn(_data, _info) {  },
      fn(_err) {  },
      None,
    )
  catch {
    _ => false
  } noraise {
    st => {
      st.close()
      true
    }
  }
}

///|
fn probe_typed_output_build(
  d : @moon_cpal.Device,
  cfg : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
) -> (Bool, String, Bool) {
  let (has_typed_probe, typed_kind) = typed_probe_kind(sample_format)
  if !has_typed_probe {
    return (false, "", false)
  }
  let typed_ok = match sample_format {
    @moon_cpal.SampleFormat::F32 =>
      try
        d.build_output_stream_f32(
          cfg,
          fn(xs, _info) { fill_output_f32_silence(xs) },
          fn(_err) {  },
          None,
        )
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    @moon_cpal.SampleFormat::I16 =>
      try
        d.build_output_stream_i16(
          cfg,
          fn(xs, _info) { fill_output_i16_silence(xs) },
          fn(_err) {  },
          None,
        )
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    @moon_cpal.SampleFormat::U16 =>
      try
        d.build_output_stream_u16(
          cfg,
          fn(xs, _info) { fill_output_u16_silence(xs) },
          fn(_err) {  },
          None,
        )
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    @moon_cpal.SampleFormat::U8 =>
      try
        d.build_output_stream_u8(
          cfg,
          fn(xs, _info) { fill_output_u8_silence(xs) },
          fn(_err) {  },
          None,
        )
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    _ => false
  }
  (true, typed_kind, typed_ok)
}

///|
fn probe_typed_input_build(
  d : @moon_cpal.Device,
  cfg : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
) -> (Bool, String, Bool) {
  let (has_typed_probe, typed_kind) = typed_probe_kind(sample_format)
  if !has_typed_probe {
    return (false, "", false)
  }
  let typed_ok = match sample_format {
    @moon_cpal.SampleFormat::F32 =>
      try
        d.build_input_stream_f32(cfg, fn(_xs, _info) {  }, fn(_err) {  }, None)
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    @moon_cpal.SampleFormat::I16 =>
      try
        d.build_input_stream_i16(cfg, fn(_xs, _info) {  }, fn(_err) {  }, None)
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    @moon_cpal.SampleFormat::U16 =>
      try
        d.build_input_stream_u16(cfg, fn(_xs, _info) {  }, fn(_err) {  }, None)
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    @moon_cpal.SampleFormat::U8 =>
      try
        d.build_input_stream_u8(cfg, fn(_xs, _info) {  }, fn(_err) {  }, None)
      catch {
        _ => false
      } noraise {
        st => {
          st.close()
          true
        }
      }
    _ => false
  }
  (true, typed_kind, typed_ok)
}

///|
fn probe_default_output_build(d : @moon_cpal.Device?) -> (Bool, ProbeBuild) {
  match d {
    None => (false, empty_build())
    Some(dev) =>
      try dev.default_output_config() catch {
        _ => (false, empty_build())
      } noraise {
        supported => {
          let cfg = supported.config()
          let sample_format = supported.sample_format()
          let raw_ok = probe_raw_output_build(dev, cfg, sample_format)
          let (has_typed_probe, typed_kind, typed_ok) = probe_typed_output_build(
            dev, cfg, sample_format,
          )
          (true, { raw_ok, has_typed_probe, typed_kind, typed_ok })
        }
      }
  }
}

///|
fn probe_default_input_build(d : @moon_cpal.Device?) -> (Bool, ProbeBuild) {
  match d {
    None => (false, empty_build())
    Some(dev) =>
      try dev.default_input_config() catch {
        _ => (false, empty_build())
      } noraise {
        supported => {
          let cfg = supported.config()
          let sample_format = supported.sample_format()
          let raw_ok = probe_raw_input_build(dev, cfg, sample_format)
          let (has_typed_probe, typed_kind, typed_ok) = probe_typed_input_build(
            dev, cfg, sample_format,
          )
          (true, { raw_ok, has_typed_probe, typed_kind, typed_ok })
        }
      }
  }
}

///|
fn probe_device(d : @moon_cpal.Device) -> ProbeDevice {
  let (id_ok, id) = probe_device_id(d)
  let (name_ok, name) = try d.description() catch {
    _ => (false, "")
  } noraise {
    desc => (true, desc.name())
  }
  let supports_input = d.supports_input()
  let supports_output = d.supports_output()
  let (has_default_input_config, default_input_config) = try
    d.default_input_config()
  catch {
    _ => (false, empty_config())
  } noraise {
    cfg => (true, probe_config(cfg))
  }
  let (has_default_output_config, default_output_config) = try
    d.default_output_config()
  catch {
    _ => (false, empty_config())
  } noraise {
    cfg => (true, probe_config(cfg))
  }
  let (supported_input_configs_ok, supported_input_configs) = try
    d.supported_input_configs()
  catch {
    _ => (false, [])
  } noraise {
    it => (true, it.map(probe_config_range).to_array())
  }
  let (supported_output_configs_ok, supported_output_configs) = try
    d.supported_output_configs()
  catch {
    _ => (false, [])
  } noraise {
    it => (true, it.map(probe_config_range).to_array())
  }
  {
    id_ok,
    id,
    name_ok,
    name,
    supports_input,
    supports_output,
    has_default_input_config,
    default_input_config,
    has_default_output_config,
    default_output_config,
    supported_input_configs_ok,
    supported_input_configs,
    supported_output_configs_ok,
    supported_output_configs,
  }
}

///|
fn probe_host_default_device(d : @moon_cpal.Device?) -> (Bool, Bool, String) {
  match d {
    None => (false, false, "")
    Some(dev) => {
      let (id_ok, id) = probe_device_id(dev)
      (true, id_ok, id)
    }
  }
}

///|
fn probe_host(id : @moon_cpal.HostId) -> ProbeHost {
  let host = try! @moon_cpal.host_from_id(id)
  let (devices_ok, devices) = try host.devices() catch {
    _ => (false, [])
  } noraise {
    it => (true, it.map(probe_device).to_array())
  }
  let (
    has_default_input_device,
    default_input_device_id_ok,
    default_input_device_id,
  ) = probe_host_default_device(host.default_input_device())
  let (has_default_input_build_probe, default_input_build) = probe_default_input_build(
    host.default_input_device(),
  )
  let (
    has_default_output_device,
    default_output_device_id_ok,
    default_output_device_id,
  ) = probe_host_default_device(host.default_output_device())
  let (has_default_output_build_probe, default_output_build) = probe_default_output_build(
    host.default_output_device(),
  )
  {
    id: id.to_string(),
    devices_ok,
    devices,
    has_default_input_device,
    default_input_device_id_ok,
    default_input_device_id,
    has_default_input_build_probe,
    default_input_build,
    has_default_output_device,
    default_output_device_id_ok,
    default_output_device_id,
    has_default_output_build_probe,
    default_output_build,
  }
}

///|
fn snapshot() -> ProbeSnapshot {
  let all_hosts = @moon_cpal.all_hosts().map(@moon_cpal.HostId::to_string)
  let available = @moon_cpal.available_hosts()
  {
    all_hosts,
    available_hosts: available.map(@moon_cpal.HostId::to_string),
    default_host: @moon_cpal.default_host().id().to_string(),
    hosts: available.map(probe_host),
  }
}

///|
fn main {
  println(snapshot().to_json().stringify())
}
