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
