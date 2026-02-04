///|
/// Dynamic audio buffer passed to stream callbacks (subset).
///
/// This is a MoonBit-specific API surface (not present in upstream `cpal`). It exists to
/// represent input/output audio buffers without relying on Rust-style generic slice callbacks.
///
/// Current scope:
/// - store raw bytes + `SampleFormat`
/// - safe typed decoders for common PCM formats, returning `Option`
///   - signed: I8/I16/I24/I32/I64
///   - unsigned: U8/U16/U24/U32/U64
///   - float: F32/F64
///   - (DSD formats are intentionally not decoded at this layer yet)

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
fn read_u64_le(bytes : FixedArray[Byte], offset : Int) -> UInt64? {
  match
    (
      bytes.get(offset),
      bytes.get(offset + 1),
      bytes.get(offset + 2),
      bytes.get(offset + 3),
      bytes.get(offset + 4),
      bytes.get(offset + 5),
      bytes.get(offset + 6),
      bytes.get(offset + 7),
    ) {
    (Some(b0), Some(b1), Some(b2), Some(b3), Some(b4), Some(b5), Some(b6), Some(b7)) => {
      let lo : UInt64 = b0.to_uint64() |
        (b1.to_uint64() << 8) |
        (b2.to_uint64() << 16) |
        (b3.to_uint64() << 24)
      let hi : UInt64 = b4.to_uint64() |
        (b5.to_uint64() << 8) |
        (b6.to_uint64() << 16) |
        (b7.to_uint64() << 24)
      Some(lo | (hi << 32))
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
fn write_u64_le(bytes : FixedArray[Byte], offset : Int, v : UInt64) -> Bool {
  if offset < 0 || offset + 7 >= bytes.length() {
    return false
  }
  let w0 = (v & (0xffffffff : UInt64)).to_uint()
  let w1 = (v >> 32).to_uint()
  if !write_u32_le(bytes, offset, w0) {
    return false
  }
  if !write_u32_le(bytes, offset + 4, w1) {
    return false
  }
  true
}

///|
pub fn Data::try_as_i8(self : Data) -> Array[Int]? {
  if self.sample_format != SampleFormat::I8 {
    return None
  }
  let out : Array[Int] = []
  for b in self.bytes.op_as_view() {
    let w = b.to_int()
    out.push(if w >= 128 { w - 256 } else { w })
  }
  Some(out)
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
pub fn Data::try_as_u24(self : Data) -> Array[U24]? {
  if self.sample_format != SampleFormat::U24 {
    return None
  }
  if self.bytes.length() % 4 != 0 {
    return None
  }
  let n = self.bytes.length() / 4
  let out : Array[U24] = []
  let mut i = 0
  while i < n {
    let off = i * 4
    match read_u32_le(self.bytes, off) {
      None => return None
      Some(bits) => {
        let raw = (bits & (0x00ff_ffff : UInt)).reinterpret_as_int()
        out.push(U24::new(raw))
      }
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_i24(self : Data) -> Array[I24]? {
  if self.sample_format != SampleFormat::I24 {
    return None
  }
  if self.bytes.length() % 4 != 0 {
    return None
  }
  let n = self.bytes.length() / 4
  let out : Array[I24] = []
  let mut i = 0
  while i < n {
    let off = i * 4
    match read_u32_le(self.bytes, off) {
      None => return None
      Some(bits) => {
        let u = bits & (0x00ff_ffff : UInt)
        let raw =
          if (u & (0x0080_0000 : UInt)) != (0 : UInt) {
            (u | (0xff00_0000 : UInt)).reinterpret_as_int()
          } else {
            u.reinterpret_as_int()
          }
        out.push(I24::new(raw))
      }
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_u32(self : Data) -> Array[UInt]? {
  if self.sample_format != SampleFormat::U32 {
    return None
  }
  if self.bytes.length() % 4 != 0 {
    return None
  }
  let n = self.bytes.length() / 4
  let out : Array[UInt] = []
  let mut i = 0
  while i < n {
    let off = i * 4
    match read_u32_le(self.bytes, off) {
      None => return None
      Some(v) => out.push(v)
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_i32(self : Data) -> Array[Int]? {
  if self.sample_format != SampleFormat::I32 {
    return None
  }
  if self.bytes.length() % 4 != 0 {
    return None
  }
  let n = self.bytes.length() / 4
  let out : Array[Int] = []
  let mut i = 0
  while i < n {
    let off = i * 4
    match read_u32_le(self.bytes, off) {
      None => return None
      Some(bits) => {
        out.push(bits.reinterpret_as_int())
      }
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
pub fn Data::try_as_u64(self : Data) -> Array[UInt64]? {
  if self.sample_format != SampleFormat::U64 {
    return None
  }
  if self.bytes.length() % 8 != 0 {
    return None
  }
  let n = self.bytes.length() / 8
  let out : Array[UInt64] = []
  let mut i = 0
  while i < n {
    let off = i * 8
    match read_u64_le(self.bytes, off) {
      None => return None
      Some(v) => out.push(v)
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_i64(self : Data) -> Array[Int64]? {
  if self.sample_format != SampleFormat::I64 {
    return None
  }
  if self.bytes.length() % 8 != 0 {
    return None
  }
  let n = self.bytes.length() / 8
  let out : Array[Int64] = []
  let mut i = 0
  while i < n {
    let off = i * 8
    match read_u64_le(self.bytes, off) {
      None => return None
      Some(bits) => out.push(bits.reinterpret_as_int64())
    }
    i = i + 1
  }
  Some(out)
}

///|
pub fn Data::try_as_f64(self : Data) -> Array[Double]? {
  if self.sample_format != SampleFormat::F64 {
    return None
  }
  if self.bytes.length() % 8 != 0 {
    return None
  }
  let n = self.bytes.length() / 8
  let out : Array[Double] = []
  let mut i = 0
  while i < n {
    let off = i * 8
    match read_u64_le(self.bytes, off) {
      None => return None
      Some(bits) => out.push(bits.reinterpret_as_double())
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
/// Best-effort encoder for I8 output buffers.
pub fn Data::write_i8(self : Data, samples : Array[Int]) -> Bool {
  if self.sample_format != SampleFormat::I8 {
    return false
  }
  if self.bytes.length() != samples.length() {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    let v = samples[i]
    if v < -128 || v > 127 {
      return false
    }
    let u = if v < 0 { v + 256 } else { v }
    self.bytes[i] = u.to_byte()
    i = i + 1
  }
  true
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
/// Best-effort encoder for U24 (little-endian, stored in the low 24 bits of a 32-bit word).
pub fn Data::write_u24(self : Data, samples : Array[U24]) -> Bool {
  if self.sample_format != SampleFormat::U24 {
    return false
  }
  if self.bytes.length() != samples.length() * 4 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    let raw = samples[i].to_int()
    if raw < 0 || raw > 16_777_215 {
      return false
    }
    if !write_u32_le(self.bytes, i * 4, raw.reinterpret_as_uint()) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for I24 (little-endian, stored in the low 24 bits of a 32-bit word).
pub fn Data::write_i24(self : Data, samples : Array[I24]) -> Bool {
  if self.sample_format != SampleFormat::I24 {
    return false
  }
  if self.bytes.length() != samples.length() * 4 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    let raw = samples[i].to_int()
    if raw < -8_388_608 || raw > 8_388_607 {
      return false
    }
    let u = if raw < 0 { raw + 16_777_216 } else { raw }
    if !write_u32_le(self.bytes, i * 4, u.reinterpret_as_uint()) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for U32 (little-endian).
pub fn Data::write_u32(self : Data, samples : Array[UInt]) -> Bool {
  if self.sample_format != SampleFormat::U32 {
    return false
  }
  if self.bytes.length() != samples.length() * 4 {
    return false
  }
  let max_u32 = (0xffff_ffff : UInt)
  let mut i = 0
  while i < samples.length() {
    let v = samples[i]
    if v > max_u32 {
      return false
    }
    if !write_u32_le(self.bytes, i * 4, v) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for I32 (little-endian).
pub fn Data::write_i32(self : Data, samples : Array[Int]) -> Bool {
  if self.sample_format != SampleFormat::I32 {
    return false
  }
  if self.bytes.length() != samples.length() * 4 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    let v = samples[i]
    if !write_u32_le(self.bytes, i * 4, v.reinterpret_as_uint()) {
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

///|
/// Best-effort encoder for U64 (little-endian).
pub fn Data::write_u64(self : Data, samples : Array[UInt64]) -> Bool {
  if self.sample_format != SampleFormat::U64 {
    return false
  }
  if self.bytes.length() != samples.length() * 8 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    if !write_u64_le(self.bytes, i * 8, samples[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for I64 (little-endian).
pub fn Data::write_i64(self : Data, samples : Array[Int64]) -> Bool {
  if self.sample_format != SampleFormat::I64 {
    return false
  }
  if self.bytes.length() != samples.length() * 8 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    if !write_u64_le(self.bytes, i * 8, samples[i].reinterpret_as_uint64()) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Best-effort encoder for F64 (IEEE-754, little-endian).
pub fn Data::write_f64(self : Data, samples : Array[Double]) -> Bool {
  if self.sample_format != SampleFormat::F64 {
    return false
  }
  if self.bytes.length() != samples.length() * 8 {
    return false
  }
  let mut i = 0
  while i < samples.length() {
    if !write_u64_le(self.bytes, i * 8, samples[i].reinterpret_as_uint64()) {
      return false
    }
    i = i + 1
  }
  true
}
