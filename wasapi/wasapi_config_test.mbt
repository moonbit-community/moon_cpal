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
      let r = ranges[0]
      inspect(r.channels() == cfg.channels(), content="true")
      inspect(r.min_sample_rate() == cfg.sample_rate(), content="true")
      inspect(r.max_sample_rate() == cfg.sample_rate(), content="true")
      inspect(r.sample_format() == cfg.sample_format(), content="true")
    }
  }
}
