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
  inner : @moon_cpal.Data
} derive(Show, Eq)

///|
pub fn default_host() -> Host {
  { inner: @platform.default_host() }
}

///|
pub fn available_hosts() -> Array[@moon_cpal.HostId] {
  @platform.available_hosts()
}

///|
pub fn all_hosts() -> Array[@moon_cpal.HostId] {
  @platform.all_hosts()
}

///|
pub fn host_from_id(
  id : @moon_cpal.HostId,
) -> Host raise @moon_cpal.HostUnavailable {
  { inner: @platform.host_from_id(id) }
}

///|
pub fn try_host_from_id(id : @moon_cpal.HostId) -> Host? {
  @platform.try_host_from_id(id).map(fn(h) { { inner: h } })
}

///|
pub fn Host::id(self : Host) -> @moon_cpal.HostId {
  @platform.Host::id(self.inner)
}

///|
pub fn Host::devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  @platform.Host::devices(self.inner).map(fn(d) { { inner: d } })
}

///|
pub fn Host::device_by_id(self : Host, id : @moon_cpal.DeviceId) -> Device? {
  match @platform.Host::device_by_id(self.inner, id) {
    None => None
    Some(d) => Some({ inner: d })
  }
}

///|
pub fn Host::input_devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  @platform.Host::input_devices(self.inner).map(fn(d) { { inner: d } })
}

///|
pub fn Host::output_devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
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
pub fn Device::name(self : Device) -> String raise @moon_cpal.DeviceNameError {
  @platform.Device::name(self.inner)
}

///|
pub fn Device::id(
  self : Device,
) -> @moon_cpal.DeviceId raise @moon_cpal.DeviceIdError {
  @platform.Device::id(self.inner)
}

///|
pub fn Device::description(
  self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
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
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  @platform.Device::supported_output_configs(self.inner)
}

///|
pub fn Device::supported_input_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  @platform.Device::supported_input_configs(self.inner)
}

///|
pub fn Device::default_output_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  @platform.Device::default_output_config(self.inner)
}

///|
pub fn Device::default_input_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  @platform.Device::default_input_config(self.inner)
}

///|
pub fn Device::build_output_stream(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Float], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let mut scratch : Array[Float] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::F32,
    fn(d, info) {
      let n = @moon_cpal.Data::len(d)
      if scratch.length() != n {
        scratch = make_f32_zeros(n)
      } else {
        fill_f32_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@moon_cpal.Data::write_f32(d, scratch) {
        @moon_cpal.Data::clear(d)
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Int16], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let mut scratch : Array[Int16] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::I16,
    fn(d, info) {
      let n = @moon_cpal.Data::len(d)
      if scratch.length() != n {
        scratch = make_i16_zeros(n)
      } else {
        fill_i16_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@moon_cpal.Data::write_i16(d, scratch) {
        @moon_cpal.Data::clear(d)
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[UInt16], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let mut scratch : Array[UInt16] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::U16,
    fn(d, info) {
      let n = @moon_cpal.Data::len(d)
      if scratch.length() != n {
        scratch = make_u16_zeros(n)
      } else {
        fill_u16_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@moon_cpal.Data::write_u16(d, scratch) {
        @moon_cpal.Data::clear(d)
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Byte], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let mut scratch : Array[Byte] = []
  let inner_stream = @platform.Device::build_output_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::U8,
    fn(d, info) {
      let n = @moon_cpal.Data::len(d)
      if scratch.length() != n {
        scratch = make_u8_zeros(n)
      } else {
        fill_u8_zeros(scratch)
      }
      data_callback(scratch, info)
      if !@moon_cpal.Data::write_u8(d, scratch) {
        @moon_cpal.Data::clear(d)
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Float], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::F32,
    fn(d, info) {
      match @moon_cpal.Data::try_as_f32(d) {
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Int16], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::I16,
    fn(d, info) {
      match @moon_cpal.Data::try_as_i16(d) {
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[UInt16], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::U16,
    fn(d, info) {
      match @moon_cpal.Data::try_as_u16(d) {
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
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Byte], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  let inner_stream = @platform.Device::build_input_stream_raw(
    self.inner,
    config,
    @moon_cpal.SampleFormat::U8,
    fn(d, info) {
      match @moon_cpal.Data::try_as_u8(d) {
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
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  @platform.Stream::play(self.inner)
}

///|
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  @platform.Stream::pause(self.inner)
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  @platform.Stream::close(self.inner)
}

///|
pub fn Data::sample_format(self : Data) -> @moon_cpal.SampleFormat {
  @moon_cpal.Data::sample_format(self.inner)
}

///|
pub fn Data::len(self : Data) -> Int {
  @moon_cpal.Data::len(self.inner)
}

///|
pub fn Data::bytes(self : Data) -> FixedArray[Byte] {
  @moon_cpal.Data::bytes(self.inner)
}

///|
pub fn Data::try_as_u8(self : Data) -> Array[Byte]? {
  @moon_cpal.Data::try_as_u8(self.inner)
}

///|
pub fn Data::try_as_u16(self : Data) -> Array[UInt16]? {
  @moon_cpal.Data::try_as_u16(self.inner)
}

///|
pub fn Data::try_as_i16(self : Data) -> Array[Int16]? {
  @moon_cpal.Data::try_as_i16(self.inner)
}

///|
pub fn Data::try_as_f32(self : Data) -> Array[Float]? {
  @moon_cpal.Data::try_as_f32(self.inner)
}

///|
pub fn Data::clear(self : Data) -> Unit {
  @moon_cpal.Data::clear(self.inner)
}

///|
pub fn Data::write_u8(self : Data, samples : Array[Byte]) -> Bool {
  @moon_cpal.Data::write_u8(self.inner, samples)
}

///|
pub fn Data::write_u16(self : Data, samples : Array[UInt16]) -> Bool {
  @moon_cpal.Data::write_u16(self.inner, samples)
}

///|
pub fn Data::write_i16(self : Data, samples : Array[Int16]) -> Bool {
  @moon_cpal.Data::write_i16(self.inner, samples)
}

///|
pub fn Data::write_f32(self : Data, samples : Array[Float]) -> Bool {
  @moon_cpal.Data::write_f32(self.inner, samples)
}
