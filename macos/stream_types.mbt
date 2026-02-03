///|
/// CoreAudio stream types (macOS).
///
/// The actual implementation is split by target:
/// - `stream_native.mbt` (native target): AudioQueue-backed streams.
/// - `stream_stub.mbt`   (non-native): raises backend-specific errors.

///|
pub enum StreamKind {
  Output
  Input
} derive(Show, Eq)

///|
// An external object that owns native stream resources.
//
// On native targets this is backed by `moonbit_make_external_object` with a finalizer.
// On non-native targets it is an opaque stub value.
type StreamOwner

///|
pub struct Stream {
  kind : StreamKind
  handle : UInt64
  owner : StreamOwner
}

///|
pub impl Eq for Stream with equal(self : Stream, other : Stream) -> Bool {
  self.kind == other.kind && self.handle == other.handle
}

///|
pub impl Show for Stream with output(self : Stream, logger : &Logger) -> Unit {
  logger.write_string("\{self.kind}(\{self.handle})")
}
