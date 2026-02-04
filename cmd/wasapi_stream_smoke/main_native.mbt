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
  let devices = host.devices()
  println("devices: \{devices.length()}")
  for d in devices {
    println("  - \{d.name()}")
  }

  let mut out_ok = false
  for dev in devices {
    println("trying output device: \{dev.name()}")
    let cfg =
      try dev.default_output_config() catch {
        e => {
          println("default output config failed: \{e}")
          continue
        }
      } noraise {
        supported => supported.config()
      }
    let calls : Array[Int] = [0]
    try
      dev.build_output_stream(
        cfg,
        fn(data, _info) {
          calls[0] = calls[0] + 1
          fill_silence(data)
        },
        fn(err) { println("stream error: \{err}") },
        None,
      )
    catch {
      e => {
        println("output stream build failed: \{e}")
        continue
      }
    } noraise {
      stream => {
        try stream.play() catch {
          e => {
            println("output stream play failed: \{e}")
            stream.close()
            continue
          }
        } noraise {
          _ => ()
        }
        sleep_ms(1000)
        try stream.pause() catch {
          e => println("output stream pause failed: \{e}")
        } noraise {
          _ => ()
        }
        stream.close()
        println("output stream ok (callbacks=\{calls[0]})")
        out_ok = true
        break
      }
    }
  }
  if !out_ok {
    println("no usable output device")
  }

  let mut in_ok = false
  for dev in devices {
    println("trying input device: \{dev.name()}")
    let cfg =
      try dev.default_input_config() catch {
        e => {
          println("default input config failed: \{e}")
          continue
        }
      } noraise {
        supported => supported.config()
      }
    let calls : Array[Int] = [0]
    let printed : Array[Bool] = [false]
    try
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
    catch {
      e => {
        println("input stream build failed: \{e}")
        continue
      }
    } noraise {
      stream => {
        try stream.play() catch {
          e => {
            println("input stream play failed: \{e}")
            stream.close()
            continue
          }
        } noraise {
          _ => ()
        }
        sleep_ms(1000)
        try stream.pause() catch {
          e => println("input stream pause failed: \{e}")
        } noraise {
          _ => ()
        }
        stream.close()
        println("input stream ok (callbacks=\{calls[0]})")
        in_ok = true
        break
      }
    }
  }
  if !in_ok {
    println("no usable input device")
  }
}
