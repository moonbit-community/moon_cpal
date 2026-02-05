///|
extern "C" fn sleep_ms(ms : Int) -> Unit = "moon_cpal_sleep_ms"

///|
fn wait_until(counter : Array[Int], min_count : Int, timeout_ms : Int) -> Bool {
  let mut waited = 0
  while waited < timeout_ms {
    if counter[0] >= min_count {
      return true
    }
    sleep_ms(10)
    waited = waited + 10
  }
  counter[0] >= min_count
}

///|
test "alsa output stream: no callbacks before play; pause/close stops callbacks (best-effort)" {
  if @moon_cpal.native_os() != @moon_cpal.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  let dev = match host.default_output_device() {
    None => {
      inspect(true, content="true")
      return
    }
    Some(d) => d
  }
  let cfg = try dev.default_output_config() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    supported => supported.config()
  }
  let calls : Array[Int] = [0]
  let stream = try
    dev.build_output_stream(
      cfg,
      fn(data, _info) {
        calls[0] = calls[0] + 1
        data.clear()
      },
      fn(_err) { panic() },
      None,
    )
  catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    s => s
  }
  sleep_ms(50)
  inspect(calls[0] == 0, content="true")
  try stream.play() catch {
    _ => {
      inspect(true, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  inspect(wait_until(calls, 1, 2000), content="true")
  try stream.pause() catch {
    _ => {
      inspect(true, content="true")
      stream.close()
      return
    }
  } noraise {
    _ => ()
  }
  let paused = calls[0]
  sleep_ms(100)
  inspect(calls[0] <= paused + 1, content="true")
  stream.close()
  let closed = calls[0]
  sleep_ms(100)
  inspect(calls[0] <= closed + 1, content="true")
}
