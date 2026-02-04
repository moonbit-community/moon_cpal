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
pub fn Host::id(self : Host) -> @moon_cpal.HostId {
  match self {
    Null(_) => @moon_cpal.HostId::Null
    CoreAudio(_) => @moon_cpal.HostId::CoreAudio
    Alsa(_) => @moon_cpal.HostId::Alsa
    Jack(_) => @moon_cpal.HostId::Jack
    Wasapi(_) => @moon_cpal.HostId::Wasapi
  }
}

///|
pub fn available_hosts() -> Array[@moon_cpal.HostId] {
  @moon_cpal.available_hosts()
}

///|
pub fn host_from_id(
  id : @moon_cpal.HostId,
) -> Host raise @moon_cpal.HostUnavailable {
  let hs = available_hosts()
  let mut ok = false
  for i in 0..<hs.length() {
    if hs[i] == id {
      ok = true
      break
    }
  }
  if !ok {
    raise @moon_cpal.host_unavailable(@moon_cpal.HostId::to_string(id))
  }
  match id {
    CoreAudio => Host::CoreAudio(@macos.default_host())
    Alsa => Host::Alsa(@alsa.default_host())
    Jack => Host::Jack(@jack.default_host())
    Null => Host::Null(@null.default_host())
    Wasapi => Host::Wasapi(@wasapi.default_host())
    _ => raise @moon_cpal.host_unavailable(@moon_cpal.HostId::to_string(id))
  }
}

///|
pub fn try_host_from_id(id : @moon_cpal.HostId) -> Host? {
  try host_from_id(id) catch {
    _ => None
  } noraise {
    h => Some(h)
  }
}

///|
pub fn Host::default_output_device(
  self : Host,
) -> Device? {
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
pub fn Host::default_input_device(
  self : Host,
) -> Device? {
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
pub fn Host::devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  match self {
    Null(h) => h.devices().map(fn(d) { Device::Null(d) })
    CoreAudio(h) =>
      try h.devices() catch {
        @macos.CoreAudioError::DeviceNotAvailable(op, status) =>
          raise @moon_cpal.devices_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @moon_cpal.devices_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
      } noraise {
        ds => ds.map(fn(d) { Device::CoreAudio(d) })
      }
    Alsa(h) => h.devices().map(fn(d) { Device::Alsa(d) })
    Jack(h) => h.devices().map(fn(d) { Device::Jack(d) })
    Wasapi(h) => h.devices().map(fn(d) { Device::Wasapi(d) })
  }
}

///|
pub fn Device::name(self : Device) -> String raise @moon_cpal.DeviceNameError {
  match self {
    Null(d) => d.name()
    CoreAudio(d) =>
      try d.name() catch {
        @macos.CoreAudioError::DeviceNotAvailable(op, status) =>
          raise @moon_cpal.device_name_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @moon_cpal.device_name_error_backend_specific(
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
pub fn Device::description(
  self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
  match self {
    Null(d) => d.description()
    CoreAudio(d) =>
      try d.description() catch {
        @macos.CoreAudioError::DeviceNotAvailable(op, status) =>
          raise @moon_cpal.device_name_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @moon_cpal.device_name_error_backend_specific(
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
pub fn Device::supported_output_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  match self {
    Null(d) => d.supported_output_configs()
    CoreAudio(d) =>
      try d.supported_output_configs() catch {
        @macos.CoreAudioError::DeviceNotAvailable(_, _) =>
          raise @moon_cpal.supported_stream_configs_error_device_not_available()
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @moon_cpal.supported_stream_configs_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
      } noraise {
        xs => xs
      }
    Alsa(d) => d.supported_output_configs()
    Jack(d) => d.supported_output_configs()
    Wasapi(d) => d.supported_output_configs()
  }
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  match self {
    Null(d) => d.supported_input_configs()
    CoreAudio(d) =>
      try d.supported_input_configs() catch {
        @macos.CoreAudioError::DeviceNotAvailable(_, _) =>
          raise @moon_cpal.supported_stream_configs_error_device_not_available()
        @macos.CoreAudioError::CoreAudioError(op, status) =>
          raise @moon_cpal.supported_stream_configs_error_backend_specific(
            "\{op} (OSStatus \{status})",
          )
      } noraise {
        xs => xs
      }
    Alsa(d) => d.supported_input_configs()
    Jack(d) => d.supported_input_configs()
    Wasapi(d) => d.supported_input_configs()
  }
}

///|
pub fn Device::try_default_output_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig? {
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
) -> @moon_cpal.SupportedStreamConfig? {
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
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
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
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
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
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
pub fn Device::build_input_stream(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  match self {
    Null(s) => s.play()
    CoreAudio(s) => s.play()
    Alsa(s) => s.play()
    Jack(s) => s.play()
    Wasapi(s) => s.play()
  }
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
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
