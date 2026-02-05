///|
test "test_host exposes a synthetic device" {
  let host = default_host()
  inspect(host.devices().length(), content="1")
  inspect(host.default_output_device() != None, content="true")
  inspect(host.default_input_device() != None, content="true")
}
