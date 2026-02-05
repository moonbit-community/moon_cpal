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
  // Other HRESULTs should be backend-specific.
  match wasapi_stream_error_from_hresult(-2004287474, "DeviceInit") {
    @moon_cpal.StreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  match wasapi_stream_error_from_hresult(-2004287472, "DeviceInit") {
    @moon_cpal.StreamError::BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  inspect(
    wasapi_build_error_from_hresult(-2004287484, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  inspect(
    wasapi_build_error_from_hresult(-2004287478, "DeviceInit"),
    content="DeviceNotAvailable",
  )
  match wasapi_build_error_from_hresult(-2004287474, "DeviceInit") {
    @moon_cpal.BuildStreamError::BackendSpecific(_) =>
      inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  match wasapi_build_error_from_hresult(-2004287472, "DeviceInit") {
    @moon_cpal.BuildStreamError::BackendSpecific(_) =>
      inspect(true, content="true")
    _ => inspect(false, content="true")
  }
  inspect(
    wasapi_build_error_from_hresult(-2004287480, "IAudioClientInitialize"),
    content="StreamConfigNotSupported",
  )
  inspect(
    wasapi_build_error_from_hresult(-2147024809, "IAudioClientInitialize"),
    content="InvalidArgument",
  )
}
