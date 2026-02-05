///|
/// Null stream type.
///
/// This mirrors upstream `cpal::host::null::Stream`, which cannot be played/paused.

///|
pub struct Stream {
  _unit : Unit
} derive(Show, Eq)

///|
let _unused_stream_for_lint : Stream = { _unit: () }

///|
pub fn Stream::play(_self : Stream) -> Unit raise @moon_cpal.PlayStreamError {
  raise @moon_cpal.play_stream_error_backend_specific(
    "null stream play: unimplemented",
  )
}

///|
pub fn Stream::pause(_self : Stream) -> Unit raise @moon_cpal.PauseStreamError {
  raise @moon_cpal.pause_stream_error_backend_specific(
    "null stream pause: unimplemented",
  )
}

///|
pub fn Stream::close(_self : Stream) -> Unit {
  ()
}
