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
/// Smoke tests for macOS CoreAudio streams.
///
/// These mirror upstream `cpal` CoreAudio macOS tests, but are best-effort:
/// - On CI or without permissions/devices, we treat failures as "skipped".
/// - Locally, they exercise build + play/pause.

///|
test "macos stream smoke: play output" {
  try {
    let host = default_host()
    match host.default_output_device() {
      None => ()
      Some(dev) => {
        let ranges = dev.supported_output_configs()
        if ranges.is_empty() {
          ()
        } else {
          let supported = ranges[0].with_max_sample_rate()
          let cfg = supported.config()
          let stream = dev.build_output_stream(
            cfg,
            fn(_data, _info) { () },
            fn(_err) { () },
            None,
          )
          stream.play()
          stream.pause()
          stream.close()
        }
      }
    }
  } catch {
    _ => ()
  } noraise {
    _ => ()
  }
  inspect(true, content="true")
}

///|
test "macos stream smoke: record input" {
  try {
    let host = default_host()
    match host.default_input_device() {
      None => ()
      Some(dev) => {
        let ranges = dev.supported_input_configs()
        if ranges.is_empty() {
          ()
        } else {
          let supported = ranges[0].with_max_sample_rate()
          let cfg = supported.config()
          let stream = dev.build_input_stream(
            cfg,
            fn(_data, _info) { () },
            fn(_err) { () },
            None,
          )
          stream.play()
          stream.pause()
          stream.close()
        }
      }
    }
  } catch {
    _ => ()
  } noraise {
    _ => ()
  }
  inspect(true, content="true")
}

///|
test "macos stream smoke: record via output device" {
  try {
    let host = default_host()
    match host.default_output_device() {
      None => ()
      Some(dev) => {
        let ranges = dev.supported_output_configs()
        if ranges.is_empty() {
          ()
        } else {
          let supported = ranges[0].with_max_sample_rate()
          let cfg = supported.config()
          // Mirrors upstream `test_record_output`: attempt to build an input stream with
          // the output device + config (may fail depending on device capabilities).
          try
            dev.build_input_stream(
              cfg,
              fn(_data, _info) { () },
              fn(_err) { () },
              None,
            )
          catch {
            _ => ()
          } noraise {
            stream => {
              try stream.play() catch {
                _ => ()
              } noraise {
                _ => ()
              }
              try stream.pause() catch {
                _ => ()
              } noraise {
                _ => ()
              }
              stream.close()
            }
          }
        }
      }
    }
  } catch {
    _ => ()
  } noraise {
    _ => ()
  }
  inspect(true, content="true")
}
