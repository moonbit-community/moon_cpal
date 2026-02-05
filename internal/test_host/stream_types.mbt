///|
/// Stream types for the internal test backend.

///|
pub enum StreamKind {
  Input
  Output
} derive(Show, Eq)

///|
type StreamOwner

///|
pub struct Stream {
  kind : StreamKind
  owner : StreamOwner
}

///|
pub impl Show for Stream with output(self : Stream, logger : &Logger) -> Unit {
  logger.write_string("Stream(")
  logger.write_string(self.kind.to_string())
  logger.write_string(")")
}
