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
  fn devices(Self) -> Iter[@spec.Device] raise @core.DevicesError
  fn device_by_id(Self, @core.DeviceId) -> @spec.Device?
  fn default_input_device(Self) -> @spec.Device?
  fn default_output_device(Self) -> @spec.Device?
  fn input_devices(Self) -> Iter[@spec.Device] raise @core.DevicesError
  fn output_devices(Self) -> Iter[@spec.Device] raise @core.DevicesError
}

///|
pub trait DeviceTrait {
  fn name(Self) -> String raise @core.DeviceNameError
  fn id(Self) -> @core.DeviceId raise @core.DeviceIdError
  fn description(Self) -> @core.DeviceDescription raise @core.DeviceNameError
  fn supports_input(Self) -> Bool
  fn supports_output(Self) -> Bool
  fn supported_input_configs(Self) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError
  fn supported_output_configs(Self) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError
  fn default_input_config(Self) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError
  fn default_output_config(Self) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError
  fn build_input_stream(
    Self,
    @core.StreamConfig,
    (@spec.Data, @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_input_stream_raw(
    Self,
    @core.StreamConfig,
    @core.SampleFormat,
    (@spec.Data, @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_output_stream(
    Self,
    @core.StreamConfig,
    (@spec.Data, @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_output_stream_raw(
    Self,
    @core.StreamConfig,
    @core.SampleFormat,
    (@spec.Data, @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_output_stream_f32(
    Self,
    @core.StreamConfig,
    (Array[Float], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_output_stream_i16(
    Self,
    @core.StreamConfig,
    (Array[Int16], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_output_stream_u16(
    Self,
    @core.StreamConfig,
    (Array[UInt16], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_output_stream_u8(
    Self,
    @core.StreamConfig,
    (Array[Byte], @core.OutputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_input_stream_f32(
    Self,
    @core.StreamConfig,
    (Array[Float], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_input_stream_i16(
    Self,
    @core.StreamConfig,
    (Array[Int16], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_input_stream_u16(
    Self,
    @core.StreamConfig,
    (Array[UInt16], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
  fn build_input_stream_u8(
    Self,
    @core.StreamConfig,
    (Array[Byte], @core.InputCallbackInfo) -> Unit,
    (@core.StreamError) -> Unit,
    @core.Duration?,
  ) -> @spec.Stream raise @core.BuildStreamError
}

///|
pub trait StreamTrait {
  fn play(Self) -> Unit raise @core.PlayStreamError
  fn pause(Self) -> Unit raise @core.PauseStreamError
  fn close(Self) -> Unit
}

///|
pub impl HostTrait for @spec.Host with fn devices(self : @spec.Host) {
  self.devices()
}

///|
pub impl HostTrait for @spec.Host with fn device_by_id(
  self : @spec.Host,
  id : @core.DeviceId,
) {
  self.device_by_id(id)
}

///|
pub impl HostTrait for @spec.Host with fn default_input_device(
  self : @spec.Host,
) {
  self.default_input_device()
}

///|
pub impl HostTrait for @spec.Host with fn default_output_device(
  self : @spec.Host,
) {
  self.default_output_device()
}

///|
pub impl HostTrait for @spec.Host with fn input_devices(self : @spec.Host) {
  self.input_devices()
}

///|
pub impl HostTrait for @spec.Host with fn output_devices(self : @spec.Host) {
  self.output_devices()
}

///|
pub impl DeviceTrait for @spec.Device with fn name(self : @spec.Device) {
  self.name()
}

///|
pub impl DeviceTrait for @spec.Device with fn id(self : @spec.Device) {
  self.id()
}

///|
pub impl DeviceTrait for @spec.Device with fn description(self : @spec.Device) {
  self.description()
}

///|
pub impl DeviceTrait for @spec.Device with fn supports_input(
  self : @spec.Device,
) {
  self.supports_input()
}

///|
pub impl DeviceTrait for @spec.Device with fn supports_output(
  self : @spec.Device,
) {
  self.supports_output()
}

///|
pub impl DeviceTrait for @spec.Device with fn supported_input_configs(
  self : @spec.Device,
) {
  self.supported_input_configs()
}

///|
pub impl DeviceTrait for @spec.Device with fn supported_output_configs(
  self : @spec.Device,
) {
  self.supported_output_configs()
}

///|
pub impl DeviceTrait for @spec.Device with fn default_input_config(
  self : @spec.Device,
) {
  self.default_input_config()
}

///|
pub impl DeviceTrait for @spec.Device with fn default_output_config(
  self : @spec.Device,
) {
  self.default_output_config()
}

///|
pub impl DeviceTrait for @spec.Device with fn build_input_stream(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (@spec.Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_input_stream_raw(
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
pub impl DeviceTrait for @spec.Device with fn build_output_stream(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (@spec.Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_output_stream_raw(
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
pub impl DeviceTrait for @spec.Device with fn build_output_stream_f32(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_f32(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_output_stream_i16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_i16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_output_stream_u16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_u16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_output_stream_u8(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_output_stream_u8(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_input_stream_f32(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_f32(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_input_stream_i16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_i16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_input_stream_u16(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_u16(config, data_callback, error_callback, timeout)
}

///|
pub impl DeviceTrait for @spec.Device with fn build_input_stream_u8(
  self : @spec.Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) {
  self.build_input_stream_u8(config, data_callback, error_callback, timeout)
}

///|
pub impl StreamTrait for @spec.Stream with fn play(self : @spec.Stream) {
  self.play()
}

///|
pub impl StreamTrait for @spec.Stream with fn pause(self : @spec.Stream) {
  self.pause()
}

///|
pub impl StreamTrait for @spec.Stream with fn close(self : @spec.Stream) {
  self.close()
}
