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
test "wasapi build_input_stream supports render endpoints via loopback (best-effort)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  let mut target : Device? = None
  for dev in host.devices() {
    if data_flow_tag(dev.id) == Some(2) &&
      dev.supported_output_configs().length() > 0 {
      target = Some(dev)
      break
    }
  }
  let dev = match target {
    None => {
      inspect(true, content="true")
      return
    }
    Some(d) => d
  }
  let cfg = try dev.default_output_config() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    x => x.config()
  }
  try
    dev.build_input_stream(cfg, fn(_data, _info) { () }, fn(_err) { () }, None)
  catch {
    err =>
      // This path should no longer fail due to pre-validation mismatch between
      // `build_input_stream` and `build_input_stream_raw`.
      match err {
        @core.BuildStreamError::StreamConfigNotSupported =>
          inspect(false, content="true")
        _ => inspect(true, content="true")
      }
  } noraise {
    stream => {
      stream.close()
      inspect(true, content="true")
    }
  }
}
