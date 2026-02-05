///|
test "jack fixed buffer 0 is stream_config_not_supported (unit)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let dev : Device = {
    id: "moon_cpal_out",
    direction: @core.DeviceDirection::output(),
  }
  let sc = @core.StreamConfig::new(2, 48000, @core.BufferSize::fixed(0))
  try
    dev.build_output_stream_raw(
      sc,
      @core.SampleFormat::F32,
      fn(_d, _info) { () },
      fn(_e) { () },
      None,
    )
  catch {
    e =>
      match e {
        @core.BuildStreamError::StreamConfigNotSupported =>
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
  if @core.native_os() != @core.NativeOs::Linux {
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
        direction: @core.DeviceDirection::output(),
      }
      let want = buf + 1
      let sc = @core.StreamConfig::new(2, 48000, @core.BufferSize::fixed(want))
      try
        dev.build_output_stream_raw(
          sc,
          @core.SampleFormat::F32,
          fn(_d, _info) { () },
          fn(_e) { () },
          None,
        )
      catch {
        e =>
          match e {
            @core.BuildStreamError::StreamConfigNotSupported =>
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
