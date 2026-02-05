///|
/// CPAL-like trait surface (MoonBit).
///
/// This package provides `HostTrait`/`DeviceTrait`/`StreamTrait` analogues to upstream
/// `cpal::traits` and implements them for the `spec` API types.

///|
pub trait HostTrait {
  devices(Self) -> Array[@spec.Device] raise @moon_cpal.DevicesError
  device_by_id(Self, @moon_cpal.DeviceId) -> @spec.Device?
  default_input_device(Self) -> @spec.Device?
  default_output_device(Self) -> @spec.Device?
  input_devices(Self) -> Array[@spec.Device] raise @moon_cpal.DevicesError
  output_devices(Self) -> Array[@spec.Device] raise @moon_cpal.DevicesError
}

///|
pub trait DeviceTrait {
  name(Self) -> String raise @moon_cpal.DeviceNameError
  id(Self) -> @moon_cpal.DeviceId raise @moon_cpal.DeviceIdError
  description(Self) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError
  supports_input(Self) -> Bool
  supports_output(Self) -> Bool
  supported_input_configs(Self) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError
  supported_output_configs(Self) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError
  default_input_config(Self) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError
  default_output_config(Self) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError
  build_input_stream(
    Self,
    @moon_cpal.StreamConfig,
    (@spec.Data, @moon_cpal.InputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_input_stream_raw(
    Self,
    @moon_cpal.StreamConfig,
    @moon_cpal.SampleFormat,
    (@spec.Data, @moon_cpal.InputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_output_stream(
    Self,
    @moon_cpal.StreamConfig,
    (@spec.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_output_stream_raw(
    Self,
    @moon_cpal.StreamConfig,
    @moon_cpal.SampleFormat,
    (@spec.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_output_stream_f32(
    Self,
    @moon_cpal.StreamConfig,
    (Array[Float], @moon_cpal.OutputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_output_stream_i16(
    Self,
    @moon_cpal.StreamConfig,
    (Array[Int16], @moon_cpal.OutputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_output_stream_u16(
    Self,
    @moon_cpal.StreamConfig,
    (Array[UInt16], @moon_cpal.OutputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_output_stream_u8(
    Self,
    @moon_cpal.StreamConfig,
    (Array[Byte], @moon_cpal.OutputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_input_stream_f32(
    Self,
    @moon_cpal.StreamConfig,
    (Array[Float], @moon_cpal.InputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_input_stream_i16(
    Self,
    @moon_cpal.StreamConfig,
    (Array[Int16], @moon_cpal.InputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_input_stream_u16(
    Self,
    @moon_cpal.StreamConfig,
    (Array[UInt16], @moon_cpal.InputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
  build_input_stream_u8(
    Self,
    @moon_cpal.StreamConfig,
    (Array[Byte], @moon_cpal.InputCallbackInfo) -> Unit,
    (@moon_cpal.StreamError) -> Unit,
    @moon_cpal.Duration?,
  ) -> @spec.Stream raise @moon_cpal.BuildStreamError
}

///|
pub trait StreamTrait {
  play(Self) -> Unit raise @moon_cpal.PlayStreamError
  pause(Self) -> Unit raise @moon_cpal.PauseStreamError
  close(Self) -> Unit
}

///|
pub impl HostTrait for @spec.Host with devices(self : @spec.Host) {
  self.devices()
}

///|
pub impl HostTrait for @spec.Host with device_by_id(
  self : @spec.Host,
  id : @moon_cpal.DeviceId,
) {
  self.device_by_id(id)
}

///|
pub impl HostTrait for @spec.Host with default_input_device(self : @spec.Host) {
  self.default_input_device()
}

///|
pub impl HostTrait for @spec.Host with default_output_device(self : @spec.Host) {
  self.default_output_device()
}

///|
pub impl HostTrait for @spec.Host with input_devices(self : @spec.Host) {
  self.input_devices()
}

///|
pub impl HostTrait for @spec.Host with output_devices(self : @spec.Host) {
  self.output_devices()
}

///|
pub impl DeviceTrait for @spec.Device with name(self : @spec.Device) {
  self.name()
}

///|
pub impl DeviceTrait for @spec.Device with id(self : @spec.Device) {
  self.id()
}

///|
pub impl DeviceTrait for @spec.Device with description(self : @spec.Device) {
  self.description()
}

///|
pub impl DeviceTrait for @spec.Device with supports_input(self : @spec.Device) {
  self.supports_input()
}

///|
pub impl DeviceTrait for @spec.Device with supports_output(self : @spec.Device) {
  self.supports_output()
}

///|
pub impl DeviceTrait for @spec.Device with supported_input_configs(
  self : @spec.Device,
) {
  self.supported_input_configs()
}

///|
pub impl DeviceTrait for @spec.Device with supported_output_configs(
  self : @spec.Device,
) {
  self.supported_output_configs()
}

///|
pub impl DeviceTrait for @spec.Device with default_input_config(
  self : @spec.Device,
) {
  self.default_input_config()
}

///|
pub impl DeviceTrait for @spec.Device with default_output_config(
  self : @spec.Device,
) {
  self.default_output_config()
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@spec.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_input_stream(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_raw(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@spec.Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_input_stream_raw(
    config, sample_format, data_callback, error_callback, timeout,
  )
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (@spec.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_output_stream(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_raw(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (@spec.Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_output_stream_raw(
    config, sample_format, data_callback, error_callback, timeout,
  )
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_f32(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Float], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_output_stream_f32(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_i16(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Int16], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_output_stream_i16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_u16(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[UInt16], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_output_stream_u16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_u8(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Byte], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_output_stream_u8(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_f32(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Float], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_input_stream_f32(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_i16(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Int16], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_input_stream_i16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_u16(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[UInt16], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_input_stream_u16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_u8(
  self : @spec.Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Byte], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) {
  self.build_input_stream_u8(config, data_callback, error_callback, timeout)
}

///|
pub impl StreamTrait for @spec.Stream with play(self : @spec.Stream) {
  self.play()
}

///|
pub impl StreamTrait for @spec.Stream with pause(self : @spec.Stream) {
  self.pause()
}

///|
pub impl StreamTrait for @spec.Stream with close(self : @spec.Stream) {
  self.close()
}
