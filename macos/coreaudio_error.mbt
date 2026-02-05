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
pub suberror CoreAudioError {
  CoreAudioError(String, Int)
  DeviceNotAvailable(String, Int)
}

///|
fn[A] raise_osstatus(op : String, status : Int) -> A raise CoreAudioError {
  match osstatus_kind(status) {
    1 => raise CoreAudioError::DeviceNotAvailable(op, status)
    _ => raise CoreAudioError(op, status)
  }
}

///|
fn[A] raise_default_osstatus(
  op : String,
  status : Int,
) -> A raise @core.DefaultStreamConfigError {
  match osstatus_kind(status) {
    1 => raise @core.default_stream_config_error_device_not_available()
    2 => raise @core.default_stream_config_error_stream_type_not_supported()
    _ =>
      raise @core.default_stream_config_error_backend_specific(
        "\{op} (OSStatus \{status})",
      )
  }
}
