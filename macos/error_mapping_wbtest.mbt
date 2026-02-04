///|
test "coreaudio OSStatus kind + stream error mapping (unit)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Macos {
    inspect(true, content="true")
    return
  }

  // See `macos/coreaudio_stub.c` for the classification rules and constants.
  inspect(osstatus_kind(-50) == 4, content="true") // kAudio_ParamError
  inspect(osstatus_kind(50) == 4, content="true")
  inspect(osstatus_kind(-66668) == 5, content="true") // kAudioQueueErr_RecordUnderrun
  inspect(osstatus_kind(-66671) == 3, content="true") // kAudioQueueErr_QueueInvalidated
  inspect(osstatus_kind(-66680) == 1, content="true") // kAudioQueueErr_InvalidDevice
  inspect(osstatus_kind(560226676) == 2, content="true") // kAudioDeviceUnsupportedFormatError
  inspect(osstatus_kind(0) == 0, content="true")
  let slot = FixedArray::make(
    1,
    @moon_cpal.stream_error_backend_specific("init"),
  )
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, -66668)
  inspect(slot[0], content="BufferUnderrun")
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, -66671)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, -66680)
  inspect(slot[0], content="DeviceNotAvailable")
}
