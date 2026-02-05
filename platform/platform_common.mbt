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
/// Platform-level dynamic host/device wrappers.
///
/// This is a small MoonBit analogue of upstream `cpal::platform` dynamic dispatch types.
///
/// Native backends:
/// - Null (always available)
/// - macOS CoreAudio (native; stubbed on non-Apple native builds for linking)
/// - Linux ALSA + JACK
/// - Windows WASAPI

///|
pub enum Host {
  Null(@null.Host)
  CoreAudio(@macos.Host)
  Alsa(@alsa.Host)
  Jack(@jack.Host)
  Wasapi(@wasapi.Host)
} derive(Show, Eq)

///|
pub enum Device {
  Null(@null.Device)
  CoreAudio(@macos.Device)
  Alsa(@alsa.Device)
  Jack(@jack.Device)
  Wasapi(@wasapi.Device)
} derive(Show, Eq)

///|
pub enum Stream {
  Null(@null.Stream)
  CoreAudio(@macos.Stream)
  Alsa(@alsa.Stream)
  Jack(@jack.Stream)
  Wasapi(@wasapi.Stream)
} derive(Show, Eq)

///|
pub fn Host::id(self : Host) -> @core.HostId {
  match self {
    Null(_) => @core.HostId::Null
    CoreAudio(_) => @core.HostId::CoreAudio
    Alsa(_) => @core.HostId::Alsa
    Jack(_) => @core.HostId::Jack
    Wasapi(_) => @core.HostId::Wasapi
  }
}

///|
pub fn available_hosts() -> Array[@core.HostId] {
  // Upstream `cpal::available_hosts()` filters by runtime availability (HostTrait::is_available).
  //
  // We implement the runtime filtering at the `platform` layer (which can depend on backend
  // packages without introducing cycles).
  match @core.native_os() {
    @core.NativeOs::Macos => [@core.HostId::CoreAudio]
    @core.NativeOs::Windows => [@core.HostId::Wasapi]
    // Match upstream ordering (platform `ALL_HOSTS`): JACK (feature-gated upstream) before ALSA.
    @core.NativeOs::Linux => [@core.HostId::Jack, @core.HostId::Alsa]
    // Match upstream: the Null backend exists as a fallback, but `available_hosts()` yields
    // only hosts that are currently available for real audio I/O.
    @core.NativeOs::Unknown => []
  }
}

///|
pub fn all_hosts() -> Array[@core.HostId] {
  // Mirrors upstream platform `ALL_HOSTS`: the set of hosts supported by the current compilation
  // target. This includes hosts that may not be currently available at runtime.
  //
  // Note: In upstream, `HostId` is platform-specific; on supported platforms it does not include
  // `Null`. In MoonBit we keep a cross-platform superset `HostId`, so we expose the platform
  // subset via this function.
  match @core.native_os() {
    @core.NativeOs::Macos => [@core.HostId::CoreAudio]
    @core.NativeOs::Windows => [@core.HostId::Wasapi]
    @core.NativeOs::Linux => [@core.HostId::Jack, @core.HostId::Alsa]
    @core.NativeOs::Unknown => [@core.HostId::Null]
  }
}

///|
pub fn host_from_id(id : @core.HostId) -> Host raise @core.HostUnavailable {
  match id {
    // Upstream: platform `HostId` includes `Null` only on unsupported targets.
    Null =>
      if @core.native_os() == @core.NativeOs::Unknown {
        Host::Null(@null.default_host())
      } else {
        raise @core.host_unavailable()
      }
    CoreAudio =>
      if @core.native_os() == @core.NativeOs::Macos {
        Host::CoreAudio(@macos.default_host())
      } else {
        raise @core.host_unavailable()
      }
    Wasapi =>
      if @core.native_os() == @core.NativeOs::Windows {
        Host::Wasapi(@wasapi.default_host())
      } else {
        raise @core.host_unavailable()
      }
    Alsa =>
      if @core.native_os() == @core.NativeOs::Linux {
        Host::Alsa(@alsa.default_host())
      } else {
        raise @core.host_unavailable()
      }
    Jack =>
      if @core.native_os() == @core.NativeOs::Linux {
        Host::Jack(@jack.default_host())
      } else {
        raise @core.host_unavailable()
      }
    _ => raise @core.host_unavailable()
  }
}

