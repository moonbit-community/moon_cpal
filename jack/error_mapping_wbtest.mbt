///|
test "jack build error mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Linux {
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

///|
test "jack stream error mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let slot = FixedArray::make(1, @core.stream_error_backend_specific("init"))
  // jack_client_open failures => device not available.
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, 1)
  inspect(slot[0], content="DeviceNotAvailable")

  // Activation/registration failures => invalidated.
  call_stream_error_callback(fn(e) { slot[0] = e }, 2, -1)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 3, -1)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 4, -1)
  inspect(slot[0], content="StreamInvalidated")

  // Errno-style (op_tag 0) mapping: ENODEV and EPIPE.
  call_stream_error_callback(fn(e) { slot[0] = e }, 0, -19)
  inspect(slot[0], content="DeviceNotAvailable")
  call_stream_error_callback(fn(e) { slot[0] = e }, 0, -32)
  inspect(slot[0], content="StreamInvalidated")
}
