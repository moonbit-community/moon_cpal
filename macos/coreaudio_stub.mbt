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
