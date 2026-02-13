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
/// Null device stream builders.
///
/// Upstream null backend uses `unimplemented!()` for stream building and supported config queries.
/// In MoonBit we represent this as backend-specific errors.

///|
pub fn Device::build_output_stream(
  _self : Device,
  _config : @core.StreamConfig,
  _data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_output_stream: unimplemented",
  )
}

///|
pub fn Device::build_output_stream_raw(
  _self : Device,
  _config : @core.StreamConfig,
  _sample_format : @core.SampleFormat,
  _data_callback : (@core.Data, @core.OutputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_output_stream_raw: unimplemented",
  )
}

///|
pub fn Device::build_input_stream(
  _self : Device,
  _config : @core.StreamConfig,
  _data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_input_stream: unimplemented",
  )
}

///|
pub fn Device::build_input_stream_raw(
  _self : Device,
  _config : @core.StreamConfig,
  _sample_format : @core.SampleFormat,
  _data_callback : (@core.Data, @core.InputCallbackInfo) -> Unit,
  _error_callback : (@core.StreamError) -> Unit,
  _timeout : @core.Duration?,
) -> Stream raise @core.BuildStreamError {
  raise @core.build_stream_error_backend_specific(
    "null build_input_stream_raw: unimplemented",
  )
}
