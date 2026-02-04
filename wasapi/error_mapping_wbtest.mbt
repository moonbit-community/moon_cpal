///|
test "wasapi HRESULT mapping (unit)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  // AUDCLNT_E_DEVICE_INVALIDATED (0x88890004)
  inspect(
    wasapi_stream_error_from_hresult(-2004287484, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  // AUDCLNT_E_DEVICE_IN_USE (0x8889000A)
  inspect(
    wasapi_stream_error_from_hresult(-2004287478, "IAudioClientStart"),
    content="DeviceNotAvailable",
  )
}
