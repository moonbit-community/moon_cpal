///|
pub fn SampleFormat::sample_size(self : SampleFormat) -> Int {
  match self {
    I8 => 1
    U8 => 1
    I16 => 2
    U16 => 2
    I24 => 4
    U24 => 4
    I32 => 4
    U32 => 4
    I64 => 8
    U64 => 8
    F32 => 4
    F64 => 8
    DsdU8 => 1
    DsdU16 => 2
    DsdU32 => 4
  }
}

///|
pub fn SampleFormat::bits_per_sample(self : SampleFormat) -> Int {
  match self {
    I8 => 8
    U8 => 8
    I16 => 16
    U16 => 16
    I24 => 24
    U24 => 24
    I32 => 32
    U32 => 32
    I64 => 64
    U64 => 64
    F32 => 32
    F64 => 64
    DsdU8 => 1
    DsdU16 => 1
    DsdU32 => 1
  }
}

///|
pub fn SampleFormat::is_int(self : SampleFormat) -> Bool {
  match self {
    I8 | I16 | I24 | I32 | I64 => true
    _ => false
  }
}

///|
pub fn SampleFormat::is_uint(self : SampleFormat) -> Bool {
  match self {
    U8 | U16 | U24 | U32 | U64 => true
    _ => false
  }
}

///|
pub fn SampleFormat::is_float(self : SampleFormat) -> Bool {
  match self {
    F32 | F64 => true
    _ => false
  }
}

///|
pub fn SampleFormat::is_dsd(self : SampleFormat) -> Bool {
  match self {
    DsdU8 | DsdU16 | DsdU32 => true
    _ => false
  }
}

///|
pub fn SampleFormat::to_debug_string(self : SampleFormat) -> String {
  match self {
    I8 => "i8"
    I16 => "i16"
    I24 => "i24"
    I32 => "i32"
    I64 => "i64"
    U8 => "u8"
    U16 => "u16"
    U24 => "u24"
    U32 => "u32"
    U64 => "u64"
    F32 => "f32"
    F64 => "f64"
    DsdU8 => "dsdu8"
    DsdU16 => "dsdu16"
    DsdU32 => "dsdu32"
  }
}
