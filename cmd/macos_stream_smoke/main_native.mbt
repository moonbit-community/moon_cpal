///|
extern "C" fn sleep(secs : UInt) -> UInt = "sleep"

///|
extern "C" fn sin(x : Double) -> Double = "sin"

///|
fn main {
  let host = @macos.default_host()
  let maybe_out = host.default_output_device()
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
        let phase : Array[Double] = [0.0]
        let calls : Array[Int] = [0]
        let last_cb : Array[@moon_cpal.StreamInstant?] = [None]
        let sr = cfg.sample_rate.to_double()
        let ch = cfg.channels
        let two_pi = 6.283185307179586
        let freq = 440.0
        let step = two_pi * freq / sr
        try
          dev.build_output_stream(
            cfg,
            fn(data, info) {
              calls[0] = calls[0] + 1
              let now = info.timestamp().callback()
              match last_cb[0] {
                None => last_cb[0] = Some(now)
                Some(prev) => {
                  if now.duration_since(prev) is None {
                    println("non-monotonic output callback timestamp")
                    panic()
                  }
                  last_cb[0] = Some(now)
                }
              }
              match data.sample_format() {
                @moon_cpal.SampleFormat::F32 => {
                  let bytes = data.bytes()
                  let n_samples = bytes.length() / 4
                  let frames = if ch > 0 { n_samples / ch } else { 0 }
                  let mut off = 0
                  for _ in 0..<frames {
                    let v = Float::from_double(sin(phase[0]) * 0.2)
                    phase[0] = phase[0] + step
                    // Keep phase bounded to avoid extreme growth over long runs.
                    if phase[0] > two_pi {
                      phase[0] = phase[0] - two_pi
                    }
                    let bits = Float::reinterpret_as_uint(v)
                    for _ in 0..<ch {
                      bytes.unsafe_write_uint32_le(off, bits)
                      off = off + 4
                    }
                  }
                }
                @moon_cpal.SampleFormat::I16 => {
                  let bytes = data.bytes()
                  let n_samples = bytes.length() / 2
                  let frames = if ch > 0 { n_samples / ch } else { 0 }
                  let mut off = 0
                  for _ in 0..<frames {
                    let v = sin(phase[0]) * 0.2
                    phase[0] = phase[0] + step
                    if phase[0] > two_pi {
                      phase[0] = phase[0] - two_pi
                    }
                    // Scale to i16.
                    let s = (v * 32767.0).to_int()
                    let s = if s < -32768 {
                      -32768
                    } else if s > 32767 {
                      32767
                    } else {
                      s
                    }
                    let bits = Int16::from_int(s).reinterpret_as_uint16()
                    for _ in 0..<ch {
                      bytes.unsafe_write_uint16_le(off, bits)
                      off = off + 2
                    }
                  }
                }
                _ => ()
              }
            },
            fn(err) { println("stream error: \{err}") },
            None,
          )
        catch {
          e => {
            println("output stream build failed: \{e}")
            return
          }
        } noraise {
          stream => {
            try stream.play() catch {
              e => {
                println("output stream play failed: \{e}")
                stream.close()
                return
              }
            } noraise {
              _ => ()
            }
            ignore(sleep(1))
            try stream.pause() catch {
              e => println("output stream pause failed: \{e}")
            } noraise {
              _ => ()
            }
            let paused = calls[0]
            ignore(sleep(1))
            if calls[0] > paused + 1 {
              println(
                "output callbacks continued after pause (before=\{paused} after=\{calls[0]})",
              )
              stream.close()
              panic()
            }
            stream.close()
            println("output stream ok (callbacks=\{calls[0]})")
          }
        }
      }
    }
  }
  let maybe_in = host.default_input_device()
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
        let calls : Array[Int] = [0]
        let printed : Array[Bool] = [false]
        let last_cb : Array[@moon_cpal.StreamInstant?] = [None]
        try
          dev.build_input_stream(
            cfg,
            fn(data, info) {
              calls[0] = calls[0] + 1
              let now = info.timestamp().callback()
              match last_cb[0] {
                None => last_cb[0] = Some(now)
                Some(prev) => {
                  if now.duration_since(prev) is None {
                    println("non-monotonic input callback timestamp")
                    panic()
                  }
                  last_cb[0] = Some(now)
                }
              }
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
            let paused = calls[0]
            ignore(sleep(1))
            if calls[0] > paused + 1 {
              println(
                "input callbacks continued after pause (before=\{paused} after=\{calls[0]})",
              )
              stream.close()
              panic()
            }
            stream.close()
            println("input stream ok")
            println("input callbacks=\{calls[0]}")
          }
        }
      }
    }
  }
}
