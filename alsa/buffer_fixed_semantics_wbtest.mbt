///|
test "alsa fixed buffer 0 is invalid argument (best-effort)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
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
      let sc = @moon_cpal.StreamConfig::new(
        cfg.channels(),
        cfg.sample_rate(),
        @moon_cpal.BufferSize::fixed(0),
      )
      try
        dev.build_output_stream_raw(
          sc,
          cfg.sample_format(),
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
  }
}

///|
test "alsa fixed buffer larger than supported range fails (best-effort)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
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
      let big = 1000000000
      let sc = @moon_cpal.StreamConfig::new(
        cfg.channels(),
        cfg.sample_rate(),
        @moon_cpal.BufferSize::fixed(big),
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
          inspect(false, content="true")
        }
      }
    }
  }
}
