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
/// Internal deterministic test backend.
///
/// This backend is used only for unit tests that validate callback ordering and timing semantics
/// without requiring real audio devices.

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  _unit : Unit
} derive(Show, Eq)

///|
pub fn Device::new() -> Device {
  { _unit: () }
}

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] {
  [Device::new()]
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  Some(Device::new())
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  Some(Device::new())
}

///|
pub fn Device::name(_self : Device) -> String {
  "test_host"
}

///|
pub fn Device::description(_self : Device) -> @core.DeviceDescription {
  @core.DeviceDescription::new(
    "Test Device",
    driver=Some("TestHost"),
    device_type=@core.DeviceType::virtual_(),
    interface_type=@core.InterfaceType::virtual_(),
    direction=@core.DeviceDirection::unknown(),
  )
}

///|
pub fn Device::id(_self : Device) -> @core.DeviceId {
  @core.DeviceId::new(@core.HostId::Null, "test_host")
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] {
  let buf = @core.SupportedBufferSize::Range(min=64, max=2048)
  let min_sr = 8000
  let max_sr = 192000
  let chans = [1, 2]
  let fmts = [
    @core.SampleFormat::F32,
    @core.SampleFormat::I16,
    @core.SampleFormat::U16,
    @core.SampleFormat::U8,
  ]
  let out : Array[@core.SupportedStreamConfigRange] = []
  for ch in chans {
    for fmt in fmts {
      out.push(
        @core.SupportedStreamConfigRange::new(ch, min_sr, max_sr, buf, fmt),
      )
    }
  }
  out
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] {
  Device::supported_input_configs(_self)
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @core.SupportedStreamConfig {
  @core.SupportedStreamConfig::new(
    2,
    48000,
    @core.SupportedBufferSize::Range(min=64, max=2048),
    @core.SampleFormat::F32,
  )
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @core.SupportedStreamConfig {
  Device::default_input_config(_self)
}
