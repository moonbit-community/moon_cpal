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
/// Null stream type.
///
/// This mirrors upstream `cpal::host::null::Stream`, which cannot be played/paused.

///|
pub struct Stream {
  _unit : Unit
} derive(Debug, Eq)

///|
let _unused_stream_for_lint : Stream = { _unit: () }

///|
pub fn Stream::play(_self : Stream) -> Unit raise @core.PlayStreamError {
  raise @core.play_stream_error_backend_specific(
    "null stream play: unimplemented",
  )
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @core.PauseStreamError {
  raise @core.pause_stream_error_backend_specific(
    "null stream pause: unimplemented",
  )
}

///|
pub fn Stream::close(_self : Stream) -> Unit {
  ()
}
