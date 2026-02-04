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
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
  let buf = @moon_cpal.SupportedBufferSize::Range(min=64, max=4096)
  [
    @moon_cpal.SupportedStreamConfigRange::new(
      2,
      8000,
      192000,
      buf,
      @moon_cpal.SampleFormat::F32,
    ),
  ]
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return []
  }
  let buf = @moon_cpal.SupportedBufferSize::Range(min=64, max=4096)
  [
    @moon_cpal.SupportedStreamConfigRange::new(
      2,
      8000,
      192000,
      buf,
      @moon_cpal.SampleFormat::F32,
    ),
  ]
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
  @moon_cpal.SupportedStreamConfig::new(
    2,
    48000,
    @moon_cpal.SupportedBufferSize::Range(min=64, max=4096),
    @moon_cpal.SampleFormat::F32,
  )
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
  @moon_cpal.SupportedStreamConfig::new(
    2,
    48000,
    @moon_cpal.SupportedBufferSize::Range(min=64, max=4096),
    @moon_cpal.SampleFormat::F32,
  )
}