///|
pub fn try_host_from_id(id : @core.HostId) -> Host? {
  try host_from_id(id) catch {
    _ => None
  } noraise {
    h => Some(h)
  }
}

///|
pub fn Host::default_output_device(self : Host) -> Device? {
  match self {
    Null(h) =>
      match h.default_output_device() {
        None => None
        Some(d) => Some(Device::Null(d))
      }
    CoreAudio(h) =>
      match h.default_output_device() {
        None => None
        Some(d) => Some(Device::CoreAudio(d))
      }
    Alsa(h) =>
      match h.default_output_device() {
        None => None
        Some(d) => Some(Device::Alsa(d))
      }
    Jack(h) =>
      match h.default_output_device() {
        None => None
        Some(d) => Some(Device::Jack(d))
      }
    Wasapi(h) =>
      match h.default_output_device() {
        None => None
        Some(d) => Some(Device::Wasapi(d))
      }
  }
}

///|
pub fn Host::default_input_device(self : Host) -> Device? {
  match self {
    Null(h) =>
      match h.default_input_device() {
        None => None
        Some(d) => Some(Device::Null(d))
      }
    CoreAudio(h) =>
      match h.default_input_device() {
        None => None
        Some(d) => Some(Device::CoreAudio(d))
      }
    Alsa(h) =>
      match h.default_input_device() {
        None => None
        Some(d) => Some(Device::Alsa(d))
      }
    Jack(h) =>
      match h.default_input_device() {
        None => None
        Some(d) => Some(Device::Jack(d))
      }
    Wasapi(h) =>
      match h.default_input_device() {
        None => None
        Some(d) => Some(Device::Wasapi(d))
      }
  }
}

///|
pub fn Host::devices(self : Host) -> Iter[Device] raise @core.DevicesError {
  match self {
    Null(h) => {
      let ds = h.devices()
      ds.iter().map(fn(d) { Device::Null(d) })
    }
    CoreAudio(h) =>
      try h.devices() catch {
        @macos.CoreAudioError::DeviceNotAvailable(op, status) =>
          raise @core.devices_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @core.devices_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
      } noraise {
        ds => ds.iter().map(fn(d) { Device::CoreAudio(d) })
      }
    Alsa(h) => {
      let ds = h.devices()
      ds.iter().map(fn(d) { Device::Alsa(d) })
    }
    Jack(h) => {
      let ds = h.devices()
      ds.iter().map(fn(d) { Device::Jack(d) })
    }
    Wasapi(h) => {
      let ds = h.devices()
      ds.iter().map(fn(d) { Device::Wasapi(d) })
    }
  }
}

///|
pub fn Host::device_by_id(self : Host, id : @core.DeviceId) -> Device? {
  let ds = try Host::devices(self) catch {
    _ => return None
  } noraise {
    xs => xs
  }
  ds.find_first(fn(d) {
    try d.id() catch {
      _ => false
    } noraise {
      did => did == id
    }
  })
}

///|
pub fn Host::input_devices(
  self : Host,
) -> Iter[Device] raise @core.DevicesError {
  Host::devices(self).filter(fn(d) { d.supports_input() })
}

///|
pub fn Host::output_devices(
  self : Host,
) -> Iter[Device] raise @core.DevicesError {
  Host::devices(self).filter(fn(d) { d.supports_output() })
}

