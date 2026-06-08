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
test "wasapi raw output build on capture endpoint is not pre-rejected by config ranges (best-effort)" {
  if @core.native_os() != Windows {
    inspect(true, content="true")
    return
  }

  let host = default_host()
  let in_dev = match host.default_input_device() {
    None => {
      inspect(true, content="true")
      return
    }
    Some(d) => d
  }
  let in_cfg = try in_dev.default_input_config() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    x => x
  }
  let sc = in_cfg.config()

  try
    in_dev.build_output_stream_raw(
      sc,
      in_cfg.sample_format(),
      fn(_d, _info) { () },
      fn(_e) { () },
      None,
    )
  catch {
    e =>
      match e {
        // This case historically indicated MoonBit-side prevalidation against
        // supported_output_configs() on capture endpoints; keep it rejected.
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
