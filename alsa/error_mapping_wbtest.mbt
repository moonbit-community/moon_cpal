///|
test "alsa errno mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  inspect(
    alsa_stream_error_from_errno(-19, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_stream_error_from_errno(-2, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_stream_error_from_errno(-1, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_stream_error_from_errno(-13, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(alsa_stream_error_from_errno(-32, "xrun"), content="BufferUnderrun")
  inspect(
    alsa_stream_error_from_errno(-5, "snd_pcm_writei"),
    content="StreamInvalidated",
  )
  inspect(
    alsa_stream_error_from_errno(-77, "snd_pcm_writei"),
    content="StreamInvalidated",
  )
  inspect(
    alsa_stream_error_from_errno(-86, "snd_pcm_writei"),
    content="StreamInvalidated",
  )
  inspect(
    alsa_build_error_from_errno(-19, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-2, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-1, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-13, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-524, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-16, "snd_pcm_open"),
    content="DeviceBusy",
  )
  inspect(
    alsa_build_error_from_errno(-11, "snd_pcm_open"),
    content="DeviceBusy",
  )
  inspect(
    alsa_build_error_from_errno(-22, "snd_pcm_hw_params"),
    content="InvalidArgument",
  )
}
