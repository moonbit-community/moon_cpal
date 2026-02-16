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
fn assert_full_write_api_exists(data : Data) -> Unit {
  let i8s : Array[Int] = []
  let u8s : Array[Byte] = []
  let u16s : Array[UInt16] = []
  let i16s : Array[Int16] = []
  let u24s : Array[@core.U24] = []
  let i24s : Array[@core.I24] = []
  let u32s : Array[UInt] = []
  let i32s : Array[Int] = []
  let f32s : Array[Float] = []
  let u64s : Array[UInt64] = []
  let i64s : Array[Int64] = []
  let f64s : Array[Double] = []
  ignore(data.write_i8(i8s))
  ignore(data.write_u8(u8s))
  ignore(data.write_u16(u16s))
  ignore(data.write_i16(i16s))
  ignore(data.write_u24(u24s))
  ignore(data.write_i24(i24s))
  ignore(data.write_u32(u32s))
  ignore(data.write_i32(i32s))
  ignore(data.write_f32(f32s))
  ignore(data.write_u64(u64s))
  ignore(data.write_i64(i64s))
  ignore(data.write_f64(f64s))
}

///|
test "spec data write api includes all numeric formats" {
  ignore(assert_full_write_api_exists)
  inspect(true, content="true")
}
