///|
/// WASAPI stream types (Windows).
///
/// Implementations are split by target:
/// - `stream_native.mbt` (native): real WASAPI I/O.
/// - `stream.mbt`        (non-native): stubs.

///|
pub enum StreamKind {
  Output
  Input
} derive(Show, Eq)

///|
// An external object that owns native stream resources.
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
