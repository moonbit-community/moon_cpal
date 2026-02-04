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
pub fn host_from_id(
  id : @moon_cpal.HostId,
) -> Host raise @moon_cpal.HostUnavailable {
  { inner: @platform.host_from_id(id) }
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
pub fn Host::default_output_device(
  self : Host,
) -> Device? raise @moon_cpal.DevicesError {
  match @platform.Host::default_output_device(self.inner) {
    None => None
    Some(d) => Some({ inner: d })
  }
}

///|
pub fn Host::default_input_device(
  self : Host,
) -> Device? raise @moon_cpal.DevicesError {
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
