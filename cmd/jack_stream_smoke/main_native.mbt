///|
extern "C" fn sleep_ms(ms : Int) -> Unit = "moon_cpal_sleep_ms"

///|
fn fill_silence_f32(data : @moon_cpal.Data) -> Unit {
  let bytes = data.bytes()
  let mut off = 0
  while off + 4 <= bytes.length() {
    bytes.unsafe_write_uint32_le(off, 0)
    off += 4
  }
}

///|
fn main {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    println("jack_stream_smoke: Linux-only (native)")
    return
  }
  let host = @jack.default_host()
  let devices = host.devices()
  println("devices: \{devices.length()}")
  for d in devices {
    println("  - \{d.name()}")
  }
  let dev = match host.default_output_device() {
    None => {
      println("no default device")
      panic()
    }
    Some(d) => d
  }
  let cfg = try dev.default_output_config() catch {
    e => {
      println("default output config failed: \{e}")
      panic()
    }
  } noraise {
    supported => supported.config()
  }

  // Output stream should always produce callbacks once the server is running.
  let calls : Array[Int] = [0]
  let out = try
    dev.build_output_stream(
      cfg,
      fn(data, _info) {
        calls[0] = calls[0] + 1
        fill_silence_f32(data)
      },
      fn(err) { println("stream error: \{err}") },
      None,
    )
  catch {
    e => {
      println("output stream build failed: \{e}")
      panic()
    }
  } noraise {
    s => s
  }
  try out.play() catch {
    e => {
      println("output stream play failed: \{e}")
      out.close()
      panic()
    }
  } noraise {
    _ => ()
  }
  sleep_ms(1000)
  try out.pause() catch {
    e => println("output stream pause failed: \{e}")
  } noraise {
    _ => ()
  }
  out.close()
  println("output callbacks: \{calls[0]}")
  if calls[0] <= 0 {
    println("no callbacks (is jackd running?)")
    panic()
  }

  // Input: best-effort. With the dummy driver this should still tick.
  let in_calls : Array[Int] = [0]
  let in_stream = try
    dev.build_input_stream(
      cfg,
      fn(_data, _info) { in_calls[0] = in_calls[0] + 1 },
      fn(err) { println("stream error: \{err}") },
      None,
    )
  catch {
    e => {
      println("input stream build failed: \{e}")
      return
    }
  } noraise {
    s => s
  }
  try in_stream.play() catch {
    e => {
      println("input stream play failed: \{e}")
      in_stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  sleep_ms(1000)
  in_stream.close()
  println("input callbacks: \{in_calls[0]}")
}
