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
/// Timestamp types associated with stream data callbacks.
///
/// Ported from upstream `cpal`'s `InputStreamTimestamp`, `OutputStreamTimestamp`,
/// `InputCallbackInfo`, and `OutputCallbackInfo`.

///|
/// A timestamp associated with a call to an input stream's data callback.
pub struct InputStreamTimestamp {
  callback : StreamInstant
  capture : StreamInstant
} derive(Show, Eq)

///|
pub fn InputStreamTimestamp::new(
  callback : StreamInstant,
  capture : StreamInstant,
) -> InputStreamTimestamp {
  { callback, capture }
}

///|
pub fn InputStreamTimestamp::callback(
  self : InputStreamTimestamp,
) -> StreamInstant {
  self.callback
}

///|
pub fn InputStreamTimestamp::capture(
  self : InputStreamTimestamp,
) -> StreamInstant {
  self.capture
}

///|
/// A timestamp associated with a call to an output stream's data callback.
pub struct OutputStreamTimestamp {
  callback : StreamInstant
  playback : StreamInstant
} derive(Show, Eq)

///|
pub fn OutputStreamTimestamp::new(
  callback : StreamInstant,
  playback : StreamInstant,
) -> OutputStreamTimestamp {
  { callback, playback }
}

///|
pub fn OutputStreamTimestamp::callback(
  self : OutputStreamTimestamp,
) -> StreamInstant {
  self.callback
}

///|
pub fn OutputStreamTimestamp::playback(
  self : OutputStreamTimestamp,
) -> StreamInstant {
  self.playback
}

///|
/// Information relevant to a single call to the user's input stream data callback.
pub struct InputCallbackInfo {
  timestamp : InputStreamTimestamp
} derive(Show, Eq)

///|
pub fn InputCallbackInfo::new(
  timestamp : InputStreamTimestamp,
) -> InputCallbackInfo {
  { timestamp, }
}

///|
pub fn InputCallbackInfo::timestamp(
  self : InputCallbackInfo,
) -> InputStreamTimestamp {
  self.timestamp
}

///|
/// Information relevant to a single call to the user's output stream data callback.
pub struct OutputCallbackInfo {
  timestamp : OutputStreamTimestamp
} derive(Show, Eq)

///|
pub fn OutputCallbackInfo::new(
  timestamp : OutputStreamTimestamp,
) -> OutputCallbackInfo {
  { timestamp, }
}

///|
pub fn OutputCallbackInfo::timestamp(
  self : OutputCallbackInfo,
) -> OutputStreamTimestamp {
  self.timestamp
}
