///|
fn main {
  // Simple smoke test for CoreAudio bindings (native + macOS only).
  let ids = try! @macos.device_ids()
  println("devices: \{ids.length()}")
  for id in ids {
    let name = try! @macos.device_name(id)
    println("\{id}: \{name}")
  }
  try @macos.default_output_device_id() catch {
    _ => println("default output error")
  } noraise {
    Some(id) => {
      println("default output: \{id}")
      let cfgs = try! @macos.supported_output_configs(id)
      println("supported output configs: \{cfgs.length()}")
      if cfgs.length() > 0 {
        println("\{cfgs[0]}")
      }
      try @macos.default_output_config(id) catch {
        _ => println("default output config error")
      } noraise {
        cfg => println("default output config: \{cfg}")
      }
    }
    None => println("default output: none")
  }
  try @macos.default_input_device_id() catch {
    _ => println("default input error")
  } noraise {
    Some(id) => {
      println("default input: \{id}")
      try @macos.default_input_config(id) catch {
        _ => println("default input config error")
      } noraise {
        cfg => println("default input config: \{cfg}")
      }
    }
    None => println("default input: none")
  }
}
