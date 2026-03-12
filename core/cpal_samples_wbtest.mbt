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
test "i24 clamp + float conversions" {
  inspect(I24::I24(9_000_000).to_int(), content="8388607")
  inspect(I24::I24(-9_000_000).to_int(), content="-8388608")
  let i24_eq : I24 = Sample::equilibrium()
  inspect(i24_eq.to_f32(), content="0")
  inspect(I24::from_f32(1.0).to_int(), content="8388607")
  inspect(I24::from_f32(-1.0).to_int(), content="-8388608")
  let half = I24::from_f32(0.5).to_f32()
  inspect(
    half.is_close(0.5, relative_tolerance=1.0e-6, absolute_tolerance=1.0e-6),
    content="true",
  )
}

///|
test "u24 clamp + float conversions" {
  inspect(U24::U24(-1).to_int(), content="0")
  inspect(U24::U24(99_999_999).to_int(), content="16777215")
  let u24_eq : U24 = Sample::equilibrium()
  inspect(u24_eq.to_int(), content="8388608")
  inspect(u24_eq.to_f32(), content="0")
  inspect(U24::from_f32(-1.0).to_int(), content="0")
  inspect(U24::from_f32(1.0).to_int(), content="16777215")
}

///|
test "sized_sample format mapping" {
  inspect(SizedSample::format((0.0 : Float)), content="F32")
  inspect(SizedSample::format((0.0 : Double)), content="F64")
  inspect(SizedSample::format(Int16::from_int(0)), content="I16")
  inspect(SizedSample::format(Int::to_uint16(0)), content="U16")
  inspect(SizedSample::format(Int::to_byte(0)), content="U8")
  inspect(SizedSample::format(I24::I24(0)), content="I24")
  inspect(SizedSample::format(U24::U24(0)), content="U24")
}

///|
test "from_sample conversion via f32" {
  let zero_u16 : UInt16 = Sample::equilibrium()
  let z : Float = sample_cast(zero_u16)
  inspect(z, content="0")
  let a : Int16 = sample_cast(0.5)
  inspect(a.to_int() > 0, content="true")
  let b : UInt16 = sample_cast(-1.0)
  inspect(b.to_int(), content="0")
}
