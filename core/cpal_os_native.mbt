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
/// Best-effort OS detection for native builds.
///
/// Moon's conditional compilation in `moon.pkg.json` can distinguish backend/mode but not OS,
/// so we expose a tiny native helper implemented in C.

///|
pub(all) enum NativeOs {
  Unknown
  Macos
  Windows
  Linux
} derive(Debug, Eq)

///|
extern "C" fn native_os_tag() -> Int = "moon_cpal_os_tag"

///|
pub fn native_os() -> NativeOs {
  match native_os_tag() {
    1 => Macos
    2 => Windows
    3 => Linux
    _ => Unknown
  }
}
