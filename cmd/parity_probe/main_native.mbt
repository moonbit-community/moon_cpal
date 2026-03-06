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
  has_default_output_device : Bool
  default_output_device_id_ok : Bool
  default_output_device_id : String
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
  let (
    has_default_output_device,
    default_output_device_id_ok,
    default_output_device_id,
  ) = probe_host_default_device(host.default_output_device())
  {
    id: id.to_string(),
    devices_ok,
    devices,
    has_default_input_device,
    default_input_device_id_ok,
    default_input_device_id,
    has_default_output_device,
    default_output_device_id_ok,
    default_output_device_id,
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
