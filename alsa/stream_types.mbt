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
/// ALSA stream types (Linux).
///
/// Implementations are split by target:
/// - `stream_native.mbt` (native): real ALSA I/O via libasound.
/// - `stream.mbt`        (non-native): stubs.

///|
pub enum StreamKind {
  Output
  Input
} derive(Debug, Eq)

///|
// An external object that owns native stream resources.
//
// On native targets this is backed by `moonbit_make_external_object` with a finalizer.
// On non-native targets it is an opaque stub value.
type StreamOwner

///|
pub struct Stream {
  kind : StreamKind
  handle : UInt64
  owner : StreamOwner
}

///|
pub impl Eq for Stream with equal(self : Stream, other : Stream) -> Bool {
  self.kind == other.kind && self.handle == other.handle
}

///|
pub impl @debug.Debug for Stream with to_repr(self : Stream) -> @debug.Repr {
  @debug.Debug::to_repr((self.kind, self.handle))
}

///|
pub impl Show for Stream with output(self : Stream, logger : &Logger) -> Unit {
  logger.write_string("\{self.kind}(\{self.handle})")
}
