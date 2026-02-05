///|
/// Root `Milky2018/moon_cpal` public API (native-only).
///
/// Mirrors upstream `cpal::lib.rs` re-exports:
/// - core types/errors live in `Milky2018/moon_cpal/core`
/// - dynamic dispatch host/device/stream live in `Milky2018/moon_cpal/platform`

///|
pub type HostId = @core.HostId

///|
pub type DeviceId = @core.DeviceId

///|
pub type DeviceIdError = @core.DeviceIdError

///|
pub type BackendSpecificError = @core.BackendSpecificError

///|
pub type DevicesError = @core.DevicesError

///|
pub type DeviceNameError = @core.DeviceNameError

///|
pub type SupportedStreamConfigsError = @core.SupportedStreamConfigsError

///|
pub type DefaultStreamConfigError = @core.DefaultStreamConfigError

///|
pub type BuildStreamError = @core.BuildStreamError

///|
pub type PlayStreamError = @core.PlayStreamError

///|
pub type PauseStreamError = @core.PauseStreamError

///|
pub type StreamError = @core.StreamError

///|
pub type BufferSize = @core.BufferSize

///|
pub type SupportedBufferSize = @core.SupportedBufferSize

///|
pub type StreamConfig = @core.StreamConfig

///|
pub type SupportedStreamConfig = @core.SupportedStreamConfig

///|
pub type SupportedStreamConfigRange = @core.SupportedStreamConfigRange

///|
pub type SampleFormat = @core.SampleFormat

///|
pub type StreamInstant = @core.StreamInstant

///|
pub type Duration = @core.Duration

///|
pub type InputStreamTimestamp = @core.InputStreamTimestamp

///|
pub type OutputStreamTimestamp = @core.OutputStreamTimestamp

///|
pub type InputCallbackInfo = @core.InputCallbackInfo

///|
pub type OutputCallbackInfo = @core.OutputCallbackInfo

///|
pub type DeviceDescription = @core.DeviceDescription

///|
pub type DeviceDirection = @core.DeviceDirection

///|
pub type DeviceType = @core.DeviceType

///|
pub type InterfaceType = @core.InterfaceType

///|
pub type HostUnavailable = @core.HostUnavailable

///|
pub type Host = @spec.Host

///|
pub type Device = @spec.Device

///|
pub type Stream = @spec.Stream

///|
pub type Data = @spec.Data

///|
pub fn available_hosts() -> Array[HostId] {
  @spec.available_hosts()
}

///|
pub fn default_host() -> Host {
  @spec.default_host()
}

///|
pub fn host_from_id(id : HostId) -> Host raise @core.HostUnavailable {
  @spec.host_from_id(id)
}

///|
pub fn try_host_from_id(id : HostId) -> Host? {
  @spec.try_host_from_id(id)
}

///|
pub fn all_hosts() -> Array[HostId] {
  @spec.all_hosts()
}
