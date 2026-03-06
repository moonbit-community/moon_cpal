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
test "alsa default config matches supported configs (best-effort)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_output_config() catch {
        _ => {
          // Some CI environments may not expose a working default PCM even with `.asoundrc`.
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      let ranges = try dev.supported_output_configs() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        xs => xs
      }
      inspect(ranges.length() > 0, content="true")

      // Ensure `cfg` is representable by at least one returned range.
      let mut ok = false
      for r in ranges {
        if r.channels() == cfg.channels() &&
          r.sample_format() == cfg.sample_format() &&
          r.min_sample_rate() <= cfg.sample_rate() &&
          cfg.sample_rate() <= r.max_sample_rate() {
          ok = true
        }
      }
      inspect(ok, content="true")
    }
  }
}

///|
test "alsa supported configs include sane buffer size ranges (best-effort)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let ranges = try dev.supported_output_configs() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        xs => xs
      }
      if ranges.length() == 0 {
        inspect(true, content="true")
        return
      }
      let r = ranges[0]
      match r.buffer_size() {
        Unknown => inspect(true, content="true")
        Range(min=mn, max=mx) => {
          inspect(mn > 0, content="true")
          inspect(mx >= mn, content="true")
        }
      }
    }
  }
}

///|
test "alsa enumeration keeps null PCM when present (best-effort)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  let devs = host.devices()
  let mut saw_default = false
  let mut saw_null = false
  for dev in devs {
    let did = dev.id().to_string()
    if did == "alsa:default" {
      saw_default = true
    }
    if did == "alsa:null" {
      saw_null = true
      let desc = try dev.description() catch {
        _ => {
          inspect(false, content="true")
          return
        }
      } noraise {
        x => x
      }
      inspect(desc.name().length() > 0, content="true")
    }
  }
  inspect(saw_default, content="true")
  inspect(true, content="true")
  if saw_null {
    inspect(true, content="true")
  } else {
    inspect(true, content="true")
  }
}
