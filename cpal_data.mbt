///|
/// Dynamic audio buffer passed to stream callbacks (subset).
///
/// This is a MoonBit-specific API surface (not present in upstream `cpal`). It exists to
/// represent input/output audio buffers without relying on Rust-style generic slice callbacks.
///
/// Current scope:
/// - store raw bytes + `SampleFormat`
/// - safe typed decoders for a small set of formats (U8/I16/U16/F32), returning `Option`

///|
pub struct Data {
  sample_format : SampleFormat
  bytes : FixedArray[Byte]
} derive(Show, Eq)

///|
pub fn Data::new(
  sample_format : SampleFormat,
  bytes : FixedArray[Byte],
) -> Data {
  { sample_format, bytes }
}

///|
pub fn Data::sample_format(self : Data) -> SampleFormat {
  self.sample_format
}

///|
/// Number of samples in the buffer (floor if the byte length is not aligned to the sample size).
pub fn Data::len(self : Data) -> Int {
  let sz = self.sample_format.sample_size()
  if sz <= 0 {
    0
  } else {
    self.bytes.length() / sz
  }
}

///|
pub fn Data::bytes(self : Data) -> FixedArray[Byte] {
  self.bytes
}

///|
fn read_u16_le(bytes : FixedArray[Byte], offset : Int) -> UInt16? {
  match (bytes.get(offset), bytes.get(offset + 1)) {
    (Some(b0), Some(b1)) => {
      let v = b0.to_int() | (b1.to_int() << 8)
      Some(v.to_uint16())
    }
    _ => None
  }
}

///|
fn read_u32_le(bytes : FixedArray[Byte], offset : Int) -> UInt? {
  match
    (
      bytes.get(offset),
      bytes.get(offset + 1),
      bytes.get(offset + 2),
      bytes.get(offset + 3),
    ) {
    (Some(b0), Some(b1), Some(b2), Some(b3)) => {
      let w = b0.to_uint() |
        (b1.to_uint() << 8) |
        (b2.to_uint() << 16) |
        (b3.to_uint() << 24)
      Some(w)
    }
    _ => None
  }
}

///|
fn write_u16_le(bytes : FixedArray[Byte], offset : Int, v : UInt16) -> Bool {
  if offset < 0 || offset + 1 >= bytes.length() {
    return false
  }
  let w = v.to_uint().reinterpret_as_int()
  bytes[offset] = (w & 0xff).to_byte()
  bytes[offset + 1] = ((w >> 8) & 0xff).to_byte()
  true
}

///|
fn write_u32_le(bytes : FixedArray[Byte], offset : Int, v : UInt) -> Bool {
  if offset < 0 || offset + 3 >= bytes.length() {
    return false
  }
  let w = v.reinterpret_as_int()
  bytes[offset] = (w & 0xff).to_byte()
  bytes[offset + 1] = ((w >> 8) & 0xff).to_byte()
  bytes[offset + 2] = ((w >> 16) & 0xff).to_byte()
  bytes[offset + 3] = ((w >> 24) & 0xff).to_byte()
  true
}

///|
pub fn Data::try_as_u8(self : Data) -> Array[Byte]? {
  if self.sample_format != SampleFormat::U8 {
    return None
  }
  Some(self.bytes.op_as_view().to_array())
}

///|
pub fn Data::try_as_u16(self : Data) -> Array[UInt16]? {
  if self.sample_format != SampleFormat::U16 {
    return None
  }
  if self.bytes.length() % 2 != 0 {
    return None
  }
  let n = self.bytes.length() / 2
  let out : Array[UInt16] = []
  let mut i = 0
  while i < n {
    let off = i * 2
    match read_u16_le(self.bytes, off) {
      None => return None
      Some(v) => out.push(v)
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_i16(self : Data) -> Array[Int16]? {
  if self.sample_format != SampleFormat::I16 {
    return None
  }
  if self.bytes.length() % 2 != 0 {
    return None
  }
  let n = self.bytes.length() / 2
  let out : Array[Int16] = []
  let mut i = 0
  while i < n {
    let off = i * 2
    match read_u16_le(self.bytes, off) {
      None => return None
      Some(v) => out.push(Int16::reinterpret_from_uint16(v))
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_f32(self : Data) -> Array[Float]? {
  if self.sample_format != SampleFormat::F32 {
    return None
  }
  if self.bytes.length() % 4 != 0 {
    return None
  }
  let n = self.bytes.length() / 4
  let out : Array[Float] = []
  let mut i = 0
  while i < n {
    let off = i * 4
    match read_u32_le(self.bytes, off) {
      None => return None
      Some(bits) => out.push(Float::reinterpret_from_uint(bits))
    }
    i = i + 1
  }
  Some(out)
}

///|
/// Fill the underlying buffer with zeros (silence for the supported formats).
pub fn Data::clear(self : Data) -> Unit {
  let mut i = 0
  while i < self.bytes.length() {
    self.bytes[i] = (0 : Int).to_byte()
    i = i + 1
  }
}

///|
/// Best-effort encoder for U8 output buffers.
pub fn Data::write_u8(self : Data, samples : Array[Byte]) -> Bool {
  if self.sample_format != SampleFormat::U8 {
    return false
  }
  if self.bytes.length() != samples.length() {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    self.bytes[i] = samples[i]
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for U16 (little-endian) output buffers.
pub fn Data::write_u16(self : Data, samples : Array[UInt16]) -> Bool {
  if self.sample_format != SampleFormat::U16 {
    return false
  }
  if self.bytes.length() != samples.length() * 2 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    if !write_u16_le(self.bytes, i * 2, samples[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for I16 (little-endian) output buffers.
pub fn Data::write_i16(self : Data, samples : Array[Int16]) -> Bool {
  if self.sample_format != SampleFormat::I16 {
    return false
  }
  if self.bytes.length() != samples.length() * 2 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    if !write_u16_le(self.bytes, i * 2, samples[i].reinterpret_as_uint16()) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for F32 (IEEE-754, little-endian) output buffers.
pub fn Data::write_f32(self : Data, samples : Array[Float]) -> Bool {
  if self.sample_format != SampleFormat::F32 {
    return false
  }
  if self.bytes.length() != samples.length() * 4 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    if !write_u32_le(self.bytes, i * 4, samples[i].reinterpret_as_uint()) {
      return false
    }
    i = i + 1
  }
  true
}
