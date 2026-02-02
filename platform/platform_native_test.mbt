///|
test "platform default_host (native)" {
  let h = default_host()
  inspect(h.id(), content="CoreAudio")
  try host_from_id(Null) catch {
    _ => inspect(false, content="true")
  } noraise {
    _ => inspect(true, content="true")
  }
}
