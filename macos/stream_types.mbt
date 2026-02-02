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
pub struct Stream {
  kind : StreamKind
  handle : UInt64
} derive(Show, Eq)
