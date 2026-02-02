///|
extern "C" fn sleep(secs : UInt) -> UInt = "sleep"

///|
fn main {
  let host = @macos.default_host()
  let maybe_out = try! host.default_output_device()
  match maybe_out {
    None => println("no default output device")
    Some(dev) => {
      println("output device: \{try! dev.name()}")
      let ranges = try! dev.supported_output_configs()
      if ranges.is_empty() {
        println("no supported output configs")
      } else {
        let supported = ranges[0].with_max_sample_rate()
        let cfg = supported.config()
        println("building output stream: \{supported}")
        let stream = try! dev.build_output_stream(
          cfg,
          fn(_data, _info) { () },
          fn(err) { println("stream error: \{err}") },
          None,
        )
        try! stream.play()
        ignore(sleep(1))
        try! stream.pause()
        stream.close()
        println("output stream ok")
      }
    }
  }
  let maybe_in = try! host.default_input_device()
  match maybe_in {
    None => println("no default input device")
    Some(dev) => {
      println("input device: \{try! dev.name()}")
      let ranges = try! dev.supported_input_configs()
      if ranges.is_empty() {
        println("no supported input configs")
      } else {
        let supported = ranges[0].with_max_sample_rate()
        let cfg = supported.config()
        println("building input stream: \{supported}")
        try
          dev.build_input_stream(
            cfg,
            fn(_data, _info) { () },
            fn(err) { println("stream error: \{err}") },
            None,
          )
        catch {
          e => {
            println("input stream build failed: \{e}")
            return
          }
        } noraise {
          stream => {
            try stream.play() catch {
              e => {
                println("input stream play failed: \{e}")
                stream.close()
                return
              }
            } noraise {
              _ => ()
            }
            ignore(sleep(1))
            try stream.pause() catch {
              e => println("input stream pause failed: \{e}")
            } noraise {
              _ => ()
            }
            stream.close()
            println("input stream ok")
          }
        }
      }
    }
  }
}
