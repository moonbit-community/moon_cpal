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
  // Upstream `cpal::available_hosts()` filters by runtime availability (HostTrait::is_available).
  //
  // We implement the runtime filtering at the `platform` layer (which can depend on backend
  // packages without introducing cycles).
  match @moon_cpal.native_os() {
    @moon_cpal.NativeOs::Macos => [@moon_cpal.HostId::CoreAudio]
    @moon_cpal.NativeOs::Windows => [@moon_cpal.HostId::Wasapi]
    // Match upstream ordering (platform `ALL_HOSTS`): JACK (feature-gated upstream) before ALSA.
    @moon_cpal.NativeOs::Linux =>
      [@moon_cpal.HostId::Jack, @moon_cpal.HostId::Alsa]
    // Match upstream: the Null backend exists as a fallback, but `available_hosts()` yields
    // only hosts that are currently available for real audio I/O.
    @moon_cpal.NativeOs::Unknown => []
  }
}

///|
pub fn all_hosts() -> Array[@moon_cpal.HostId] {
  // Mirrors upstream platform `ALL_HOSTS`: the set of hosts supported by the current compilation
  // target. This includes hosts that may not be currently available at runtime.
  //
  // Note: In upstream, `HostId` is platform-specific; on supported platforms it does not include
  // `Null`. In MoonBit we keep a cross-platform superset `HostId`, so we expose the platform
  // subset via this function.
  match @moon_cpal.native_os() {
    @moon_cpal.NativeOs::Macos => [@moon_cpal.HostId::CoreAudio]
    @moon_cpal.NativeOs::Windows => [@moon_cpal.HostId::Wasapi]
    @moon_cpal.NativeOs::Linux =>
      [@moon_cpal.HostId::Jack, @moon_cpal.HostId::Alsa]
    @moon_cpal.NativeOs::Unknown => [@moon_cpal.HostId::Null]
  }
}

///|
pub fn host_from_id(
  id : @moon_cpal.HostId,
) -> Host raise @moon_cpal.HostUnavailable {
  match id {
    // Upstream: platform `HostId` includes `Null` only on unsupported targets.
    Null =>
      if @moon_cpal.native_os() == @moon_cpal.NativeOs::Unknown {
        Host::Null(@null.default_host())
      } else {
        raise @moon_cpal.host_unavailable()
      }
    CoreAudio =>
      if @moon_cpal.native_os() == @moon_cpal.NativeOs::Macos {
        Host::CoreAudio(@macos.default_host())
      } else {
        raise @moon_cpal.host_unavailable()
      }
    Wasapi =>
      if @moon_cpal.native_os() == @moon_cpal.NativeOs::Windows {
        Host::Wasapi(@wasapi.default_host())
      } else {
        raise @moon_cpal.host_unavailable()
      }
    Alsa =>
      if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
        Host::Alsa(@alsa.default_host())
      } else {
        raise @moon_cpal.host_unavailable()
      }
    Jack =>
      if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
        Host::Jack(@jack.default_host())
      } else {
        raise @moon_cpal.host_unavailable()
      }
    _ => raise @moon_cpal.host_unavailable()
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
pub fn Host::device_by_id(self : Host, id : @moon_cpal.DeviceId) -> Device? {
  let ds = try Host::devices(self) catch {
    _ => []
  } noraise {
    xs => xs
  }
  for d in ds {
    let did = try d.id() catch {
      _ => None
    } noraise {
      x => Some(x)
    }
    match did {
      None => ()
      Some(did) => if did == id { return Some(d) }
    }
  }
  None
}

///|
pub fn Host::input_devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  let ds = Host::devices(self)
  let out : Array[Device] = []
  for d in ds {
    if d.supports_input() {
      out.push(d)
    }
  }
  out
}

///|
pub fn Host::output_devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  let ds = Host::devices(self)
  let out : Array[Device] = []
  for d in ds {
    if d.supports_output() {
      out.push(d)
    }
  }
  out
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
pub fn Device::id(
  self : Device,
) -> @moon_cpal.DeviceId raise @moon_cpal.DeviceIdError {
  let did = match self {
    Null(d) => d.id()
    CoreAudio(d) => d.id()
    Alsa(d) => d.id()
    Jack(d) => d.id()
    Wasapi(d) => d.id()
  }
  if did.device_id().is_empty() {
    raise @moon_cpal.device_id_error_backend_specific(
      "Device returned an empty device_id",
    )
  }
  did
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
pub fn Device::supports_input(self : Device) -> Bool {
  try Device::supported_input_configs(self).length() > 0 catch {
    _ => false
  }
}

///|
pub fn Device::supports_output(self : Device) -> Bool {
  try Device::supported_output_configs(self).length() > 0 catch {
    _ => false
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
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@moon_cpal.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
