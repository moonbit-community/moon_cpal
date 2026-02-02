///|
test "platform default_host (non-native)" {
  let h = default_host()
  inspect(h.id(), content="Null")
  inspect(host_from_id(CoreAudio), content="None")
}
