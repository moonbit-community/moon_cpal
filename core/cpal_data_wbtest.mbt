// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
test "data: try_as_f32 (little-endian) roundtrip" {
  let one_b : Bytes = (0.5 : Float).to_le_bytes()
  let one : FixedArray[Byte] = one_b.to_fixedarray()
  let data = Data(SampleFormat::F32, one + one)
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
  let i16_data = Data(SampleFormat::I16, i16_bytes)
  inspect(i16_data.try_as_i16(), content="Some([-1])")
  let u16_bytes = FixedArray::from_array(
    [Int::to_byte(0x34), Int::to_byte(0x12)][:],
  )
  let u16_data = Data(SampleFormat::U16, u16_bytes)
  match u16_data.try_as_u16() {
    None => inspect(false, content="true")
    Some(xs) => inspect(xs[0].to_int(), content="4660")
  }
}

///|
test "data: format mismatch returns None" {
  let bytes = FixedArray::from_array([Int::to_byte(0), Int::to_byte(0)][:])
  let data = Data(SampleFormat::I16, bytes)
  inspect(data.try_as_f32(), content="None")
}

///|
test "data: clear uses equilibrium bytes" {
  let bytes = FixedArray::from_array(
    [Int::to_byte(1), Int::to_byte(2), Int::to_byte(3), Int::to_byte(4)][:],
  )
  let data = Data(SampleFormat::U8, bytes)
  data.clear()
  inspect(
    data.bytes().op_as_view().to_array(),
    content="[b'\\x80', b'\\x80', b'\\x80', b'\\x80']",
  )
  let u16_bytes = FixedArray::from_array(
    [Int::to_byte(1), Int::to_byte(2), Int::to_byte(3), Int::to_byte(4)][:],
  )
  let u16 = Data(SampleFormat::U16, u16_bytes)
  u16.clear()
  inspect(
    u16.bytes().op_as_view().to_array(),
    content="[b'\\x00', b'\\x80', b'\\x00', b'\\x80']",
  )
}

///|
test "data: write_f32 roundtrip" {
  let data = Data(SampleFormat::F32, FixedArray::make(8, Int::to_byte(0)))
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
  let i16 = Data(SampleFormat::I16, FixedArray::make(4, Int::to_byte(0)))
  inspect(
    i16.write_i16([Int16::from_int(-1), Int16::from_int(123)]),
    content="true",
  )
  inspect(i16.try_as_i16(), content="Some([-1, 123])")
  let u16 = Data(SampleFormat::U16, FixedArray::make(4, Int::to_byte(0)))
  inspect(
    u16.write_u16([(0x1234 : Int).to_uint16(), (0xabcd : Int).to_uint16()]),
    content="true",
  )
  match u16.try_as_u16() {
    None => inspect(false, content="true")
    Some(xs) =>
      inspect([xs[0].to_int(), xs[1].to_int()], content="[4660, 43981]")
  }
  let u8 = Data(SampleFormat::U8, FixedArray::make(4, Int::to_byte(0)))
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

///|
test "data: i8/i24/u24/i32/u32/i64/u64/f64 roundtrip (best-effort)" {
  let i8 = Data(SampleFormat::I8, FixedArray::make(3, Int::to_byte(0)))
  inspect(i8.write_i8([-128, 0, 127]), content="true")
  inspect(i8.try_as_i8(), content="Some([-128, 0, 127])")
  let i24 = Data(SampleFormat::I24, FixedArray::make(8, Int::to_byte(0)))
  inspect(i24.write_i24([I24::new(-1), I24::new(8_388_607)]), content="true")
  match i24.try_as_i24() {
    None => inspect(false, content="true")
    Some(xs) =>
      inspect([xs[0].to_int(), xs[1].to_int()], content="[-1, 8388607]")
  }
  let u24 = Data(SampleFormat::U24, FixedArray::make(8, Int::to_byte(0)))
  inspect(u24.write_u24([U24::new(0), U24::new(16_777_215)]), content="true")
  match u24.try_as_u24() {
    None => inspect(false, content="true")
    Some(xs) =>
      inspect([xs[0].to_int(), xs[1].to_int()], content="[0, 16777215]")
  }
  let i32 = Data(SampleFormat::I32, FixedArray::make(8, Int::to_byte(0)))
  inspect(i32.write_i32([-2_147_483_648, 2_147_483_647]), content="true")
  inspect(i32.try_as_i32(), content="Some([-2147483648, 2147483647])")
  let u32 = Data(SampleFormat::U32, FixedArray::make(8, Int::to_byte(0)))
  inspect(u32.write_u32([(0 : UInt), (0xffff_ffff : UInt)]), content="true")
  match u32.try_as_u32() {
    None => inspect(false, content="true")
    Some(xs) => {
      inspect(xs.length(), content="2")
      inspect(xs[0] == (0 : UInt), content="true")
      inspect(xs[1] == (0xffff_ffff : UInt), content="true")
    }
  }
  let i64 = Data(SampleFormat::I64, FixedArray::make(16, Int::to_byte(0)))
  inspect(
    i64.write_i64([(-1 : Int).to_int64(), (123456789 : Int).to_int64()]),
    content="true",
  )
  inspect(i64.try_as_i64(), content="Some([-1, 123456789])")
  let u64 = Data(SampleFormat::U64, FixedArray::make(16, Int::to_byte(0)))
  inspect(
    u64.write_u64([(0 : UInt64), (0xffff_ffff_ffff_ffff : UInt64)]),
    content="true",
  )
  match u64.try_as_u64() {
    None => inspect(false, content="true")
    Some(xs) => {
      inspect(xs.length(), content="2")
      inspect(xs[0] == (0 : UInt64), content="true")
      inspect(xs[1] == (0xffff_ffff_ffff_ffff : UInt64), content="true")
    }
  }
  let f64 = Data(SampleFormat::F64, FixedArray::make(16, Int::to_byte(0)))
  inspect(f64.write_f64([(0.5 : Double), (-1.0 : Double)]), content="true")
  match f64.try_as_f64() {
    None => inspect(false, content="true")
    Some(xs) => {
      inspect(xs.length(), content="2")
      inspect(Float::from_double(xs[0]).is_close(0.5), content="true")
      inspect(Float::from_double(xs[1]).is_close(-1.0), content="true")
    }
  }
}
