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
/// Implementation of the declaration-only API in `spec.mbt`.
///
/// This is the "real" end-to-end CPAL-like API surface for the MoonBit port.
/// It is implemented as a thin wrapper around the `platform` dynamic dispatch types.

///|
pub struct Host {
  inner : @platform.Host
} derive(Show, Eq)

///|
pub struct Device {
  inner : @platform.Device
} derive(Show, Eq)

///|
pub struct Stream {
  inner : @platform.Stream
} derive(Show, Eq)

///|
pub struct Data {
  inner : @core.Data
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { inner: @platform.default_host() }
}

///|
pub fn available_hosts() -> Array[@core.HostId] {
  @platform.available_hosts()
}

///|
pub fn all_hosts() -> Array[@core.HostId] {
  @platform.all_hosts()
}

///|
pub fn host_from_id(id : @core.HostId) -> Host raise @core.HostUnavailable {
  { inner: @platform.host_from_id(id) }
}

///|
pub fn try_host_from_id(id : @core.HostId) -> Host? {
  @platform.try_host_from_id(id).map(fn(h) { { inner: h } })
}

///|
pub fn Host::id(self : Host) -> @core.HostId {
  @platform.Host::id(self.inner)
}

///|
pub fn Host::devices(self : Host) -> Iter[Device] raise @core.DevicesError {
  @platform.Host::devices(self.inner).map(fn(d) { { inner: d } })
}

///|
pub fn Host::device_by_id(self : Host, id : @core.DeviceId) -> Device? {
  match @platform.Host::device_by_id(self.inner, id) {
    None => None
    Some(d) => Some({ inner: d })
  }
}

///|
pub fn Host::input_devices(
  self : Host,
) -> Iter[Device] raise @core.DevicesError {
  @platform.Host::input_devices(self.inner).map(fn(d) { { inner: d } })
}

///|
pub fn Host::output_devices(
  self : Host,
) -> Iter[Device] raise @core.DevicesError {
  @platform.Host::output_devices(self.inner).map(fn(d) { { inner: d } })
}

///|
pub fn Host::default_output_device(self : Host) -> Device? {
  match @platform.Host::default_output_device(self.inner) {
    None => None
    Some(d) => Some({ inner: d })
  }
}

///|
pub fn Host::default_input_device(self : Host) -> Device? {
  match @platform.Host::default_input_device(self.inner) {
    None => None
    Some(d) => Some({ inner: d })
  }
}

///|
pub fn Device::name(self : Device) -> String raise @core.DeviceNameError {
  @platform.Device::name(self.inner)
}

///|
pub fn Device::id(self : Device) -> @core.DeviceId raise @core.DeviceIdError {
  @platform.Device::id(self.inner)
}

///|
pub fn Device::description(
  self : Device,
) -> @core.DeviceDescription raise @core.DeviceNameError {
  @platform.Device::description(self.inner)
}

///|
pub fn Device::supports_input(self : Device) -> Bool {
  @platform.Device::supports_input(self.inner)
}

///|
pub fn Device::supports_output(self : Device) -> Bool {
  @platform.Device::supports_output(self.inner)
}

///|
pub fn Device::supported_output_configs(
  self : Device,
) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  @platform.Device::supported_output_configs(self.inner)
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Iter[@core.SupportedStreamConfigRange] raise @core.SupportedStreamConfigsError {
  @platform.Device::supported_input_configs(self.inner)
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  @platform.Device::default_output_config(self.inner)
}

///|
pub fn Device::default_input_config(
  self : Device,
) -> @core.SupportedStreamConfig raise @core.DefaultStreamConfigError {
  @platform.Device::default_input_config(self.inner)
}

///|
pub fn Device::build_output_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_output_stream(
    self.inner,
    config,
    fn(d, info) { data_callback({ inner: d }, info) },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (Data, @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    sample_format,
    fn(d, info) { data_callback({ inner: d }, info) },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
fn make_f32_zeros(n : Int) -> Array[Float] {
  let out : Array[Float] = []
  let mut i = 0
  while i < n {
    out.push(0.0)
    i = i + 1
  }
  out
}

///|
fn fill_f32_zeros(xs : Array[Float]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = 0.0
    i = i + 1
  }
}

///|
fn make_i16_zeros(n : Int) -> Array[Int16] {
  let out : Array[Int16] = []
  let mut i = 0
  while i < n {
    out.push(Int16::from_int(0))
    i = i + 1
  }
  out
}

///|
fn fill_i16_zeros(xs : Array[Int16]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = Int16::from_int(0)
    i = i + 1
  }
}

///|
fn make_u16_zeros(n : Int) -> Array[UInt16] {
  let out : Array[UInt16] = []
  let mut i = 0
  while i < n {
    out.push(Int::to_uint16(0))
    i = i + 1
  }
  out
}

///|
fn fill_u16_zeros(xs : Array[UInt16]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = Int::to_uint16(0)
    i = i + 1
  }
}

