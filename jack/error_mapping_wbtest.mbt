///|
test "jack stream error mapping (unit)" {
  let slot = FixedArray::make(
    1,
    @moon_cpal.stream_error_backend_specific("init"),
  )
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, 1)
  inspect(slot[0], content="DeviceNotAvailable")
  call_stream_error_callback(fn(e) { slot[0] = e }, 0, 19)
  inspect(slot[0], content="DeviceNotAvailable")
  call_stream_error_callback(fn(e) { slot[0] = e }, 0, 32)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 2, -1)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 99, 123)
  match slot[0] {
    @moon_cpal.StreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
}
