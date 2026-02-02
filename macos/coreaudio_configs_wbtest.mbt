///|
test "macos supported_output_configs basic invariants" {
  let host = default_host()
  let dev = match (try! host.default_output_device()) {
    Some(d) => d
    None => panic()
  }
  let configs = try! dev.supported_output_configs()
  inspect(configs.length() > 0, content="true")
  let first = configs[0]
  inspect(first.sample_format(), content="F32")
  inspect(first.channels() > 0, content="true")
  inspect(first.min_sample_rate() <= first.max_sample_rate(), content="true")
  match first.buffer_size() {
    Range(min=mn, max=mx) => {
      inspect(mn > 0, content="true")
      inspect(mn <= mx, content="true")
    }
    Unknown => panic()
  }
}

///|
test "macos supported_input_configs basic invariants (if any)" {
  let host = default_host()
  match (try! host.default_input_device()) {
    None => inspect(true, content="true")
    Some(dev) => {
      let configs = try! dev.supported_input_configs()
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
