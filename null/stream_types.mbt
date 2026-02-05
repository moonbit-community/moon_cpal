///|
/// Null stream types (native targets).
///
/// The Null backend is used for portable tests and as a "no real I/O" host.

///|
pub enum StreamKind {
  Output
  Input
} derive(Show, Eq)

///|
// External object owning native stream resources.
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
