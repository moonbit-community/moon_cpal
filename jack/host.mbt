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
/// JACK backend (Linux-only for now).
///
/// This backend is primarily intended for CI validation of our callback-thread stream model
/// in a JACK environment (using the dummy driver).
///
/// Implementation notes:
/// - Mirrors upstream CPAL: expose one input device and one output device (JACK client ports).

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  id : String
  direction : @core.DeviceDirection
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
fn default_output_device() -> Device {
  { id: "cpal_client_out", direction: @core.DeviceDirection::output() }
}

///|
fn default_input_device() -> Device {
  { id: "cpal_client_in", direction: @core.DeviceDirection::input() }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] {
  if @core.native_os() == @core.NativeOs::Linux {
    match default_server_config() {
      None => []
      Some(_) => [default_input_device(), default_output_device()]
    }
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @core.native_os() == @core.NativeOs::Linux {
    match default_server_config() {
      None => None
      Some(_) => Some(default_output_device())
    }
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @core.native_os() == @core.NativeOs::Linux {
    match default_server_config() {
      None => None
      Some(_) => Some(default_input_device())
    }
  } else {
    None
  }
}

///|
pub fn Device::name(_self : Device) -> String {
  if @core.native_os() == @core.NativeOs::Linux {
    _self.id
  } else {
    _self.id
  }
}

///|
pub fn Device::description(
  _self : Device,
) -> @core.DeviceDescription raise @core.DeviceNameError {
  let name = Device::name(_self)
  if name.length() == 0 {
    raise @core.device_name_error_backend_specific(
      "jack device description: empty name",
    )
  }
  // Mirrors upstream CPAL: only name + direction are filled for JACK.
  @core.DeviceDescriptionBuilder::new(name).direction(_self.direction).build()
}

///|
pub fn Device::id(_self : Device) -> @core.DeviceId {
  @core.DeviceId::new(@core.HostId::Jack, _self.id)
}

///|
pub fn Device::supports_input(_self : Device) -> Bool {
  if @core.native_os() != @core.NativeOs::Linux {
    false
  } else {
    match default_server_config() {
      None => false
      Some(_) => true
    }
  }
}

///|
pub fn Device::supports_output(_self : Device) -> Bool {
  if @core.native_os() != @core.NativeOs::Linux {
    false
  } else {
    match default_server_config() {
      None => false
      Some(_) => true
    }
  }
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] {
  if @core.native_os() != @core.NativeOs::Linux {
    return []
  }
  supported_configs(_self)
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@core.SupportedStreamConfigRange] {
  if @core.native_os() != @core.NativeOs::Linux {
    return []
  }
  supported_configs(_self)
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  if @core.native_os() != @core.NativeOs::Linux {
    raise @core.default_stream_config_error_backend_specific(
      "jack default_input_config: not available on this OS",
    )
  }
  default_config(_self)
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  if @core.native_os() != @core.NativeOs::Linux {
    raise @core.default_stream_config_error_backend_specific(
      "jack default_output_config: not available on this OS",
    )
  }
  default_config(_self)
}

///|
fn default_config(
  _self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  match default_server_config() {
    None => raise @core.default_stream_config_error_device_not_available()
    Some((sr, buf)) =>
      @core.SupportedStreamConfig::new(
        2,
        sr,
        @core.SupportedBufferSize::Range(min=buf, max=buf),
        @core.SampleFormat::F32,
      )
  }
}

///|
fn supported_configs(_self : Device) -> Array[@core.SupportedStreamConfigRange] {
  match default_server_config() {
    None => []
    Some((sr, buf)) => {
      // Mirrors upstream cpal's JACK backend: fixed sample rate/buffer size from server,
      // float32 sample format, and a small set of common channel counts.
      let chans = [1, 2, 4, 6, 8, 16, 24, 32, 48, 64]
      let buf_range = @core.SupportedBufferSize::Range(min=buf, max=buf)
      let out : Array[@core.SupportedStreamConfigRange] = []
      for ch in chans {
        out.push(
          @core.SupportedStreamConfigRange::new(
            ch,
            sr,
            sr,
            buf_range,
            @core.SampleFormat::F32,
          ),
        )
      }
      out
    }
  }
}
