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
test "traits: HostTrait/DeviceTrait/StreamTrait roundtrip (best-effort)" {
  let host = @spec.default_host()
  let _id = host.id()

  // Exercise trait dispatch.
  let _ = HostTrait::default_output_device(host)
  match HostTrait::default_output_device(host) {
    None => inspect(true, content="true")
    Some(dev) => {
      let _ = DeviceTrait::supports_output(dev)
      let _ = try DeviceTrait::id(dev) catch {
        _ => @core.DeviceId::new(_id, "")
      } noraise {
        x => x
      }
      let cfg = try DeviceTrait::default_output_config(dev) catch {
        _ => None
      } noraise {
        x => Some(x)
      }
      match cfg {
        None => inspect(true, content="true")
        Some(cfg) => {
          let sc = cfg.config()
          let stream = try
            DeviceTrait::build_output_stream_raw(
              dev,
              sc,
              cfg.sample_format(),
              fn(data, _info) { data.clear() },
              fn(_e) { () },
              None,
            )
          catch {
            _ => None
          } noraise {
            s => Some(s)
          }
          match stream {
            None => inspect(true, content="true")
            Some(s) => {
              // Stream lifecycle calls should not crash.
              try StreamTrait::play(s) catch {
                _ => ()
              } noraise {
                _ => ()
              }
              try StreamTrait::pause(s) catch {
                _ => ()
              } noraise {
                _ => ()
              }
              StreamTrait::close(s)
              inspect(true, content="true")
            }
          }
        }
      }
    }
  }
}
