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
test "wasapi output configs reflect device mix format (best-effort)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None =>
      // Some environments may not expose a default render endpoint.
      inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_output_config() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      inspect(cfg.channels() > 0, content="true")
      inspect(cfg.sample_rate() > 0, content="true")
      let ranges = dev.supported_output_configs()
      inspect(ranges.length() > 0, content="true")
      let mut found = false
      for r in ranges {
        if r.channels() == cfg.channels() &&
          r.min_sample_rate() == cfg.sample_rate() &&
          r.max_sample_rate() == cfg.sample_rate() &&
          r.sample_format() == cfg.sample_format() &&
          r.buffer_size() == cfg.buffer_size() {
          found = true
          break
        }
      }
      inspect(found, content="true")
    }
  }
}

///|
test "wasapi data_flow gating (best-effort)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  for dev in host.devices() {
    match data_flow_tag(dev.id) {
      None => ()
      Some(tag) =>
        if tag == 1 {
          // Capture device: output should be empty.
          inspect(dev.supports_input(), content="true")
          inspect(dev.supports_output(), content="false")
          inspect(dev.supported_output_configs().length() == 0, content="true")
        } else if tag == 2 {
          // Render device: input should be empty.
          inspect(dev.supports_input(), content="false")
          inspect(dev.supports_output(), content="true")
          inspect(dev.supported_input_configs().length() == 0, content="true")
        }
    }
  }
  inspect(true, content="true")
}

///|
test "wasapi default devices appear in enumeration (best-effort)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let devices = default_host().devices()
  let has_id = fn(id : String) {
    let mut found = false
    for d in devices {
      if d.id == id {
        found = true
        break
      }
    }
    found
  }
  match default_host().default_output_device() {
    Some(d) => inspect(has_id(d.id), content="true")
    None => inspect(true, content="true")
  }
  match default_host().default_input_device() {
    Some(d) => inspect(has_id(d.id), content="true")
    None => inspect(true, content="true")
  }
}
