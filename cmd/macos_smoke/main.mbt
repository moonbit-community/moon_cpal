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
fn main {
  // Simple smoke test for CoreAudio bindings (native + macOS only).
  let ids = try! @macos.device_ids()
  println("devices: \{ids.length()}")
  for id in ids {
    let name = try! @macos.device_name(id)
    println("\{id}: \{name}")
  }
  match @macos.default_output_device_id() {
    Some(id) => {
      println("default output: \{id}")
      let cfgs = try! @macos.supported_output_configs(id)
      println("supported output configs: \{cfgs.length()}")
      if cfgs.length() > 0 {
        println("\{cfgs[0]}")
      }
      try @macos.default_output_config(id) catch {
        _ => println("default output config error")
      } noraise {
        cfg => println("default output config: \{cfg}")
      }
    }
    None => println("default output: none")
  }
  match @macos.default_input_device_id() {
    Some(id) => {
      println("default input: \{id}")
      try @macos.default_input_config(id) catch {
        _ => println("default input config error")
      } noraise {
        cfg => println("default input config: \{cfg}")
      }
    }
    None => println("default input: none")
  }
}
