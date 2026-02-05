///|
test "jack fixed buffer 0 is invalid argument (unit)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let dev : Device = {
    id: "moon_cpal_out",
    direction: @moon_cpal.DeviceDirection::output(),
  }
  let sc = @moon_cpal.StreamConfig::new(
    2,
    48000,
    @moon_cpal.BufferSize::fixed(0),
  )
  try
    dev.build_output_stream_raw(
      sc,
      @moon_cpal.SampleFormat::F32,
      fn(_d, _info) { () },
      fn(_e) { () },
      None,
    )
  catch {
    e =>
      match e {
        @moon_cpal.BuildStreamError::InvalidArgument =>
          inspect(true, content="true")
        _ => inspect(false, content="true")
      }
  } noraise {
    s => {
      s.close()
      inspect(false, content="true")
    }
  }
}

///|
test "jack fixed buffer mismatch fails when server config known (best-effort)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  match default_server_config() {
    None => {
      inspect(true, content="true")
      return
    }
    Some((_sr, buf)) => {
      let dev : Device = {
        id: "moon_cpal_out",
        direction: @moon_cpal.DeviceDirection::output(),
      }
      let want = buf + 1
      let sc = @moon_cpal.StreamConfig::new(
        2,
        48000,
        @moon_cpal.BufferSize::fixed(want),
      )
      try
        dev.build_output_stream_raw(
          sc,
          @moon_cpal.SampleFormat::F32,
          fn(_d, _info) { () },
          fn(_e) { () },
          None,
        )
      catch {
        e =>
          match e {
            @moon_cpal.BuildStreamError::StreamConfigNotSupported =>
              inspect(true, content="true")
            _ => inspect(false, content="true")
          }
      } noraise {
        s => {
          s.close()
          inspect(false, content="true")
        }
      }
    }
  }
}