///|
pub fn Device::name(self : Device) -> String raise @core.DeviceNameError {
  match self {
    Null(d) => d.name()
    CoreAudio(d) =>
      try d.name() catch {
        @macos.CoreAudioError::DeviceNotAvailable(op, status) =>
          raise @core.device_name_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @core.device_name_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
      } noraise {
        s => s
      }
    Alsa(d) => d.name()
    Jack(d) => d.name()
    Wasapi(d) => d.name()
  }
}

///|
pub fn Device::id(self : Device) -> @core.DeviceId raise @core.DeviceIdError {
  let did = match self {
    Null(d) => d.id()
    CoreAudio(d) => d.id()
    Alsa(d) => d.id()
    Jack(d) => d.id()
    Wasapi(d) => d.id()
  }
  if did.device_id().is_empty() {
    raise @core.device_id_error_backend_specific(
      "Device returned an empty device_id",
    )
  }
  did
}

///|
pub fn Device::description(
  self : Device,
) -> @core.DeviceDescription raise @core.DeviceNameError {
  match self {
    Null(d) => d.description()
    CoreAudio(d) =>
      try d.description() catch {
        @macos.CoreAudioError::DeviceNotAvailable(op, status) =>
          raise @core.device_name_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @core.device_name_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
      } noraise {
        x => x
      }
    Alsa(d) => d.description()
    Jack(d) => d.description()
    Wasapi(d) => d.description()
  }
}

///|
pub fn Device::supports_input(self : Device) -> Bool {
  match self {
    Alsa(d) => d.supports_input()
    Jack(d) => d.supports_input()
    _ =>
      try (Device::supported_input_configs(self).next() is Some(_)) catch {
        _ => false
      }
  }
}

///|
pub fn Device::supports_output(self : Device) -> Bool {
  match self {
    Alsa(d) => d.supports_output()
    Jack(d) => d.supports_output()
    _ =>
      try (Device::supported_output_configs(self).next() is Some(_)) catch {
        _ => false
      }
  }
}

///|
pub fn Device::supported_output_configs(
  self : Device,
) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  match self {
    Null(d) => {
      let xs = d.supported_output_configs()
      xs.iter()
    }
    CoreAudio(d) =>
      try d.supported_output_configs() catch {
        @macos.CoreAudioError::DeviceNotAvailable(_, _) =>
          raise @core.supported_stream_configs_error_device_not_available()
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @macos.supported_configs_error_from_osstatus(op, status)
      } noraise {
        xs => xs.iter()
      }
    Alsa(d) => {
      let xs = d.supported_output_configs()
      xs.iter()
    }
    Jack(d) => {
      let xs = d.supported_output_configs()
      xs.iter()
    }
    Wasapi(d) => {
      let xs = d.supported_output_configs()
      xs.iter()
    }
  }
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  match self {
    Null(d) => {
      let xs = d.supported_input_configs()
      xs.iter()
    }
    CoreAudio(d) =>
      try d.supported_input_configs() catch {
        @macos.CoreAudioError::DeviceNotAvailable(_, _) =>
          raise @core.supported_stream_configs_error_device_not_available()
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @macos.supported_configs_error_from_osstatus(op, status)
      } noraise {
        xs => xs.iter()
      }
    Alsa(d) => {
      let xs = d.supported_input_configs()
      xs.iter()
    }
    Jack(d) => {
      let xs = d.supported_input_configs()
      xs.iter()
    }
    Wasapi(d) => {
      let xs = d.supported_input_configs()
      xs.iter()
    }
  }
}

///|
pub fn Device::try_default_output_config(
  self : Device,
) -> @core.SupportedStreamConfig? {
  match self {
    Null(d) =>
      try d.default_output_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    CoreAudio(d) =>
      try d.default_output_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    Alsa(d) =>
      try d.default_output_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    Jack(d) =>
      try d.default_output_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    Wasapi(d) =>
      try d.default_output_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
  }
}

