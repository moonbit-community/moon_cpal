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
/// CPAL-like trait surface (MoonBit).
///
/// This package provides `HostTrait`/`DeviceTrait`/`StreamTrait` analogues to upstream
/// `cpal::traits` and implements them for the `spec` API types.

///|
pub trait HostTrait {
  devices(Self) -> Array[@spec.Device] raise @core.DevicesError
  device_by_id(Self, @core.DeviceId) -> @spec.Device?
  default_input_device(Self) -> @spec.Device?
  default_output_device(Self) -> @spec.Device?
  input_devices(Self) -> Array[@spec.Device] raise @core.DevicesError
  output_devices(Self) -> Array[@spec.Device] raise @core.DevicesError
}

///|
pub trait DeviceTrait {
  name(Self) -> String raise @core.DeviceNameError
  id(Self) -> @core.DeviceId raise @core.DeviceIdError
  description(Self) -> @core.DeviceDescription raise @core.DeviceNameError
  supports_input(Self) -> Bool
  supports_output(Self) -> Bool
  supported_input_configs(Self) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError
  supported_output_configs(Self) -> Array[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError
  default_input_config(Self) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError
  default_output_config(Self) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError
  build_input_stream(
    Self,
    @core.StreamConfig,
    (@spec.Data, @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_input_stream_raw(
    Self,
    @core.StreamConfig,
    @core.SampleFormat,
    (@spec.Data, @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_output_stream(
    Self,
    @core.StreamConfig,
    (@spec.Data, @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_output_stream_raw(
    Self,
    @core.StreamConfig,
    @core.SampleFormat,
    (@spec.Data, @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_output_stream_f32(
    Self,
    @core.StreamConfig,
    (Array[Float], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_output_stream_i16(
    Self,
    @core.StreamConfig,
    (Array[Int16], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_output_stream_u16(
    Self,
    @core.StreamConfig,
    (Array[UInt16], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_output_stream_u8(
    Self,
    @core.StreamConfig,
    (Array[Byte], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_input_stream_f32(
    Self,
    @core.StreamConfig,
    (Array[Float], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_input_stream_i16(
    Self,
    @core.StreamConfig,
    (Array[Int16], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_input_stream_u16(
    Self,
    @core.StreamConfig,
    (Array[UInt16], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  build_input_stream_u8(
    Self,
    @core.StreamConfig,
    (Array[Byte], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
}

///|
pub trait StreamTrait {
  play(Self) -> Unit raise @core.PlayStreamError
  pause(Self) -> Unit raise @core.PauseStreamError
  close(Self) -> Unit
}

///|
pub impl HostTrait for @spec.Host with devices(self : @spec.Host) {
  self.devices()
}

///|
pub impl HostTrait for @spec.Host with device_by_id(
  self : @spec.Host,
  id : @core.DeviceId,
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
  config : @core.StreamConfig,
  data_callback : (@spec.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_raw(
  self : @spec.Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@spec.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_raw(
    config, sample_format, data_callback, error_callback, timeout,
  )
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (@spec.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_raw(
  self : @spec.Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (@spec.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_raw(
    config, sample_format, data_callback, error_callback, timeout,
  )
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_f32(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_f32(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_i16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_i16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_u16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_u16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_output_stream_u8(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_u8(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_f32(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_f32(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_i16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_i16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_u16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_u16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with build_input_stream_u8(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
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
