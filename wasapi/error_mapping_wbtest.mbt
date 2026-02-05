///|
test "wasapi HRESULT mapping (unit)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  // AUDCLNT_E_DEVICE_INVALIDATED (0x88890004)
  inspect(
    wasapi_stream_error_from_hresult(-2004287484, "DeviceInit"),
    content="StreamInvalidated",
  )
  // AUDCLNT_E_DEVICE_IN_USE (0x8889000A)
  inspect(
    wasapi_stream_error_from_hresult(-2004287478, "IAudioClientStart"),
    content="DeviceNotAvailable",
  )
  // AUDCLNT_E_ENDPOINT_CREATE_FAILED (0x8889000E)
  inspect(
    wasapi_stream_error_from_hresult(-2004287474, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  // AUDCLNT_E_SERVICE_NOT_RUNNING (0x88890010)
  inspect(
    wasapi_stream_error_from_hresult(-2004287472, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287484, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287474, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287472, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287478, "DeviceInit"),
    content="DeviceBusy",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287480, "IAudioClientInitialize"),
    content="StreamConfigNotSupported",
  )
  inspect(
    wasapi_build_error_from_hresult(-2147024809, "IAudioClientInitialize"),
    content="InvalidArgument",
  )
}
