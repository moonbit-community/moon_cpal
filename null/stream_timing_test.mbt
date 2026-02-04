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
test "null stream: no callbacks before play; pause stops callbacks (best-effort)" {
  let host = default_host()
  let dev = match host.default_output_device() {
    None => {
      inspect(false, content="true")
      return
    }
    Some(d) => d
  }

  let frames = 128
  let ch = 2
  let cfg = @moon_cpal.StreamConfig::new(
    ch,
    48000,
    @moon_cpal.BufferSize::fixed(frames),
  )

  let calls : Array[Int] = [0]
  let seen_sizes : Array[Int] = [0]
  let stream = try dev.build_output_stream(
    cfg,
    fn(data, _info) {
      calls[0] = calls[0] + 1
      // BufferSize::Fixed must be exact: samples == frames * channels.
      if data.len() != frames * ch {
        panic()
      }
      seen_sizes[0] = seen_sizes[0] + 1
      data.clear()
    },
    fn(_err) { panic() },
    None,
  ) catch {
    _ => {
      inspect(false, content="true")
      return
    }
  } noraise {
    s => s
  }

  // Must not call callbacks before play.
  sleep_ms(50)
  inspect(calls[0] == 0, content="true")

  try stream.play() catch {
    _ => {
      inspect(false, content="true")
      stream.close()
      return
    }
  } noraise { _ => () }

  inspect(wait_until(calls, 3, 2000), content="true")

  try stream.pause() catch {
    _ => {
      inspect(false, content="true")
      stream.close()
      return
    }
  } noraise { _ => () }

  let paused = calls[0]
  sleep_ms(100)
  // Allow at most one in-flight callback.
  inspect(calls[0] <= paused + 1, content="true")
  inspect(seen_sizes[0] > 0, content="true")

  stream.close()
}

///|
test "null stream: close stops callbacks; play after close fails" {
  let host = default_host()
  let dev = match host.default_input_device() {
    None => {
      inspect(false, content="true")
      return
    }
    Some(d) => d
  }

  let cfg = @moon_cpal.StreamConfig::new(
    1,
    48000,
    @moon_cpal.BufferSize::fixed(64),
  )
  let calls : Array[Int] = [0]

  let stream = try dev.build_input_stream(
    cfg,
    fn(_data, _info) { calls[0] = calls[0] + 1 },
    fn(_err) { panic() },
    None,
  ) catch {
    _ => {
      inspect(false, content="true")
      return
    }
  } noraise {
    s => s
  }

  try stream.play() catch {
    _ => {
      inspect(false, content="true")
      stream.close()
      return
    }
  } noraise { _ => () }

  inspect(wait_until(calls, 2, 2000), content="true")

  stream.close()
  let closed = calls[0]
  sleep_ms(100)
  inspect(calls[0] <= closed + 1, content="true")

  try stream.play() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    _ => inspect(false, content="true")
  }
}
