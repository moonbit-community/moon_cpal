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
fn print_supported_ranges(
  kind : String,
  ranges : Iter[@moon_cpal.SupportedStreamConfigRange],
) -> Unit {
  let ranges = ranges.to_array()
  println("  \{kind} supported ranges: \{ranges.length()}")
  let n = if ranges.length() > 5 { 5 } else { ranges.length() }
  for i in 0..<n {
    let r = ranges[i]
    println(
      "    - ch=\{r.channels()} sr=\{r.min_sample_rate()}..\{r.max_sample_rate()} buf=\{r.buffer_size().to_string()} fmt=\{r.sample_format().to_debug_string()}",
    )
  }
}

///|
fn print_default_config(
  kind : String,
  f : () -> @moon_cpal.SupportedStreamConfig raise @moon_cpal.DefaultStreamConfigError,
) -> Unit {
  try f() catch {
    e => println("  \{kind} default config: error \{e}")
  } noraise {
    cfg =>
      println(
        "  \{kind} default config: ch=\{cfg.channels()} sr=\{cfg.sample_rate()} buf=\{cfg.buffer_size().to_string()} fmt=\{cfg.sample_format().to_debug_string()}",
      )
  }
}

///|
fn main {
  println("native_os: \{@core.native_os()}")
  let all = @platform.all_hosts()
  println("all_hosts: \{all.length()}")
  for id in all {
    println("- all_host: \{@moon_cpal.HostId::to_string(id)}")
  }
  let hs = @moon_cpal.available_hosts()
  println("available_hosts: \{hs.length()}")
  for id in hs {
    println("- host: \{@moon_cpal.HostId::to_string(id)}")
    let host = try @platform.host_from_id(id) catch {
      e => {
        println("  host_from_id failed: \{e}")
        continue
      }
    } noraise {
      h => h
    }

    // All devices (best-effort).
    let devs = try host.devices() catch {
      e => {
        println("  devices() error: \{e}")
        []
      }
    } noraise {
      it => it.to_array()
    }
    println("  devices: \{devs.length()}")
    let m = if devs.length() > 5 { 5 } else { devs.length() }
    for i in 0..<m {
      let d = devs[i]
      let did = try d.id() catch {
        e => {
          println("  - device id error: \{e.to_string()}")
          None
        }
      } noraise {
        x => Some(x)
      }
      let did = match did {
        None => continue
        Some(x) => x
      }
      let name = try d.name() catch {
        _ => "<error>".to_string()
      } noraise {
        s => s
      }
      println("  - device: \{name} (\{did.to_string()})")
    }

    // Default devices.
    let out_dev = host.default_output_device()
    let in_dev = host.default_input_device()
    match out_dev {
      None => println("  default output device: None")
      Some(d) => {
        try d.id() catch {
          e => println("  output device id error: \{e.to_string()}")
        } noraise {
          did => println("  output device id: \{did.to_string()}")
        }
        let name = try d.name() catch {
          e => {
            println("  output device name error: \{e}")
            "<error>".to_string()
          }
        } noraise {
          s => s
        }
        println("  default output device: \{name}")
        try d.description() catch {
          e => println("  output device description error: \{e}")
        } noraise {
          desc => {
            println("  output device description: \{desc.to_string()}")
            match desc.driver() {
              None => ()
              Some(x) => println("  output device driver: \{x}")
            }
            println(
              "  output device direction: \{desc.direction().to_string()}",
            )
          }
        }
        let ranges = try d.supported_output_configs() catch {
          e => {
            println("  supported_output_configs error: \{e}")
            [].iter()
          }
        } noraise {
          it => it
        }
        print_supported_ranges("output", ranges)
        print_default_config("output", () => d.default_output_config())
      }
    }
    match in_dev {
      None => println("  default input device: None")
      Some(d) => {
        try d.id() catch {
          e => println("  input device id error: \{e.to_string()}")
        } noraise {
          did => println("  input device id: \{did.to_string()}")
        }
        let name = try d.name() catch {
          e => {
            println("  input device name error: \{e}")
            "<error>".to_string()
          }
        } noraise {
          s => s
        }
        println("  default input device: \{name}")
        try d.description() catch {
          e => println("  input device description error: \{e}")
        } noraise {
          desc => {
            println("  input device description: \{desc.to_string()}")
            match desc.driver() {
              None => ()
              Some(x) => println("  input device driver: \{x}")
            }
            println("  input device direction: \{desc.direction().to_string()}")
          }
        }
        let ranges = try d.supported_input_configs() catch {
          e => {
            println("  supported_input_configs error: \{e}")
            [].iter()
          }
        } noraise {
          it => it
        }
        print_supported_ranges("input", ranges)
        print_default_config("input", () => d.default_input_config())
      }
    }
  }
}
