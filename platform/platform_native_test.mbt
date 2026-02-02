///|
test "platform default_host (native)" {
  let h = default_host()
  inspect(h.id(), content="CoreAudio")
  inspect(host_from_id(Null) is Some(_), content="true")
}
