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
test "platform default_host (native)" {
  let h = default_host()
  let expected = match @core.native_os() {
    Macos => @core.HostId::CoreAudio
    Linux => Alsa
    Windows => Wasapi
    Unknown => Null
  }
  inspect(h.id() == expected, content="true")
  // Match upstream: platform `HostId` includes `Null` only on unsupported targets.
  match @core.native_os() {
    Unknown =>
      try host_from_id(Null) catch {
        _ => inspect(false, content="true")
      } noraise {
        _ => inspect(true, content="true")
      }
    _ =>
      try host_from_id(Null) catch {
        _ => inspect(true, content="true")
      } noraise {
        _ => inspect(false, content="true")
      }
  }
}

///|
test "platform available_hosts + host_from_id (native)" {
  let hs = available_hosts()
  let all = all_hosts()
  // `available_hosts()` must be a subset of `all_hosts()`.
  for id in hs {
    inspect(all.contains(id), content="true")
  }
  // On supported native platforms, all hosts are available.
  if @core.native_os() != Unknown {
    inspect(hs.length() == all.length(), content="true")
  } else {
    inspect(all.length() == 1 && all[0] == Null, content="true")
  }

  // Linux should include JACK as well.
  if @core.native_os() == Linux {
    inspect(hs.contains(Jack), content="true")
  }

  // Spot-check: available hosts should match platform OS.
  match @core.native_os() {
    Macos => {
      inspect(hs.contains(CoreAudio), content="true")
      inspect(!hs.contains(Alsa), content="true")
      inspect(!hs.contains(Wasapi), content="true")
      inspect(!hs.contains(Jack), content="true")
    }
    Windows => {
      inspect(hs.contains(Wasapi), content="true")
      inspect(!hs.contains(CoreAudio), content="true")
      inspect(!hs.contains(Alsa), content="true")
      inspect(!hs.contains(Jack), content="true")
    }
    Linux => {
      inspect(hs.contains(Alsa), content="true")
      inspect(!hs.contains(CoreAudio), content="true")
      inspect(!hs.contains(Wasapi), content="true")
    }
    Unknown => @debug.debug_inspect(hs, content="[@core.HostId::Null]")
  }

  // All advertised hosts should be constructible.
  for id in all {
    try host_from_id(id) catch {
      _ => inspect(false, content="true")
    } noraise {
      _ => inspect(true, content="true")
    }
  }
}

///|
test "platform device_by_id + supports + in/out device filters" {
  for host_id in available_hosts() {
    let host = try host_from_id(host_id) catch {
      _ => continue
    } noraise {
      h => h
    }
    let ds = try host.devices() catch {
      _ => []
    } noraise {
      it => it.to_array()
    }

    // device_by_id roundtrip (best-effort)
    for d in ds {
      let did = try d.id() catch {
        _ => None
      } noraise {
        x => Some(x)
      }
      let did = match did {
        None => continue
        Some(x) => x
      }
      match host.device_by_id(did) {
        None => inspect(true, content="true")
        Some(found) => {
          let found_id = try found.id() catch {
            _ => did
          } noraise {
            x => x
          }
          inspect(found_id == did, content="true")
        }
      }

      // supports_* should match "supported_*_configs non-empty" (errors => false)
      let in_len = try d.supported_input_configs().count() catch {
        _ => 0
      } noraise {
        x => x
      }
      let out_len = try d.supported_output_configs().count() catch {
        _ => 0
      } noraise {
        x => x
      }
      inspect(d.supports_input() == (in_len > 0), content="true")
      inspect(d.supports_output() == (out_len > 0), content="true")
    }

    // input_devices/output_devices == devices().filter(supports_*)
    let expected_in : Array[Device] = []
    let expected_out : Array[Device] = []
    for d in ds {
      if d.supports_input() {
        expected_in.push(d)
      }
      if d.supports_output() {
        expected_out.push(d)
      }
    }
    let got_in = try host.input_devices() catch {
      _ => []
    } noraise {
      it => it.to_array()
    }
    let got_out = try host.output_devices() catch {
      _ => []
    } noraise {
      it => it.to_array()
    }
    inspect(got_in.length() == expected_in.length(), content="true")
    inspect(got_out.length() == expected_out.length(), content="true")
  }
}

///|
test "platform default devices are present in devices() (best-effort)" {
  for host_id in available_hosts() {
    let host = try host_from_id(host_id) catch {
      _ => continue
    } noraise {
      h => h
    }
    let ds = try host.devices() catch {
      _ => []
    } noraise {
      it => it.to_array()
    }
    let out = host.default_output_device()
    match out {
      None => ()
      Some(d) => {
        // device_by_id roundtrip should work if devices() worked.
        let did = try d.id() catch {
          _ => None
        } noraise {
          x => Some(x)
        }
        let did = match did {
          None => continue
          Some(x) => x
        }
        match host.device_by_id(did) {
          None => inspect(true, content="true")
          Some(found) => {
            let fid = try found.id() catch {
              _ => did
            } noraise {
              x => x
            }
            inspect(fid == did, content="true")
          }
        }
        if ds.length() > 0 {
          let mut ok = false
          for x in ds {
            let xid = try x.id() catch {
              _ => None
            } noraise {
              y => Some(y)
            }
            let xid = match xid {
              None => continue
              Some(v) => v
            }
            if xid == did {
              ok = true
              break
            }
          }
          inspect(ok, content="true")
        }
      }
    }
    let inp = host.default_input_device()
    match inp {
      None => ()
      Some(d) => {
        let did = try d.id() catch {
          _ => None
        } noraise {
          x => Some(x)
        }
        let did = match did {
          None => continue
          Some(x) => x
        }
        match host.device_by_id(did) {
          None => inspect(true, content="true")
          Some(found) => {
            let fid = try found.id() catch {
              _ => did
            } noraise {
              x => x
            }
            inspect(fid == did, content="true")
          }
        }
        if ds.length() > 0 {
          let mut ok = false
          for x in ds {
            let xid = try x.id() catch {
              _ => None
            } noraise {
              y => Some(y)
            }
            let xid = match xid {
              None => continue
              Some(v) => v
            }
            if xid == did {
              ok = true
              break
            }
          }
          inspect(ok, content="true")
        }
      }
    }
  }
  inspect(true, content="true")
}
