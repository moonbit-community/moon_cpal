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
/// Sample traits and 24-bit integer sample newtypes (subset).
///
/// Upstream `cpal` re-exports these from `dasp_sample` via `cpal/src/samples_formats.rs`.
/// For MoonBit, we implement a small, deterministic subset that is sufficient for:
/// - expressing sample format at the type level (`SizedSample`)
/// - filling silence (`Sample::equilibrium`)
/// - basic normalized conversions (`to_f32` / `from_f32`)

///|
pub struct I24 {
  raw : Int
  fn new(raw : Int) -> I24
} derive(Show, Eq)

///|
pub struct U24 {
  raw : Int
  fn new(raw : Int) -> U24
} derive(Show, Eq)

///|
let i24_min : Int = -8_388_608

///|
let i24_max : Int = 8_388_607

///|
let u24_min : Int = 0

///|
let u24_max : Int = 16_777_215

///|
let u24_mid : Int = 8_388_608

///|
pub fn I24::new(raw : Int) -> I24 {
  { raw: Int::clamp(raw, min=i24_min, max=i24_max) }
}

///|
pub fn I24::to_int(self : I24) -> Int {
  self.raw
}

///|
pub fn U24::new(raw : Int) -> U24 {
  { raw: Int::clamp(raw, min=u24_min, max=u24_max) }
}

///|
pub fn U24::to_int(self : U24) -> Int {
  self.raw
}

///|
pub trait Sample {
  /// A "silent" sample value.
  equilibrium() -> Self

  /// Convert to the normalized `[-1.0, 1.0]` range.
  to_f32(Self) -> Float

  /// Convert from the normalized `[-1.0, 1.0]` range (clamped and quantized).
  from_f32(Float) -> Self
}

///|
pub trait SizedSample: Sample {
  /// The corresponding `SampleFormat` for this sample type.
  format(Self) -> SampleFormat
}

///|
pub trait FromSample: Sample {
  /// Convert from a normalized `[-1.0, 1.0]` float sample.
  ///
  /// Note: Upstream `cpal` uses `dasp_sample::FromSample`, which is a generic conversion
  /// trait between arbitrary sample types. MoonBit does not currently support polymorphic
  /// trait methods, so we provide:
  /// - `FromSample::from_sample(Float)` for constructing a sample type from normalized float
  /// - `sample_cast` for generic conversion between `Sample` types via `Float`
  from_sample(Float) -> Self
}

///|
fn clamp_unit(x : Float) -> Float {
  if x < -1.0 {
    -1.0
  } else if x > 1.0 {
    1.0
  } else {
    x
  }
}

///|
fn round_to_int(x : Float) -> Int {
  x.round().to_int()
}

///|
pub fn[A : Sample, B : Sample] sample_cast(x : A) -> B {
  Sample::from_f32(x.to_f32())
}

///|
pub impl Sample for Float with equilibrium() {
  0.0
}

///|
pub impl Sample for Float with to_f32(self : Float) -> Float {
  self
}

///|
pub impl Sample for Float with from_f32(x : Float) -> Float {
  clamp_unit(x)
}

///|
pub impl SizedSample for Float with format(_self : Float) -> SampleFormat {
  SampleFormat::F32
}

///|
pub impl FromSample for Float with from_sample(x : Float) -> Float {
  Sample::from_f32(x)
}

///|
pub impl Sample for Double with equilibrium() {
  0.0
}

///|
pub impl Sample for Double with to_f32(self : Double) -> Float {
  Float::from_double(self)
}

///|
pub impl Sample for Double with from_f32(x : Float) -> Double {
  clamp_unit(x).to_double()
}

///|
pub impl SizedSample for Double with format(_self : Double) -> SampleFormat {
  SampleFormat::F64
}

///|
pub impl FromSample for Double with from_sample(x : Float) -> Double {
  Sample::from_f32(x)
}

