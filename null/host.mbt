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
/// Null backend implementation.
///
/// Mirrors upstream `cpal::host::null`: a fallback backend for unsupported platforms.
/// The host can be constructed, but reports no devices and most device/stream operations are
/// unimplemented (represented here as backend-specific errors).

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  _unit : Unit
} derive(Show, Eq)

///|
let _unused_device_for_lint : Device = { _unit: () }

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] {
  []
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  None
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  None
}

///|
pub fn Device::name(_self : Device) -> String {
  "null"
}

///|
pub fn Device::description(_self : Device) -> @core.DeviceDescription {
  let name = "Null Device"
  @core.DeviceDescription::new(
    name,
    driver=Some("Null"),
    device_type=@core.DeviceType::virtual_(),
    interface_type=@core.InterfaceType::virtual_(),
    direction=@core.DeviceDirection::unknown(),
  )
}

///|
pub fn Device::id(_self : Device) -> @core.DeviceId {
  @core.DeviceId::new(@core.HostId::Null, "")
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  raise @core.supported_stream_configs_error_backend_specific(
    "null supported_input_configs: unimplemented",
  )
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  raise @core.supported_stream_configs_error_backend_specific(
    "null supported_output_configs: unimplemented",
  )
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  raise @core.default_stream_config_error_backend_specific(
    "null default_input_config: unimplemented",
  )
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  raise @core.default_stream_config_error_backend_specific(
    "null default_output_config: unimplemented",
  )
}
