///|
test "alsa default config matches supported configs (best-effort)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let cfg = try dev.default_output_config() catch {
        _ => {
          // Some CI environments may not expose a working default PCM even with `.asoundrc`.
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      let ranges = try dev.supported_output_configs() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        xs => xs
      }
      inspect(ranges.length() > 0, content="true")

      // Ensure `cfg` is representable by at least one returned range.
      let mut ok = false
      for r in ranges {
        if r.channels() == cfg.channels() &&
          r.sample_format() == cfg.sample_format() &&
          r.min_sample_rate() <= cfg.sample_rate() &&
          cfg.sample_rate() <= r.max_sample_rate() {
          ok = true
        }
      }
      inspect(ok, content="true")
    }
  }
}

///|
test "alsa supported configs include sane buffer size ranges (best-effort)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) => {
      let ranges = try dev.supported_output_configs() catch {
        _ => {
          inspect(true, content="true")
          return
        }
      } noraise {
        xs => xs
      }
      if ranges.length() == 0 {
        inspect(true, content="true")
        return
      }
      let r = ranges[0]
      match r.buffer_size() {
        Unknown => inspect(true, content="true")
        Range(min=mn, max=mx) => {
          inspect(mn > 0, content="true")
          inspect(mx >= mn, content="true")
        }
      }
    }
  }
}
