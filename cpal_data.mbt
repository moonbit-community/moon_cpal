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
  bytes : Bytes
} derive(Show, Eq)

///|
pub fn Data::new(sample_format : SampleFormat, bytes : Bytes) -> Data {
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
pub fn Data::bytes(self : Data) -> Bytes {
  self.bytes
}

///|
fn read_u16_le(bytes : Bytes, offset : Int) -> UInt16? {
  match (bytes.get(offset), bytes.get(offset + 1)) {
    (Some(b0), Some(b1)) => {
      let v = b0.to_int() | (b1.to_int() << 8)
      Some(v.to_uint16())
    }
    _ => None
  }
}

///|
fn read_u32_le(bytes : Bytes, offset : Int) -> UInt? {
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
pub fn Data::try_as_u8(self : Data) -> Array[Byte]? {
  if self.sample_format != SampleFormat::U8 {
    return None
  }
  Some(self.bytes.to_array())
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
