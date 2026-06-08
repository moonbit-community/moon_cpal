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
test "macos output device as input avoids early unsupported rejection (best-effort)" {
  if @core.native_os() != Macos {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      if dev.supports_input() || !dev.supports_output() {
        inspect(true, content="true")
        return
      }
      let cfg = try dev.default_output_config() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        c => c.config()
      }
      let rejected_early = try {
        let stream = dev.build_input_stream(
          cfg,
          fn(_data, _info) { () },
          fn(_err) { () },
          None,
        )
        stream.close()
        false
      } catch {
        e =>
          match e {
            StreamConfigNotSupported => true
            _ => false
          }
      } noraise {
        x => x
      }
      inspect(!rejected_early, content="true")
    }
  }
}