///|
fn make_u8_zeros(n : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut i = 0
  while i < n {
    out.push(Int::to_byte(0))
    i = i + 1
  }
  out
}

///|
fn fill_u8_zeros(xs : Array[Byte]) -> Unit {
  let mut i = 0
  while i < xs.length() {
    xs[i] = Int::to_byte(0)
    i = i + 1
  }
}

///|
pub fn Device::build_output_stream_f32(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let mut scratch : Array[Float] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::F32,
    fn(d, info) {
      let n = @core.Data::len(d)
      if scratch.length() != n {
        scratch = make_f32_zeros(n)
      } else {
        fill_f32_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@core.Data::write_f32(d, scratch) {
        @core.Data::clear(d)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_output_stream_i16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let mut scratch : Array[Int16] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::I16,
    fn(d, info) {
      let n = @core.Data::len(d)
      if scratch.length() != n {
        scratch = make_i16_zeros(n)
      } else {
        fill_i16_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@core.Data::write_i16(d, scratch) {
        @core.Data::clear(d)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_output_stream_u16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let mut scratch : Array[UInt16] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::U16,
    fn(d, info) {
      let n = @core.Data::len(d)
      if scratch.length() != n {
        scratch = make_u16_zeros(n)
      } else {
        fill_u16_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@core.Data::write_u16(d, scratch) {
        @core.Data::clear(d)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_output_stream_u8(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.OutputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let mut scratch : Array[Byte] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::U8,
    fn(d, info) {
      let n = @core.Data::len(d)
      if scratch.length() != n {
        scratch = make_u8_zeros(n)
      } else {
        fill_u8_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@core.Data::write_u8(d, scratch) {
        @core.Data::clear(d)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_input_stream(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream(
    self.inner,
    config,
    fn(d, info) { data_callback({ inner: d }, info) },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @core.StreamConfig,
  sample_format : @core.SampleFormat,
  data_callback : (Data, @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    sample_format,
    fn(d, info) { data_callback({ inner: d }, info) },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_input_stream_f32(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Float], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::F32,
    fn(d, info) {
      match @core.Data::try_as_f32(d) {
        None => data_callback([], info)
        Some(xs) => data_callback(xs, info)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_input_stream_i16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Int16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::I16,
    fn(d, info) {
      match @core.Data::try_as_i16(d) {
        None => data_callback([], info)
        Some(xs) => data_callback(xs, info)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_input_stream_u16(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[UInt16], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::U16,
    fn(d, info) {
      match @core.Data::try_as_u16(d) {
        None => data_callback([], info)
        Some(xs) => data_callback(xs, info)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Device::build_input_stream_u8(
  self : Device,
  config : @core.StreamConfig,
  data_callback : (Array[Byte], @core.InputCallbackInfo) -> Unit,
  error_callback : (@core.StreamError) -> Unit,
  timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @core.SampleFormat::U8,
    fn(d, info) {
      match @core.Data::try_as_u8(d) {
        None => data_callback([], info)
        Some(xs) => data_callback(xs, info)
      }
    },
    error_callback,
    timeout,
  )
  { inner: inner_stream }
}

///|
pub fn Stream::play(self : Stream) -> Unit raise @core.PlayStreamError {
  @platform.Stream::play(self.inner)
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @core.PauseStreamError {
  @platform.Stream::pause(self.inner)
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  @platform.Stream::close(self.inner)
}

///|
pub fn Data::sample_format(self : Data) -> @core.SampleFormat {
  @core.Data::sample_format(self.inner)
}

///|
pub fn Data::len(self : Data) -> Int {
  @core.Data::len(self.inner)
}

///|
pub fn Data::bytes(self : Data) -> FixedArray[Byte] {
  @core.Data::bytes(self.inner)
}

///|
pub fn Data::try_as_u8(self : Data) -> Array[Byte]? {
  @core.Data::try_as_u8(self.inner)
}

///|
pub fn Data::try_as_u16(self : Data) -> Array[UInt16]? {
  @core.Data::try_as_u16(self.inner)
}

///|
pub fn Data::try_as_i16(self : Data) -> Array[Int16]? {
  @core.Data::try_as_i16(self.inner)
}

///|
pub fn Data::try_as_f32(self : Data) -> Array[Float]? {
  @core.Data::try_as_f32(self.inner)
}

///|
pub fn Data::clear(self : Data) -> Unit {
  @core.Data::clear(self.inner)
}

///|
pub fn Data::write_u8(self : Data, samples : Array[Byte]) -> Bool {
  @core.Data::write_u8(self.inner, samples)
}

///|
pub fn Data::write_u16(self : Data, samples : Array[UInt16]) -> Bool {
  @core.Data::write_u16(self.inner, samples)
}

///|
pub fn Data::write_i16(self : Data, samples : Array[Int16]) -> Bool {
  @core.Data::write_i16(self.inner, samples)
}

///|
pub fn Data::write_f32(self : Data, samples : Array[Float]) -> Bool {
  @core.Data::write_f32(self.inner, samples)
}
