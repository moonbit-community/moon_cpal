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
/// WASAPI stream types (Windows).
///
/// Implementations are split by target:
/// - `stream_native.mbt` (native): real WASAPI I/O.
/// - `stream.mbt`        (non-native): stubs.

///|
pub enum StreamKind {
  Output
  Input
} derive(Debug, Eq)

///|
// An external object that owns native stream resources.
type StreamOwner

///|
pub struct Stream {
  kind : StreamKind
  handle : UInt64
  owner : StreamOwner
}

///|
pub impl Eq for Stream with fn equal(self : Stream, other : Stream) -> Bool {
  self.kind == other.kind && self.handle == other.handle
}

///|
pub impl @debug.Debug for Stream with fn to_repr(self : Stream) -> @debug.Repr {
  @debug.Debug::to_repr((self.kind, self.handle))
}

///|
pub impl Show for Stream with fn output(self : Stream, logger : &Logger) -> Unit {
  logger.write_string("\{self.kind}(\{self.handle})")
}
