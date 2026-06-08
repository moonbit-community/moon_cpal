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
/// Root `moonbit-community/moon_cpal` public API (native-only).
///
/// Mirrors upstream `cpal::lib.rs` re-exports:
/// - core types/errors live in `moonbit-community/moon_cpal/core`
/// - dynamic dispatch host/device/stream live in `moonbit-community/moon_cpal/platform`
/// - CPAL-like traits live in `moonbit-community/moon_cpal/traits`

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
pub type DeviceDescriptionBuilder = @core.DeviceDescriptionBuilder

///|
pub type DeviceDirection = @core.DeviceDirection

///|
pub type DeviceType = @core.DeviceType

///|
pub type InterfaceType = @core.InterfaceType

///|
pub type ChannelCount = @core.ChannelCount

///|
pub type SampleRate = @core.SampleRate

///|
pub type FrameCount = @core.FrameCount

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
/// Iterator types (upstream exports named iterator structs; here we expose `Iter` aliases).
pub type Devices = Iter[Device]

///|
/// Iterator of devices wrapped in a filter (upstream: `DevicesFiltered`).
pub type DevicesFiltered[A] = Iter[A]

///|
/// A host's device iterator yielding only *input* devices (upstream: `InputDevices`).
pub type InputDevices[A] = DevicesFiltered[A]

///|
/// A host's device iterator yielding only *output* devices (upstream: `OutputDevices`).
pub type OutputDevices[A] = DevicesFiltered[A]

///|
pub type SupportedInputConfigs = Iter[SupportedStreamConfigRange]

///|
pub type SupportedOutputConfigs = Iter[SupportedStreamConfigRange]

///|
/// Sample and conversion traits/types (from `samples_formats.rs` in upstream).
pub using @core {trait Sample, trait SizedSample, trait FromSample}

///|
pub type I24 = @core.I24

///|
pub type U24 = @core.U24

///|
/// CPAL-like trait surface (from `traits.rs` in upstream).
pub using @traits {trait HostTrait, trait DeviceTrait, trait StreamTrait}

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

///|
/// Re-export of upstream-like sample conversion helper.
pub fn[A : Sample, B : Sample] sample_cast(x : A) -> B {
  @core.sample_cast(x)
}

///|
/// Re-export of CPAL common sample rates table.
pub fn common_sample_rates() -> Array[SampleRate] {
  @core.common_sample_rates()
}
