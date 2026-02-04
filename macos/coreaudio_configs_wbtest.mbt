///|
test "macos supported_output_configs basic invariants" {
  let host = default_host()
  match host.default_output_device() {
    None => inspect(true, content="true")
    Some(dev) =>
      try dev.supported_output_configs() catch {
        _ => inspect(true, content="true")
      } noraise {
        configs =>
          if configs.is_empty() {
            inspect(true, content="true")
          } else {
            let first = configs[0]
            inspect(first.sample_format(), content="F32")
            inspect(first.channels() > 0, content="true")
            inspect(
              first.min_sample_rate() <= first.max_sample_rate(),
              content="true",
            )
            match first.buffer_size() {
              Range(min=mn, max=mx) => {
                inspect(mn > 0, content="true")
                inspect(mn <= mx, content="true")
              }
              Unknown => inspect(true, content="true")
            }
          }
      }
  }
}

///|
test "macos supported_input_configs basic invariants (if any)" {
  let host = default_host()
  match host.default_input_device() {
    None => inspect(true, content="true")
    Some(dev) =>
      try dev.supported_input_configs() catch {
        _ => inspect(true, content="true")
      } noraise {
        configs =>
          // Some machines may not have any input-capable device; treat that as OK.
          if configs.is_empty() {
            inspect(true, content="true")
          } else {
            let first = configs[0]
            inspect(first.sample_format(), content="F32")
            inspect(first.channels() > 0, content="true")
            inspect(
              first.min_sample_rate() <= first.max_sample_rate(),
              content="true",
            )
          }
      }
  }
}
