///|
test "wasapi output configs reflect device mix format (best-effort)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None =>
      // Some environments may not expose a default render endpoint.
      inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_output_config() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      inspect(cfg.channels() > 0, content="true")
      inspect(cfg.sample_rate() > 0, content="true")
      let ranges = dev.supported_output_configs()
      inspect(ranges.length() > 0, content="true")
      let mut found = false
      for r in ranges {
        if r.channels() == cfg.channels() &&
          r.min_sample_rate() == cfg.sample_rate() &&
          r.max_sample_rate() == cfg.sample_rate() &&
          r.sample_format() == cfg.sample_format() &&
          r.buffer_size() == cfg.buffer_size() {
          found = true
          break
        }
      }
      inspect(found, content="true")
    }
  }
}

///|
test "wasapi data_flow gating (best-effort)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  for dev in host.devices() {
    if dev.id == "default" {
      continue
    }
    match data_flow_tag(dev.id) {
      None => ()
      Some(tag) =>
        if tag == 1 {
          // Capture device: output should be empty.
          inspect(dev.supported_output_configs().length() == 0, content="true")
        } else if tag == 2 {
          // Render device: input should be empty.
          inspect(dev.supported_input_configs().length() == 0, content="true")
        }
    }
  }
  inspect(true, content="true")
}
