///|
extern "C" fn sleep_ms(ms : Int) -> Unit = "moon_cpal_sleep_ms"

///|
fn fill_silence(data : @moon_cpal.Data) -> Unit {
  let bytes = data.bytes()
  match data.sample_format() {
    @moon_cpal.SampleFormat::F32 => {
      let mut off = 0
      while off + 4 <= bytes.length() {
        bytes.unsafe_write_uint32_le(off, 0)
        off += 4
      }
    }
    @moon_cpal.SampleFormat::I16 => {
      let mut off = 0
      while off + 2 <= bytes.length() {
        bytes.unsafe_write_uint16_le(off, 0)
        off += 2
      }
    }
    _ => ()
  }
}

///|
fn main {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Windows {
    println("wasapi_stream_smoke: Windows-only (native)")
    return
  }

  let host = @wasapi.default_host()

  match host.default_output_device() {
    None => println("no default output device")
    Some(dev) => {
      println("output device: \{dev.name()}")
      let supported = try! dev.default_output_config()
      let cfg = supported.config()
      println("building output stream: \{supported}")
      let calls : Array[Int] = [0]
      let stream = try!
        dev.build_output_stream(
          cfg,
          fn(data, _info) {
            calls[0] = calls[0] + 1
            fill_silence(data)
          },
          fn(err) { println("stream error: \{err}") },
          None,
        )
      try! stream.play()
      sleep_ms(1000)
      try! stream.pause()
      stream.close()
      println("output stream ok (callbacks=\{calls[0]})")
    }
  }

  match host.default_input_device() {
    None => println("no default input device")
    Some(dev) => {
      println("input device: \{dev.name()}")
      let supported = try! dev.default_input_config()
      let cfg = supported.config()
      println("building input stream: \{supported}")
      let calls : Array[Int] = [0]
      let printed : Array[Bool] = [false]
      let stream = try!
        dev.build_input_stream(
          cfg,
          fn(data, info) {
            calls[0] = calls[0] + 1
            if !printed[0] {
              printed[0] = true
              println("input ts: \{info.timestamp()}")
              match data.try_as_f32() {
                None => println("input first buffer: (not f32)")
                Some(xs) =>
                  if xs.is_empty() {
                    println("input first buffer: empty")
                  } else {
                    println("input first sample: \{xs[0]}")
                  }
              }
            }
          },
          fn(err) { println("stream error: \{err}") },
          None,
        )
      try! stream.play()
      sleep_ms(1000)
      try! stream.pause()
      stream.close()
      println("input stream ok (callbacks=\{calls[0]})")
    }
  }
}

