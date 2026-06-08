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
test "alsa fixed buffer 0 is stream_config_not_supported (best-effort)" {
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
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      let sc = @core.StreamConfig(
        cfg.channels(),
        cfg.sample_rate(),
        @core.BufferSize::fixed(0),
      )
      try
        dev.build_output_stream_raw(
          sc,
          cfg.sample_format(),
          fn(_d, _info) { () },
          fn(_e) { () },
          None,
        )
      catch {
        e =>
          match e {
            StreamConfigNotSupported => inspect(true, content="true")
            _ => inspect(false, content="true")
          }
      } noraise {
        s => {
          s.close()
          inspect(false, content="true")
        }
      }
    }
  }
}

///|
test "alsa fixed buffer outside supported range is best-effort (best-effort)" {
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
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      let max_buf = match cfg.buffer_size() {
        Unknown => {
          inspect(true, content="true")
          return
        }
        Range(max=mx, ..) => mx
      }
      // Avoid overflow when buffer size is effectively unbounded.
      if max_buf >= 2147483647 {
        inspect(true, content="true")
        return
      }
      let want = max_buf + 1
      let sc = @core.StreamConfig(
        cfg.channels(),
        cfg.sample_rate(),
        @core.BufferSize::fixed(want),
      )
      try
        dev.build_output_stream_raw(
          sc,
          cfg.sample_format(),
          fn(_d, _info) { () },
          fn(_e) { () },
          None,
        )
      catch {
        // Upstream CPAL uses "near" period-size setting for ALSA; requests outside the supported
        // range may be rounded rather than rejected. Accept any backend error here, but ensure
        // we don't pre-classify this as StreamConfigNotSupported purely due to the buffer size.
        e =>
          match e {
            StreamConfigNotSupported => inspect(false, content="true")
            _ => inspect(true, content="true")
          }
      } noraise {
        s => {
          s.close()
          inspect(true, content="true")
        }
      }
    }
  }
}
