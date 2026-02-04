///|
test "error display strings (cpal-reference parity)" {
  inspect(
    BackendSpecificError::new("oops").to_string(),
    content="A backend-specific error has occurred: oops",
  )

  inspect(
    devices_error_backend_specific("oops").to_string(),
    content="A backend-specific error has occurred: oops",
  )
  inspect(
    device_name_error_backend_specific("oops").to_string(),
    content="A backend-specific error has occurred: oops",
  )

  inspect(
    default_stream_config_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    default_stream_config_error_device_busy().to_string(),
    content="The requested device is temporarily busy. Another application or stream may be using it.",
  )
  inspect(
    default_stream_config_error_stream_type_not_supported().to_string(),
    content="The requested stream type is not supported by the device.",
  )

  inspect(
    supported_stream_configs_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    supported_stream_configs_error_device_busy().to_string(),
    content="The requested device is temporarily busy. Another application or stream may be using it.",
  )
  inspect(
    supported_stream_configs_error_invalid_argument().to_string(),
    content="Invalid argument passed to the backend. For example, this happens when trying to read capture capabilities when the device does not support it.",
  )

  inspect(
    build_stream_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    build_stream_error_device_busy().to_string(),
    content="The requested device is temporarily busy. Another application or stream may be using it.",
  )
  inspect(
    build_stream_error_stream_config_not_supported().to_string(),
    content="The requested stream configuration is not supported by the device.",
  )
  inspect(
    build_stream_error_invalid_argument().to_string(),
    content="The requested device does not support this capability (invalid argument)",
  )
  inspect(
    build_stream_error_stream_id_overflow().to_string(),
    content="Adding a new stream ID would cause an overflow",
  )

  inspect(
    play_stream_error_device_not_available().to_string(),
    content="the device associated with the stream is no longer available",
  )
  inspect(
    pause_stream_error_device_not_available().to_string(),
    content="the device associated with the stream is no longer available",
  )

  inspect(
    stream_error_device_not_available().to_string(),
    content="The requested device is no longer available. For example, it has been unplugged.",
  )
  inspect(
    stream_error_stream_invalidated().to_string(),
    content="The stream configuration is no longer valid and must be rebuilt.",
  )
  inspect(
    stream_error_buffer_underrun().to_string(),
    content="Buffer underrun/overrun occurred.",
  )

  inspect(
    host_unavailable("anything").to_string(),
    content="the requested host is unavailable",
  )
}
