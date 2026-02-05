///|
test "jack supported configs reflect server sample rate/buffer size (best-effort)" {
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
          // If no JACK server is running, config queries will fail.
          inspect(true, content="true")
          return
        }
      } noraise {
        x => x
      }
      inspect(cfg.sample_format() == @core.SampleFormat::F32, content="true")
      inspect(cfg.sample_rate() > 0, content="true")
      match cfg.buffer_size() {
        Unknown => inspect(false, content="true")
        Range(min=mn, max=mx) => {
          inspect(mn > 0, content="true")
          inspect(mx == mn, content="true")
        }
      }
      let ranges = dev.supported_output_configs()
      inspect(ranges.length() == 10, content="true")

      // JACK reports a fixed sample rate and buffer size across all supported channels.
      for r in ranges {
        inspect(r.min_sample_rate() == cfg.sample_rate(), content="true")
        inspect(r.max_sample_rate() == cfg.sample_rate(), content="true")
        inspect(r.sample_format() == cfg.sample_format(), content="true")
        match r.buffer_size() {
          Unknown => inspect(false, content="true")
          Range(min=mn, max=mx) =>
            match cfg.buffer_size() {
              Unknown => inspect(false, content="true")
              Range(min=mn2, max=mx2) => {
                inspect(mn == mn2, content="true")
                inspect(mx == mx2, content="true")
              }
            }
        }
      }
    }
  }
}