///|
pub fn Device::try_default_input_config(
  self : Device,
) -> @core.SupportedStreamConfig? {
  match self {
    Null(d) =>
      try d.default_input_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    CoreAudio(d) =>
      try d.default_input_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    Alsa(d) =>
      try d.default_input_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    Jack(d) =>
      try d.default_input_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
    Wasapi(d) =>
      try d.default_input_config() catch {
        _ => None
      } noraise {
        cfg => Some(cfg)
      }
  }
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  match self {
    Null(d) => d.default_output_config()
    CoreAudio(d) => d.default_output_config()
    Alsa(d) => d.default_output_config()
    Jack(d) => d.default_output_config()
    Wasapi(d) => d.default_output_config()
  }
}

///|
pub fn Device::default_input_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  match self {
    Null(d) => d.default_input_config()
    CoreAudio(d) => d.default_input_config()
    Alsa(d) => d.default_input_config()
    Jack(d) => d.default_input_config()
    Wasapi(d) => d.default_input_config()
  }
}

///|
pub fn Device::build_output_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  match self {
    Null(d) =>
      Stream::Null(
        d.build_output_stream(config, data_callback, error_callback, timeout),
      )
    CoreAudio(d) =>
      Stream::CoreAudio(
        d.build_output_stream(config, data_callback, error_callback, timeout),
      )
    Alsa(d) =>
      Stream::Alsa(
        d.build_output_stream(config, data_callback, error_callback, timeout),
      )
    Jack(d) =>
      Stream::Jack(
        d.build_output_stream(config, data_callback, error_callback, timeout),
      )
    Wasapi(d) =>
      Stream::Wasapi(
        d.build_output_stream(config, data_callback, error_callback, timeout),
      )
  }
}

///|
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  match self {
    Null(d) =>
      Stream::Null(
        d.build_output_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    CoreAudio(d) =>
      Stream::CoreAudio(
        d.build_output_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    Alsa(d) =>
      Stream::Alsa(
        d.build_output_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    Jack(d) =>
      Stream::Jack(
        d.build_output_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    Wasapi(d) =>
      Stream::Wasapi(
        d.build_output_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
  }
}

///|
pub fn Device::build_input_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  match self {
    Null(d) =>
      Stream::Null(
        d.build_input_stream(config, data_callback, error_callback, timeout),
      )
    CoreAudio(d) =>
      Stream::CoreAudio(
        d.build_input_stream(config, data_callback, error_callback, timeout),
      )
    Alsa(d) =>
      Stream::Alsa(
        d.build_input_stream(config, data_callback, error_callback, timeout),
      )
    Jack(d) =>
      Stream::Jack(
        d.build_input_stream(config, data_callback, error_callback, timeout),
      )
    Wasapi(d) =>
      Stream::Wasapi(
        d.build_input_stream(config, data_callback, error_callback, timeout),
      )
  }
}

///|
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  match self {
    Null(d) =>
      Stream::Null(
        d.build_input_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    CoreAudio(d) =>
      Stream::CoreAudio(
        d.build_input_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    Alsa(d) =>
      Stream::Alsa(
        d.build_input_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    Jack(d) =>
      Stream::Jack(
        d.build_input_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
    Wasapi(d) =>
      Stream::Wasapi(
        d.build_input_stream_raw(
          config, sample_format, data_callback, error_callback, timeout,
        ),
      )
  }
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  match self {
    Null(s) => s.play()
    CoreAudio(s) => s.play()
    Alsa(s) => s.play()
    Jack(s) => s.play()
    Wasapi(s) => s.play()
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  match self {
    Null(s) => s.pause()
    CoreAudio(s) => s.pause()
    Alsa(s) => s.pause()
    Jack(s) => s.pause()
    Wasapi(s) => s.pause()
  }
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  match self {
    Null(s) => s.close()
    CoreAudio(s) => s.close()
    Alsa(s) => s.close()
    Jack(s) => s.close()
    Wasapi(s) => s.close()
  }
}
