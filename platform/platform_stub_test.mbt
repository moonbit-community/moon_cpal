///|
test "platform default_host (non-native)" {
  let h = default_host()
  inspect(h.id(), content="Null")
  try host_from_id(CoreAudio) catch {
    @core.HostUnavailable(_) => inspect(true, content="true")
  } noraise {
    _ => inspect(false, content="true")
  }
}
