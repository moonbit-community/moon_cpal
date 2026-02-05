///|
extern "C" fn sleep_ms(ms : Int) -> Unit = "moon_cpal_sleep_ms"

///|
fn fill_silence(data : @core.Data) -> Unit {
  let bytes = data.bytes()
  match data.sample_format() {
    @core.SampleFormat::F32 => {
      let mut off = 0
      while off + 4 <= bytes.length() {
        bytes.unsafe_write_uint32_le(off, 0)
        off += 4
      }
    }
    @core.SampleFormat::I16 => {
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
  if @core.native_os() != @core.NativeOs::Linux {
    println("alsa_stream_smoke: Linux-only (native)")
    return
  }
  let host = @alsa.default_host()
  let devices = host.devices()
  println("devices: \{devices.length()}")
  for d in devices {
    println("  - \{d.name()}")
  }
  let mut out_ok = false
  for dev in devices {
    println("trying output device: \{dev.name()}")
    let calls : Array[Int] = [0]
    let last_cb : Array[@moon_cpal.StreamInstant?] = [None]
    let first_frames : Array[Int] = [0]
    let cfg = try dev.default_output_config() catch {
      e => {
        println("default output config failed: \{e}")
        continue
      }
    } noraise {
      supported => supported.config()
    }
    try
      dev.build_output_stream(
        cfg,
        fn(data, info) {
          calls[0] = calls[0] + 1
          if first_frames[0] == 0 {
            let n = data.len()
            let ch = cfg.channels
            if ch > 0 {
              first_frames[0] = n / ch
            }
          }
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
        let paused = calls[0]
        sleep_ms(200)
        if calls[0] > paused + 1 {
          println(
            "output callbacks continued after pause (before=\{paused} after=\{calls[0]})",
          )
          stream.close()
          panic()
        }
        stream.close()
        println("output stream ok (callbacks=\{calls[0]})")

        // Validate BufferSize::Fixed semantics: re-build with fixed size equal to the observed
        // callback frame count and ensure callback buffer sizing matches.
        if first_frames[0] > 0 && cfg.channels > 0 {
          let fixed_cfg = @moon_cpal.StreamConfig::new(
            cfg.channels,
            cfg.sample_rate,
            @moon_cpal.BufferSize::fixed(first_frames[0]),
          )
          let fixed_calls : Array[Int] = [0]
          let fixed_stream = try
            dev.build_output_stream(
              fixed_cfg,
              fn(data, _info) {
                fixed_calls[0] = fixed_calls[0] + 1
                if data.len() != first_frames[0] * cfg.channels {
                  println(
                    "fixed output callback len mismatch: got=\{data.len()} expected=\{first_frames[0] * cfg.channels}",
                  )
                  panic()
                }
                fill_silence(data)
              },
              fn(err) { println("stream error: \{err}") },
              None,
            )
          catch {
            e => {
              println("fixed output stream build failed: \{e}")
              panic()
            }
          } noraise {
            s => s
          }
          try fixed_stream.play() catch {
            e => {
              println("fixed output stream play failed: \{e}")
              fixed_stream.close()
              panic()
            }
          } noraise {
            _ => ()
          }
          sleep_ms(200)
          fixed_stream.close()
          println("fixed output stream ok (callbacks=\{fixed_calls[0]})")
        }
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
    let calls : Array[Int] = [0]
    let printed : Array[Bool] = [false]
    let last_cb : Array[@moon_cpal.StreamInstant?] = [None]
    let first_frames : Array[Int] = [0]
    let cfg = try dev.default_input_config() catch {
      e => {
        println("default input config failed: \{e}")
        continue
      }
    } noraise {
      supported => supported.config()
    }
    try
      dev.build_input_stream(
        cfg,
        fn(data, info) {
          calls[0] = calls[0] + 1
          if first_frames[0] == 0 {
            let n = data.len()
            let ch = cfg.channels
            if ch > 0 {
              first_frames[0] = n / ch
            }
          }
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
        let paused = calls[0]
        sleep_ms(200)
        if calls[0] > paused + 1 {
          println(
            "input callbacks continued after pause (before=\{paused} after=\{calls[0]})",
          )
          stream.close()
          panic()
        }
        stream.close()
        println("input stream ok (callbacks=\{calls[0]})")

        // Validate BufferSize::Fixed semantics (best-effort) using the observed callback size.
        if first_frames[0] > 0 && cfg.channels > 0 {
          let fixed_cfg = @moon_cpal.StreamConfig::new(
            cfg.channels,
            cfg.sample_rate,
            @moon_cpal.BufferSize::fixed(first_frames[0]),
          )
          let fixed_calls : Array[Int] = [0]
          let fixed_stream = try
            dev.build_input_stream(
              fixed_cfg,
              fn(data, _info) {
                fixed_calls[0] = fixed_calls[0] + 1
                if data.len() != first_frames[0] * cfg.channels {
                  println(
                    "fixed input callback len mismatch: got=\{data.len()} expected=\{first_frames[0] * cfg.channels}",
                  )
                  panic()
                }
              },
              fn(err) { println("stream error: \{err}") },
              None,
            )
          catch {
            e => {
              println("fixed input stream build failed: \{e}")
              panic()
            }
          } noraise {
            s => s
          }
          try fixed_stream.play() catch {
            e => {
              println("fixed input stream play failed: \{e}")
              fixed_stream.close()
              panic()
            }
          } noraise {
            _ => ()
          }
          sleep_ms(200)
          fixed_stream.close()
          println("fixed input stream ok (callbacks=\{fixed_calls[0]})")
        }
        in_ok = true
        break
      }
    }
  }
  if !in_ok {
    println("no usable input device")
  }
}
