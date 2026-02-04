///|
test "data: try_as_f32 (little-endian) roundtrip" {
  let one_b : Bytes = (0.5 : Float).to_le_bytes()
  let one : FixedArray[Byte] = one_b.to_fixedarray()
  let data = Data::new(SampleFormat::F32, one + one)
  match data.try_as_f32() {
    None => inspect(false, content="true")
    Some(xs) => {
      inspect(xs.length(), content="2")
      inspect(xs[0].is_close(0.5), content="true")
      inspect(xs[1].is_close(0.5), content="true")
    }
  }
}

///|
test "data: try_as_i16 and try_as_u16" {
  let bits = Int16::from_int(-1).reinterpret_as_uint16()
  let lo = bits.to_byte()
  let hi = (bits >> 8).to_byte()
  let i16_bytes = FixedArray::from_array([lo, hi][:])
  let i16_data = Data::new(SampleFormat::I16, i16_bytes)
  inspect(i16_data.try_as_i16(), content="Some([-1])")
  let u16_bytes = FixedArray::from_array(
    [Int::to_byte(0x34), Int::to_byte(0x12)][:],
  )
  let u16_data = Data::new(SampleFormat::U16, u16_bytes)
  match u16_data.try_as_u16() {
    None => inspect(false, content="true")
    Some(xs) => inspect(xs[0].to_int(), content="4660")
  }
}

///|
test "data: format mismatch returns None" {
  let bytes = FixedArray::from_array([Int::to_byte(0), Int::to_byte(0)][:])
  let data = Data::new(SampleFormat::I16, bytes)
  inspect(data.try_as_f32(), content="None")
}

///|
test "data: clear zeros bytes" {
  let bytes = FixedArray::from_array(
    [Int::to_byte(1), Int::to_byte(2), Int::to_byte(3), Int::to_byte(4)][:],
  )
  let data = Data::new(SampleFormat::U8, bytes)
  data.clear()
  inspect(
    data.bytes().op_as_view().to_array(),
    content="[b'\\x00', b'\\x00', b'\\x00', b'\\x00']",
  )
}

///|
test "data: write_f32 roundtrip" {
  let data = Data::new(SampleFormat::F32, FixedArray::make(8, Int::to_byte(0)))
  inspect(data.write_f32([(0.5 : Float), (-1.0 : Float)]), content="true")
  match data.try_as_f32() {
    None => inspect(false, content="true")
    Some(xs) => {
      inspect(xs.length(), content="2")
      inspect(xs[0].is_close(0.5), content="true")
      inspect(xs[1].is_close(-1.0), content="true")
    }
  }
}

///|
test "data: write_i16/write_u16/write_u8 roundtrip" {
  let i16 = Data::new(SampleFormat::I16, FixedArray::make(4, Int::to_byte(0)))
  inspect(
    i16.write_i16([Int16::from_int(-1), Int16::from_int(123)]),
    content="true",
  )
  inspect(i16.try_as_i16(), content="Some([-1, 123])")
  let u16 = Data::new(SampleFormat::U16, FixedArray::make(4, Int::to_byte(0)))
  inspect(
    u16.write_u16([(0x1234 : Int).to_uint16(), (0xabcd : Int).to_uint16()]),
    content="true",
  )
  match u16.try_as_u16() {
    None => inspect(false, content="true")
    Some(xs) =>
      inspect([xs[0].to_int(), xs[1].to_int()], content="[4660, 43981]")
  }
  let u8 = Data::new(SampleFormat::U8, FixedArray::make(4, Int::to_byte(0)))
  inspect(
    u8.write_u8([
      Int::to_byte(5),
      Int::to_byte(6),
      Int::to_byte(7),
      Int::to_byte(8),
    ]),
    content="true",
  )
  inspect(
    u8.try_as_u8(),
    content="Some([b'\\x05', b'\\x06', b'\\x07', b'\\x08'])",
  )
}
