///|
/// Temporary stub implementations for the declaration-only API in `spec.mbt`.
///
/// This package is a *spec/contract* and should not be used as an actual backend.

///|
pub struct Host {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Device {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Stream {
  _unit : Unit
} derive(Show, Eq)

///|
pub struct Data {
  _unit : Unit
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { _unit: () }
}

///|
pub fn host_from_id(
  _id : @moon_cpal.HostId,
) -> Host raise @moon_cpal.HostUnavailable {
  raise @moon_cpal.host_unavailable("spec stub")
}

///|
pub fn Host::id(_self : Host) -> @moon_cpal.HostId {
  @moon_cpal.HostId::Null
}

///|
pub fn Host::devices(
  _self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  raise @moon_cpal.devices_error_backend_specific("spec stub")
}

///|
pub fn Host::default_output_device(
  _self : Host,
) -> Device? raise @moon_cpal.DevicesError {
  raise @moon_cpal.devices_error_backend_specific("spec stub")
}

///|
pub fn Host::default_input_device(
  _self : Host,
) -> Device? raise @moon_cpal.DevicesError {
  raise @moon_cpal.devices_error_backend_specific("spec stub")
}

///|
pub fn Device::name(_self : Device) -> String raise @moon_cpal.DeviceNameError {
  raise @moon_cpal.device_name_error_backend_specific("spec stub")
}

///|
pub fn Device::supported_output_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  raise @moon_cpal.supported_stream_configs_error_backend_specific("spec stub")
}

///|
pub fn Device::supported_input_configs(
  _self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  raise @moon_cpal.supported_stream_configs_error_backend_specific("spec stub")
}

///|
pub fn Device::default_output_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  raise @moon_cpal.default_stream_config_error_backend_specific("spec stub")
}

///|
pub fn Device::default_input_config(
  _self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  raise @moon_cpal.default_stream_config_error_backend_specific("spec stub")
}

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific("spec stub")
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  _config : @moon_cpal.StreamConfig,
  _data_callback : (Data, @moon_cpal.InputCallbackInfo) -> Unit,
  _error_callback : (@moon_cpal.StreamError) -> Unit,
  _timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  raise @moon_cpal.build_stream_error_backend_specific("spec stub")
}

///|
pub fn Stream::play(_self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  raise @moon_cpal.play_stream_error_backend_specific("spec stub")
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  raise @moon_cpal.pause_stream_error_backend_specific("spec stub")
}

///|
pub fn Data::sample_format(_self : Data) -> @moon_cpal.SampleFormat {
  @moon_cpal.SampleFormat::F32
}

///|
pub fn Data::len(_self : Data) -> Int {
  0
}

///|
pub fn Data::bytes(_self : Data) -> Bytes {
  Bytes::new(0)
}
