///|
test "null host has no devices" {
  let host = default_host()
  inspect(host.devices().length(), content="0")
  inspect(host.default_output_device(), content="None")
  inspect(host.default_input_device(), content="None")
}
