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
test "jack supported configs reflect server sample rate/buffer size (best-effort)" {
  if @core.native_os() != Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_output_config() catch {
        _ => {
          // If no JACK server is running, config queries will fail.
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      inspect(cfg.sample_format() == F32, content="true")
      inspect(cfg.sample_rate() > 0, content="true")
      match cfg.buffer_size() {
        Unknown => inspect(false, content="true")
        Range(min=mn, max=mx) => {
          inspect(mn > 0, content="true")
          inspect(mx == mn, content="true")
        }
      }
      let ranges = dev.supported_output_configs()
      inspect(ranges.length() == 10, content="true")

      // JACK reports a fixed sample rate and buffer size across all supported channels.
      for r in ranges {
        inspect(r.min_sample_rate() == cfg.sample_rate(), content="true")
        inspect(r.max_sample_rate() == cfg.sample_rate(), content="true")
        inspect(r.sample_format() == cfg.sample_format(), content="true")
        match r.buffer_size() {
          Unknown => inspect(false, content="true")
          Range(min=mn, max=mx) =>
            match cfg.buffer_size() {
              Unknown => inspect(false, content="true")
              Range(min=mn2, max=mx2) => {
                inspect(mn == mn2, content="true")
                inspect(mx == mx2, content="true")
              }
            }
        }
      }
    }
  }
}

///|
test "jack default devices expose config queries for both stream types (best-effort)" {
  if @core.native_os() != Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  let devs = host.devices()
  if devs.length() == 0 {
    inspect(true, content="true")
    return
  }
  for dev in devs {
    inspect(dev.supports_input(), content="true")
    inspect(dev.supports_output(), content="true")
    let in_ok = try {
      ignore(dev.default_input_config())
      true
    } catch {
      _ => false
    }
    let out_ok = try {
      ignore(dev.default_output_config())
      true
    } catch {
      _ => false
    }
    inspect(in_ok, content="true")
    inspect(out_ok, content="true")
  }
}
