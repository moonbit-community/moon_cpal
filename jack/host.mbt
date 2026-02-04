///|
/// JACK backend (Linux-only for now).
///
/// This backend is primarily intended for CI validation of our callback-thread stream model
/// in a JACK environment (using the dummy driver).
///
/// Implementation notes:
/// - For now we expose a single synthetic device with id="default".
/// - Real JACK "devices" are more like port graphs; upstream CPAL models this differently.

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  id : String
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
fn default_device() -> Device {
  { id: "default" }
}

///|
pub fn Host::devices(_self : Host) -> Array[Device] {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    [default_device()]
  } else {
    []
  }
}

///|
pub fn Host::default_output_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Host::default_input_device(_self : Host) -> Device? {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    Some(default_device())
  } else {
    None
  }
}

///|
pub fn Device::name(_self : Device) -> String {
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    "JACK".to_string()
  } else {
    _self.id
  }
}

///|
pub fn Device::description(
  _self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
  let name = Device::name(_self)
  if name.length() == 0 {
    raise @moon_cpal.device_name_error_backend_specific(
      "jack device description: empty name",
    )
  }
  @moon_cpal.DeviceDescription::new(
    name,
    driver=Some("JACK"),
    direction=@moon_cpal.DeviceDirection::duplex(),
    address=Some(_self.id),
  )
}

///|
pub fn Device::id(
  _self : Device,
) -> @moon_cpal.DeviceId {
  @moon_cpal.DeviceId::new(@moon_cpal.HostId::Jack, _self.id)
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
  supported_configs(_self)
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
  supported_configs(_self)
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise @moon_cpal.default_stream_config_error_backend_specific(
      "jack default_input_config: not available on this OS",
    )
  }
  default_config(_self)
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    raise @moon_cpal.default_stream_config_error_backend_specific(
      "jack default_output_config: not available on this OS",
    )
  }
  default_config(_self)
}

///|
fn default_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  match default_server_config() {
    None => raise @moon_cpal.default_stream_config_error_device_not_available()
    Some((sr, buf)) =>
      @moon_cpal.SupportedStreamConfig::new(
        2,
        sr,
        @moon_cpal.SupportedBufferSize::Range(min=buf, max=buf),
        @moon_cpal.SampleFormat::F32,
      )
  }
}

///|
fn supported_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  match default_server_config() {
    None => []
    Some((sr, buf)) => {
      // Mirrors upstream cpal's JACK backend: fixed sample rate/buffer size from server,
      // float32 sample format, and a small set of common channel counts.
      let chans = [1, 2, 4, 6, 8, 16, 24, 32, 48, 64]
      let buf_range = @moon_cpal.SupportedBufferSize::Range(min=buf, max=buf)
      let out : Array[@moon_cpal.SupportedStreamConfigRange] = []
      for ch in chans {
        out.push(
          @moon_cpal.SupportedStreamConfigRange::new(
            ch,
            sr,
            sr,
            buf_range,
            @moon_cpal.SampleFormat::F32,
          ),
        )
      }
      out
    }
  }
}
