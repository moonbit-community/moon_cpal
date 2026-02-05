///|
test "wasapi fixed buffer larger than device buffer fails (best-effort)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_output_config() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      let max_buf = match cfg.buffer_size() {
        @core.SupportedBufferSize::Unknown => {
          inspect(true, content="true")
          return
        }
        @core.SupportedBufferSize::Range(max=mx, ..) => mx
      }
      if max_buf >= 2147483647 {
        inspect(true, content="true")
        return
      }
      let want = max_buf + 1
      let sc = @core.StreamConfig::new(
        cfg.channels(),
        cfg.sample_rate(),
        @core.BufferSize::fixed(want),
      )
      let got = try
        dev.build_output_stream_raw(
          sc,
          cfg.sample_format(),
          fn(_d, _info) { () },
          fn(_e) { () },
          None,
        )
      catch {
        _ => None
      } noraise {
        s => Some(s)
      }
      match got {
        None => inspect(true, content="true")
        Some(s) => {
          s.close()
          inspect(false, content="false")
        }
      }
    }
  }
}

///|
test "wasapi fixed buffer 0 is stream_config_not_supported (unit)" {
  if @core.native_os() != @core.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let dev : Device = { id: "does_not_matter" }
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