///|
pub impl Sample for Int16 with equilibrium() {
  Int16::from_int(0)
}

///|
pub impl Sample for Int16 with to_f32(self : Int16) -> Float {
  Float::from_int(self.to_int()) / Float::from_int(32_768)
}

///|
pub impl Sample for Int16 with from_f32(x : Float) -> Int16 {
  let x = clamp_unit(x)
  let scaled = round_to_int(x * Float::from_int(32_768))
  let clamped = Int::clamp(scaled, min=-32_768, max=32_767)
  Int16::from_int(clamped)
}

///|
pub impl SizedSample for Int16 with format(_self : Int16) -> SampleFormat {
  SampleFormat::I16
}

///|
pub impl FromSample for Int16 with from_sample(x : Float) -> Int16 {
  Sample::from_f32(x)
}

///|
pub impl Sample for UInt16 with equilibrium() {
  (32_768).to_uint16()
}

///|
pub impl Sample for UInt16 with to_f32(self : UInt16) -> Float {
  let v = self.to_int() - 32_768
  Float::from_int(v) / Float::from_int(32_768)
}

///|
pub impl Sample for UInt16 with from_f32(x : Float) -> UInt16 {
  let x = clamp_unit(x)
  let scaled = round_to_int(x * Float::from_int(32_768)) + 32_768
  let clamped = Int::clamp(scaled, min=0, max=65_535)
  clamped.to_uint16()
}

///|
pub impl SizedSample for UInt16 with format(_self : UInt16) -> SampleFormat {
  SampleFormat::U16
}

///|
pub impl FromSample for UInt16 with from_sample(x : Float) -> UInt16 {
  Sample::from_f32(x)
}

///|
pub impl Sample for Byte with equilibrium() {
  (128).to_byte()
}

///|
pub impl Sample for Byte with to_f32(self : Byte) -> Float {
  let v = self.to_int() - 128
  Float::from_int(v) / Float::from_int(128)
}

///|
pub impl Sample for Byte with from_f32(x : Float) -> Byte {
  let x = clamp_unit(x)
  let scaled = round_to_int(x * Float::from_int(128)) + 128
  let clamped = Int::clamp(scaled, min=0, max=255)
  clamped.to_byte()
}

///|
pub impl SizedSample for Byte with format(_self : Byte) -> SampleFormat {
  SampleFormat::U8
}

///|
pub impl FromSample for Byte with from_sample(x : Float) -> Byte {
  Sample::from_f32(x)
}

///|
pub impl Sample for I24 with equilibrium() {
  I24(0)
}

///|
pub impl Sample for I24 with to_f32(self : I24) -> Float {
  Float::from_int(self.raw) / Float::from_int(8_388_608)
}

///|
pub impl Sample for I24 with from_f32(x : Float) -> I24 {
  let x = clamp_unit(x)
  let scaled = round_to_int(x * Float::from_int(8_388_608))
  I24(scaled)
}

///|
pub impl SizedSample for I24 with format(_self : I24) -> SampleFormat {
  SampleFormat::I24
}

///|
pub impl FromSample for I24 with from_sample(x : Float) -> I24 {
  Sample::from_f32(x)
}

///|
pub impl Sample for U24 with equilibrium() {
  U24(u24_mid)
}

///|
pub impl Sample for U24 with to_f32(self : U24) -> Float {
  Float::from_int(self.raw - u24_mid) / Float::from_int(u24_mid)
}

///|
pub impl Sample for U24 with from_f32(x : Float) -> U24 {
  let x = clamp_unit(x)
  let scaled = round_to_int(x * Float::from_int(u24_mid)) + u24_mid
  U24(scaled)
}

///|
pub impl SizedSample for U24 with format(_self : U24) -> SampleFormat {
  SampleFormat::U24
}

///|
pub impl FromSample for U24 with from_sample(x : Float) -> U24 {
  Sample::from_f32(x)
}
