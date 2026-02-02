///|
test "data: try_as_f32 (little-endian) roundtrip" {
  let one : Bytes = (0.5 : Float).to_le_bytes()
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
  let i16_bytes = Bytes::from_array([lo, hi][:])
  let i16_data = Data::new(SampleFormat::I16, i16_bytes)
  inspect(i16_data.try_as_i16(), content="Some([-1])")
  let u16_bytes = Bytes::from_array([Int::to_byte(0x34), Int::to_byte(0x12)][:])
  let u16_data = Data::new(SampleFormat::U16, u16_bytes)
  match u16_data.try_as_u16() {
    None => inspect(false, content="true")
    Some(xs) => inspect(xs[0].to_int(), content="4660")
  }
}

///|
test "data: format mismatch returns None" {
  let bytes = Bytes::from_array([Int::to_byte(0), Int::to_byte(0)][:])
  let data = Data::new(SampleFormat::I16, bytes)
  inspect(data.try_as_f32(), content="None")
}
