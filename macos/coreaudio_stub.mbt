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
/// Non-native backend stub.
pub type DeviceId = UInt

///|
fn osstatus_kind(_status : Int) -> Int {
  0
}

///|
pub fn default_output_device_id() -> DeviceId? raise CoreAudioError {
  raise_osstatus("default_output_device_id (non-native backend)", -1)
}

///|
pub fn default_input_device_id() -> DeviceId? raise CoreAudioError {
  raise_osstatus("default_input_device_id (non-native backend)", -1)
}

///|
pub fn device_ids() -> Array[DeviceId] raise CoreAudioError {
  raise_osstatus("device_ids (non-native backend)", -1)
}

///|
pub fn device_name(_device_id : DeviceId) -> String raise CoreAudioError {
  raise_osstatus("device_name (non-native backend)", -1)
}

///|
pub fn supported_input_configs(
  _device_id : DeviceId,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  raise_osstatus("supported_input_configs (non-native backend)", -1)
}

///|
pub fn supported_output_configs(
  _device_id : DeviceId,
) -> Array[@core.SupportedStreamConfigRange] raise CoreAudioError {
  raise_osstatus("supported_output_configs (non-native backend)", -1)
}

///|
pub fn default_input_config(
  _device_id : DeviceId,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  raise @core.default_stream_config_error_backend_specific(
    "default_input_config (non-native backend)",
  )
}

///|
pub fn default_output_config(
  _device_id : DeviceId,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  raise @core.default_stream_config_error_backend_specific(
    "default_output_config (non-native backend)",
  )
}
