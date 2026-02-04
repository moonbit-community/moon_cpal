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
pub fn host_from_id(
  id : @moon_cpal.HostId,
) -> Host raise @moon_cpal.HostUnavailable {
  ...
}

///|
#declaration_only
pub fn Host::id(self : Host) -> @moon_cpal.HostId {
  ...
}

///|
#declaration_only
pub fn Host::devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  ...
}

///|
#declaration_only
pub fn Host::device_by_id(self : Host, id : @moon_cpal.DeviceId) -> Device? {
  ...
}

///|
#declaration_only
pub fn Host::input_devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
  ...
}

///|
#declaration_only
pub fn Host::output_devices(
  self : Host,
) -> Array[Device] raise @moon_cpal.DevicesError {
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
pub fn Device::name(self : Device) -> String raise @moon_cpal.DeviceNameError {
  ...
}

///|
#declaration_only
pub fn Device::id(self : Device) -> @moon_cpal.DeviceId {
  ...
}

///|
#declaration_only
pub fn Device::description(
  self : Device,
) -> @moon_cpal.DeviceDescription raise @moon_cpal.DeviceNameError {
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
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  ...
}

///|
#declaration_only
pub fn Device::supported_input_configs(
  self : Device,
) -> Array[@moon_cpal.SupportedStreamConfigRange] raise @moon_cpal.SupportedStreamConfigsError {
  ...
}

///|
#declaration_only
pub fn Device::default_output_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  ...
}

///|
#declaration_only
pub fn Device::default_input_config(
  self : Device,
) -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_raw(
  self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (Data, @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_f32(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Float], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_i16(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Int16], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_u16(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[UInt16], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_output_stream_u8(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Byte], @moon_cpal.OutputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_raw(
  self : Device,
  config : @moon_cpal.StreamConfig,
  sample_format : @moon_cpal.SampleFormat,
  data_callback : (Data, @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_f32(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Float], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_i16(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Int16], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_u16(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[UInt16], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Device::build_input_stream_u8(
  self : Device,
  config : @moon_cpal.StreamConfig,
  data_callback : (Array[Byte], @moon_cpal.InputCallbackInfo) -> Unit,
  error_callback : (@moon_cpal.StreamError) -> Unit,
  timeout : @moon_cpal.Duration?,
) -> Stream raise @moon_cpal.BuildStreamError {
  ...
}

///|
#declaration_only
pub fn Stream::play(self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  ...
}

///|
#declaration_only
pub fn Stream::pause(self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  ...
}

///|
#declaration_only
pub fn Stream::close(self : Stream) -> Unit {
  ...
}

///|
#declaration_only
pub fn Data::sample_format(self : Data) -> @moon_cpal.SampleFormat {
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
