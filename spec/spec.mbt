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
/// CPAL API spec (declaration-only).
///
/// This package defines the intended end-to-end public API surface for the MoonBit port of
/// RustAudio/cpal. It is **not** an implementation. Use it as a contract when incrementally
/// implementing full stream I/O and backend support.

///|
#declaration_only
pub type Host

///|
#declaration_only
pub type Device

///|
#declaration_only
pub type Stream

///|
#declaration_only
pub type Data

///|
#declaration_only
pub fn default_host() -> Host {
  ...
}

///|
#declaration_only
pub fn available_hosts() -> Array[@core.HostId] {
  ...
}

///|
#declaration_only
pub fn all_hosts() -> Array[@core.HostId] {
  ...
}

///|
#declaration_only
pub fn host_from_id(id : @core.HostId) -> Host raise @core.HostUnavailable {
  ...
}

///|
#declaration_only
pub fn try_host_from_id(id : @core.HostId) -> Host? {
  ...
}

///|
#declaration_only
pub fn Host::id(self : Host) -> @core.HostId {
  ...
}

///|
#declaration_only
pub fn Host::devices(self : Host) -> Iter[Device] raise @core.DevicesError {
  ...
}

///|
#declaration_only
pub fn Host::device_by_id(self : Host, id : @core.DeviceId) -> Device? {
  ...
}

///|
#declaration_only
pub fn Host::input_devices(
  self : Host,
) -> Iter[Device] raise @core.DevicesError {
  ...
}

///|
#declaration_only
pub fn Host::output_devices(
  self : Host,
) -> Iter[Device] raise @core.DevicesError {
  ...
}

///|
#declaration_only
pub fn Host::default_output_device(self : Host) -> Device? {
  ...
}

///|
#declaration_only
pub fn Host::default_input_device(self : Host) -> Device? {
  ...
}

///|
#declaration_only
pub fn Device::name(self : Device) -> String raise @core.DeviceNameError {
  ...
}

///|
#declaration_only
pub fn Device::id(self : Device) -> @core.DeviceId raise @core.DeviceIdError {
  ...
}

///|
#declaration_only
pub fn Device::description(
  self : Device,
) -> @core.DeviceDescription raise @core.DeviceNameError {
  ...
}

///|
#declaration_only
pub fn Device::supports_input(self : Device) -> Bool {
  ...
}

///|
#declaration_only
pub fn Device::supports_output(self : Device) -> Bool {
  ...
}

///|
#declaration_only
pub fn Device::supported_output_configs(
  self : Device,
) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  ...
}

///|
#declaration_only
pub fn Device::supported_input_configs(
  self : Device,
) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  ...
}

///|
#declaration_only
pub fn Device::default_output_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  ...
}

///|
#declaration_only
pub fn Device::default_input_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_f32(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_i16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_u16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_u8(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_f32(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_i16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_u16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_u8(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  ...
}

///|
#declaration_only
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  ...
}

///|
#declaration_only
pub fn Stream::close(self : Stream) -> Unit {
  ...
}

///|
#declaration_only
pub fn Data::sample_format(self : Data) -> @core.SampleFormat {
  ...
}

///|
#declaration_only
pub fn Data::len(self : Data) -> Int {
  ...
}

///|
#declaration_only
pub fn Data::bytes(self : Data) -> FixedArray[Byte] {
  ...
}

///|
#declaration_only
pub fn Data::try_as_u8(self : Data) -> Array[Byte]? {
  ...
}

///|
#declaration_only
pub fn Data::try_as_u16(self : Data) -> Array[UInt16]? {
  ...
}

///|
#declaration_only
pub fn Data::try_as_i16(self : Data) -> Array[Int16]? {
  ...
}

///|
#declaration_only
pub fn Data::try_as_f32(self : Data) -> Array[Float]? {
  ...
}

///|
#declaration_only
pub fn Data::clear(self : Data) -> Unit {
  ...
}

///|
#declaration_only
pub fn Data::write_u8(self : Data, samples : Array[Byte]) -> Bool {
  ...
}

///|
#declaration_only
pub fn Data::write_u16(self : Data, samples : Array[UInt16]) -> Bool {
  ...
}

///|
#declaration_only
pub fn Data::write_i16(self : Data, samples : Array[Int16]) -> Bool {
  ...
}

///|
#declaration_only
pub fn Data::write_f32(self : Data, samples : Array[Float]) -> Bool {
  ...
}
