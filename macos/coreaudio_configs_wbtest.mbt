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
test "macos supported_output_configs basic invariants" {
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) =>
      try dev.supported_output_configs() catch {
        _ => inspect(true, content="true")
      } noraise {
        configs =>
          if configs.is_empty() {
            inspect(true, content="true")
          } else {
            let first = configs[0]
            inspect(first.sample_format(), content="F32")
            inspect(first.channels() > 0, content="true")
            inspect(
              first.min_sample_rate() <= first.max_sample_rate(),
              content="true",
            )
            match first.buffer_size() {
              Range(min=mn, max=mx) => {
                inspect(mn > 0, content="true")
                inspect(mn <= mx, content="true")
              }
              Unknown => inspect(true, content="true")
            }
          }
      }
  }
}

///|
test "macos supported_input_configs basic invariants (if any)" {
  let host = default_host()
  match host.default_input_device() {
    None => inspect(true, content="true")
    Some(dev) =>
      try dev.supported_input_configs() catch {
        _ => inspect(true, content="true")
      } noraise {
        configs =>
          // Some machines may not have any input-capable device; treat that as OK.
          if configs.is_empty() {
            inspect(true, content="true")
          } else {
            let first = configs[0]
            inspect(first.sample_format(), content="F32")
            inspect(first.channels() > 0, content="true")
            inspect(
              first.min_sample_rate() <= first.max_sample_rate(),
              content="true",
            )
          }
      }
  }
}

///|
test "macos supports_input/output follow channel counts" {
  let host = default_host()
  let devices = try host.devices() catch {
    _ => []
  } noraise {
    xs => xs
  }
  for d in devices {
    inspect(
      d.supports_input() == (ca_input_channel_count(d.id) > 0),
      content="true",
    )
    inspect(
      d.supports_output() == (ca_output_channel_count(d.id) > 0),
      content="true",
    )
  }
  inspect(true, content="true")
}

///|
test "macos can apply nominal sample rate from default input config (best-effort)" {
  if @core.native_os() != @core.NativeOs::Macos {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_input_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_input_config() catch {
        _ => None
      } noraise {
        c => Some(c)
      }
      match cfg {
        None => inspect(true, content="true")
        Some(c) => {
          let ok = try {
            set_nominal_sample_rate(dev.id, c.sample_rate)
            true
          } catch {
            DeviceNotAvailable(_, _) => true
            _ => false
          } noraise {
            x => x
          }
          inspect(ok, content="true")
        }
      }
    }
  }
}

///|
test "macos set_nominal_sample_rate rejects non-positive rates" {
  let host = default_host()
  let devices = try host.devices() catch {
    _ => []
  } noraise {
    xs => xs
  }
  if devices.is_empty() {
    inspect(true, content="true")
    return
  }
  let dev = devices[0]
  let ok = try {
    set_nominal_sample_rate(dev.id, 0)
    false
  } catch {
    CoreAudioError(op, status) =>
      op == "ca_set_nominal_sample_rate" && status == -50
    _ => false
  } noraise {
    x => x
  }
  inspect(ok, content="true")
}
