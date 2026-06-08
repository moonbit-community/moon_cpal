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
fn[T : @debug.Debug] show_from_debug(value : T, logger : &Logger) -> Unit {
  let rendered = @debug.render(@debug.Debug::to_repr(value))
  logger.write_string(
    rendered.replace_all(old="{ ", new="{").replace_all(old=" }", new="}"),
  )
}

///|
pub impl Show for Host with fn output(self : Host, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for Device with fn output(self : Device, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for Stream with fn output(self : Stream, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}

///|
pub impl Show for Data with fn output(self : Data, logger : &Logger) -> Unit {
  show_from_debug(self, logger)
}
