///|
test "platform default_host (native)" {
  let h = default_host()
  let expected = match @moon_cpal.native_os() {
    @moon_cpal.NativeOs::Macos => @moon_cpal.HostId::CoreAudio
    @moon_cpal.NativeOs::Linux => @moon_cpal.HostId::Alsa
    @moon_cpal.NativeOs::Windows => @moon_cpal.HostId::Wasapi
    @moon_cpal.NativeOs::Unknown => @moon_cpal.HostId::Null
  }
  inspect(h.id() == expected, content="true")
  try host_from_id(Null) catch {
    _ => inspect(false, content="true")
  } noraise {
    _ => inspect(true, content="true")
  }
}

///|
test "platform available_hosts + host_from_id (native)" {
  let hs = available_hosts()
  // Always includes Null.
  inspect(hs.contains(@moon_cpal.HostId::Null), content="true")

  // Linux should now include JACK as well.
  if @moon_cpal.native_os() == @moon_cpal.NativeOs::Linux {
    inspect(hs.contains(@moon_cpal.HostId::Jack), content="true")
  }

  // All advertised hosts should be constructible.
  for id in hs {
    try host_from_id(id) catch {
      _ => inspect(false, content="true")
    } noraise {
      _ => inspect(true, content="true")
    }
  }
}
