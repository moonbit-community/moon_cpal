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
/// CPAL-like host/device surface for macOS (CoreAudio).
///
/// Includes device enumeration, config queries and native stream I/O (AudioQueue) with
/// MoonBit callback bridging.
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  id : DeviceId
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] raise CoreAudioError {
  device_ids().map(fn(id) { { id, } })
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  match default_output_device_id() {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  match default_input_device_id() {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
pub fn Device::name(self : Device) -> String raise CoreAudioError {
  device_name(self.id)
}

///|
pub fn Device::id(self : Device) -> @core.DeviceId {
  match device_uid(self.id) {
    Some(uid) if uid.trim().length() > 0 =>
      @core.DeviceId(@core.HostId::CoreAudio, uid)
    // Keep backend parity with upstream: ID is the CoreAudio UID, not the numeric AudioDeviceID.
    // An empty ID is promoted to DeviceIdError by platform.Device::id.
    _ => @core.DeviceId(@core.HostId::CoreAudio, "")
  }
}

///|
pub fn Device::supports_input(self : Device) -> Bool {
  ca_input_channel_count(self.id) > 0
}

///|
pub fn Device::supports_output(self : Device) -> Bool {
  ca_output_channel_count(self.id) > 0
}

///|
pub fn Device::description(
  self : Device,
) -> @core.DeviceDescription raise CoreAudioError {
  let name = device_name(self.id)
  let input_count : Int? = try supported_input_configs(self.id) catch {
    _ => None
  } noraise {
    xs => Some(xs.length())
  }
  let output_count : Int? = try supported_output_configs(self.id) catch {
    _ => None
  } noraise {
    xs => Some(xs.length())
  }
  let direction = @core.direction_from_counts(input_count, output_count)
  let mut builder = @core.DeviceDescriptionBuilder(name).direction(
    direction,
  )
  // Mirrors upstream CPAL: only tag aggregate devices.
  if device_is_aggregate(self.id) {
    builder = builder.interface_type(@core.InterfaceType::aggregate())
  }
  builder.build()
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  supported_input_configs(self.id)
}

///|
pub fn Device::supported_output_configs(
  self : Device,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  supported_output_configs(self.id)
}

///|
pub fn Device::default_input_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  default_input_config(self.id)
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  default_output_config(self.id)
}
