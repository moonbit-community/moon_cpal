///|
test "alsa: devices includes default (linux-only)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    return
  }
  let h = default_host()
  let ds = h.devices()
  inspect(ds.length() > 0, content="true")
  let mut has_default = false
  for d in ds {
    if d.id == "default" {
      has_default = true
      break
    }
  }
  inspect(has_default, content="true")
}

///|
test "alsa: default devices are always Some (linux-only)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let h = default_host()
  match h.default_output_device() {
    None => inspect(false, content="false")
    Some(d) => inspect(d.id == "default", content="true")
  }
  match h.default_input_device() {
    None => inspect(false, content="false")
    Some(d) => inspect(d.id == "default", content="true")
  }
}
