///|
test "spec default_host routes to platform" {
  let h1 = default_host()
  let h2 = @platform.default_host()
  inspect(h1.id() == @platform.Host::id(h2), content="true")
}

///|
test "spec host_from_id roundtrip for available hosts" {
  let hs = @moon_cpal.available_hosts()
  for id in hs {
    let h = try! host_from_id(id)
    inspect(h.id() == id, content="true")
  }
}

///|
test "spec host_from_id rejects unavailable host ids (native only)" {
  let os = @moon_cpal.native_os()
  let hs = @moon_cpal.available_hosts()
  fn has(xs : Array[@moon_cpal.HostId], x : @moon_cpal.HostId) -> Bool {
    for y in xs {
      if y == x {
        return true
      }
    }
    false
  }

  // Pick a host id that should not be present on this OS.
  let bad = match os {
    @moon_cpal.NativeOs::Linux => @moon_cpal.HostId::CoreAudio
    @moon_cpal.NativeOs::Macos => @moon_cpal.HostId::Alsa
    @moon_cpal.NativeOs::Windows => @moon_cpal.HostId::CoreAudio
    @moon_cpal.NativeOs::Unknown => @moon_cpal.HostId::CoreAudio
  }
  if has(hs, bad) {
    inspect(true, content="true")
    return
  }
  try host_from_id(bad) catch {
    @moon_cpal.HostUnavailable(_) => inspect(true, content="true")
  } noraise {
    _ => inspect(false, content="true")
  }
}

///|
test "spec device id + supports + device_by_id (best-effort)" {
  for host_id in @moon_cpal.available_hosts() {
    let host = try! host_from_id(host_id)
    let ds = try host.devices() catch { _ => [] } noraise { xs => xs }
    for d in ds {
      let did = d.id()
      match host.device_by_id(did) {
        None => inspect(true, content="true")
        Some(found) => {
          let fid = found.id()
          inspect(fid == did, content="true")
        }
      }
      let in_len = try d.supported_input_configs().length() catch { _ => 0 } noraise { x => x }
      let out_len = try d.supported_output_configs().length() catch { _ => 0 } noraise { x => x }
      inspect(d.supports_input() == (in_len > 0), content="true")
      inspect(d.supports_output() == (out_len > 0), content="true")
    }
  }
}
