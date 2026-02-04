///|
test "macos default_output_config basic invariants" {
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) =>
      try dev.default_output_config() catch {
        // Some devices may expose a default format that cpal considers unsupported.
        StreamTypeNotSupported => inspect(true, content="true")
        DeviceNotAvailable => inspect(true, content="true")
        DeviceBusy => inspect(true, content="true")
        BackendSpecific(_) => inspect(true, content="true")
      } noraise {
        cfg => {
          inspect(cfg.channels() > 0, content="true")
          inspect(cfg.sample_rate() > 0, content="true")
          match cfg.sample_format() {
            F32 => inspect(true, content="true")
            I16 => inspect(true, content="true")
            _ => inspect(true, content="true")
          }
          match cfg.buffer_size() {
            Range(min=mn, max=mx) => {
              inspect(mn > 0, content="true")
              inspect(mn <= mx, content="true")
            }
            Unknown => inspect(true, content="true")
          }

          // Best-effort parity check: the default sample rate should fall within at least one
          // supported output config range if those ranges are available.
          try dev.supported_output_configs() catch {
            _ => ()
          } noraise {
            ranges =>
              if ranges.is_empty() {
                ()
              } else {
                let sr = cfg.sample_rate()
                let mut ok = false
                for r in ranges {
                  if r.min_sample_rate() <= sr && sr <= r.max_sample_rate() {
                    ok = true
                    break
                  }
                }
                inspect(ok, content="true")
              }
          }
        }
      }
  }
}

///|
test "macos default_input_config basic invariants (if any)" {
  let host = default_host()
  match host.default_input_device() {
    None => inspect(true, content="true")
    Some(dev) =>
      try dev.default_input_config() catch {
        StreamTypeNotSupported => inspect(true, content="true")
        DeviceNotAvailable => inspect(true, content="true")
        DeviceBusy => inspect(true, content="true")
        BackendSpecific(_) => inspect(true, content="true")
      } noraise {
        cfg => {
          inspect(cfg.channels() > 0, content="true")
          inspect(cfg.sample_rate() > 0, content="true")
        }
      }
  }
}
