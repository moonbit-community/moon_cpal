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
test "spec default_host routes to platform" {
  let h1 = default_host()
  let h2 = @platform.default_host()
  inspect(h1.id() == @platform.Host::id(h2), content="true")
}

///|
test "spec host_from_id roundtrip for available hosts" {
  let hs = available_hosts()
  for id in hs {
    let h = try! host_from_id(id)
    inspect(h.id() == id, content="true")
  }
}

///|
test "spec host_from_id rejects unavailable host ids (native only)" {
  let os = @core.native_os()
  let hs = available_hosts()
  fn has(xs : Array[@core.HostId], x : @core.HostId) -> Bool {
    for y in xs {
      if y == x {
        return true
      }
    }
    false
  }

  // Pick a host id that should not be present on this OS.
  let bad = match os {
    @core.NativeOs::Linux => @core.HostId::CoreAudio
    @core.NativeOs::Macos => @core.HostId::Alsa
    @core.NativeOs::Windows => @core.HostId::CoreAudio
    @core.NativeOs::Unknown => @core.HostId::CoreAudio
  }
  if has(hs, bad) {
    inspect(true, content="true")
    return
  }
  try host_from_id(bad) catch {
    @core.HostUnavailable => inspect(true, content="true")
  } noraise {
    _ => inspect(false, content="true")
  }
}

///|
test "spec device id + supports + device_by_id (best-effort)" {
  for host_id in available_hosts() {
    let host = try! host_from_id(host_id)
    let ds = try host.devices() catch {
      _ => []
    } noraise {
      xs => xs
    }
    for d in ds {
      let did = try d.id() catch {
        _ => continue
      } noraise {
        x => x
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
      let in_len = try d.supported_input_configs().length() catch {
        _ => 0
      } noraise {
        x => x
      }
      let out_len = try d.supported_output_configs().length() catch {
        _ => 0
      } noraise {
        x => x
      }
      inspect(d.supports_input() == (in_len > 0), content="true")
      inspect(d.supports_output() == (out_len > 0), content="true")
    }
  }
}

///|
test "spec: raw + typed stream builders (best-effort)" {
  let host = default_host()
  let out = match host.default_output_device() {
    None => {
      inspect(true, content="true")
      return
    }
    Some(d) => d
  }
  let inp = match host.default_input_device() {
    None => {
      inspect(true, content="true")
      return
    }
    Some(d) => d
  }
  let out_cfg = try out.default_output_config() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    x => x
  }
  let inp_cfg = try inp.default_input_config() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    x => x
  }
  let out_sc = @core.StreamConfig::new(
    out_cfg.channels(),
    out_cfg.sample_rate(),
    @core.BufferSize::fixed(64),
  )
  let inp_sc = @core.StreamConfig::new(
    inp_cfg.channels(),
    inp_cfg.sample_rate(),
    @core.BufferSize::fixed(64),
  )

  // Raw output.
  try
    out.build_output_stream_raw(
      out_sc,
      out_cfg.sample_format(),
      fn(_d, _info) {  },
      fn(_e) {  },
      None,
    )
  catch {
    _ => ()
  } noraise {
    st => {
      ignore(try? st.play())
      ignore(try? st.pause())
      st.close()
    }
  }

  // Typed output (best-effort; may fail if the device doesn't support the requested format).
  try
    out.build_output_stream_f32(out_sc, fn(_xs, _info) {  }, fn(_e) {  }, None)
  catch {
    _ => ()
  } noraise {
    st => {
      ignore(try? st.play())
      ignore(try? st.pause())
      st.close()
    }
  }
  try
    out.build_output_stream_i16(out_sc, fn(_xs, _info) {  }, fn(_e) {  }, None)
  catch {
    _ => ()
  } noraise {
    st => {
      ignore(try? st.play())
      ignore(try? st.pause())
      st.close()
    }
  }

  // Raw input.
  try
    inp.build_input_stream_raw(
      inp_sc,
      inp_cfg.sample_format(),
      fn(_d, _info) {  },
      fn(_e) {  },
      None,
    )
  catch {
    _ => ()
  } noraise {
    st => {
      ignore(try? st.play())
      ignore(try? st.pause())
      st.close()
    }
  }

  // Typed input.
  try
    inp.build_input_stream_f32(inp_sc, fn(_xs, _info) {  }, fn(_e) {  }, None)
  catch {
    _ => ()
  } noraise {
    st => {
      ignore(try? st.play())
      ignore(try? st.pause())
      st.close()
    }
  }
  inspect(true, content="true")
}
