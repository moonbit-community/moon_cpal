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
/// Backward-compatibility `Show` impls after `derive(Show)` deprecation.
///
/// We keep source-level derives on `Debug` and manually expose `Show` for API and tests.

///|
fn[T : @debug.Debug] show_from_debug(value : T, logger : &Logger) -> Unit {
  let rendered = @debug.render(@debug.Debug::to_repr(value))
  logger.write_string(
    rendered.replace_all(old="{ ", new="{").replace_all(old=" }", new="}"),
  )
}

///|
pub impl Show for NativeOs with output(self : NativeOs, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for I24 with output(self : I24, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for U24 with output(self : U24, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for Duration with output(self : Duration, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for StreamInstant with output(
  self : StreamInstant,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for InputStreamTimestamp with output(
  self : InputStreamTimestamp,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for OutputStreamTimestamp with output(
  self : OutputStreamTimestamp,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for InputCallbackInfo with output(
  self : InputCallbackInfo,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for OutputCallbackInfo with output(
  self : OutputCallbackInfo,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceType with output(self : DeviceType, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for InterfaceType with output(
  self : InterfaceType,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceDirection with output(
  self : DeviceDirection,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceDescription with output(
  self : DeviceDescription,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceDescriptionBuilder with output(
  self : DeviceDescriptionBuilder,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for BackendSpecificError with output(
  self : BackendSpecificError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DefaultStreamConfigError with output(
  self : DefaultStreamConfigError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for SupportedStreamConfigsError with output(
  self : SupportedStreamConfigsError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DevicesError with output(
  self : DevicesError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceNameError with output(
  self : DeviceNameError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for BuildStreamError with output(
  self : BuildStreamError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for PlayStreamError with output(
  self : PlayStreamError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for PauseStreamError with output(
  self : PauseStreamError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for StreamError with output(self : StreamError, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for Data with output(self : Data, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceIdError with output(
  self : DeviceIdError,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for DeviceId with output(self : DeviceId, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for HostUnavailable with output(
  self : HostUnavailable,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for HostId with output(self : HostId, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for BufferSize with output(self : BufferSize, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for StreamConfig with output(
  self : StreamConfig,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for SupportedBufferSize with output(
  self : SupportedBufferSize,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for SampleFormat with output(
  self : SampleFormat,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for SupportedStreamConfig with output(
  self : SupportedStreamConfig,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for SupportedStreamConfigRange with output(
  self : SupportedStreamConfigRange,
  logger : &Logger,
) -> Unit {
  show_from_debug(self, logger)
}
