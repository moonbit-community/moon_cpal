///|
test "jack build error mapping (unit)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  inspect(
    jack_build_error_from_status(-19, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-2, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-1, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-13, "jack_client_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    jack_build_error_from_status(-16, "jack_client_open"),
    content="DeviceBusy",
  )
  inspect(
    jack_build_error_from_status(-11, "jack_client_open"),
    content="DeviceBusy",
  )
  inspect(
    jack_build_error_from_status(-22, "jack_client_open"),
    content="InvalidArgument",
  )
}

