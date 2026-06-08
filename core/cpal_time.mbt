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
/// A minimal duration type used by the ported `StreamInstant` arithmetic.
///
/// Upstream uses `std::time::Duration` (non-negative). Here we keep the same invariant.
pub struct Duration {
  secs : UInt64
  nanos : Int // 0 <= nanos < 1_000_000_000
} derive(Debug, Eq)

///|
pub fn Duration::from_secs(secs : UInt64) -> Duration {
  Duration(secs, 0)
}

///|
pub fn Duration::Duration(secs : UInt64, nanos : Int) -> Duration {
  if nanos < 0 {
    panic()
  }
  let mut secs = secs
  let mut nanos = nanos
  let billion = 1_000_000_000
  if nanos >= billion {
    let carry = nanos / billion
    let carry_u64 = carry.to_uint64()
    let new_secs = secs + carry_u64
    if new_secs < secs {
      panic()
    }
    secs = new_secs
    nanos = nanos - carry * billion
  }
  { secs, nanos }
}

///|
pub fn Duration::new(secs : UInt64, nanos : Int) -> Duration {
  Duration(secs, nanos)
}

///|
fn Duration::as_nanos_bigint(self : Duration) -> @bigint.BigInt {
  let bsecs = @bigint.BigInt::from_uint64(self.secs)
  let bnanos = @bigint.BigInt::from_int(self.nanos)
  let b1e9 = @bigint.BigInt::from_int(1_000_000_000)
  @bigint.BigInt::add(@bigint.BigInt::mul(bsecs, b1e9), bnanos)
}

///|
/// Monotonic timestamp associated with a stream.
pub struct StreamInstant {
  secs : Int64
  nanos : Int // normalized to 0 <= nanos < 1_000_000_000
} derive(Debug, Eq)

///|
pub fn StreamInstant::StreamInstant(secs : Int64, nanos : Int) -> StreamInstant {
  // Keep the representation normalized; this matches common upstream usage and keeps arithmetic sane.
  let mut secs = secs
  let mut nanos = nanos
  let billion = 1_000_000_000
  if nanos >= billion {
    let carry = nanos / billion
    secs = secs + carry.to_int64()
    nanos = nanos - carry * billion
  } else if nanos < 0 {
    let borrow = (-nanos + (billion - 1)) / billion
    secs = secs - borrow.to_int64()
    nanos = nanos + borrow * billion
  }
  { secs, nanos }
}

///|
pub fn StreamInstant::new(secs : Int64, nanos : Int) -> StreamInstant {
  StreamInstant(secs, nanos)
}

///|
fn StreamInstant::as_nanos_bigint(self : StreamInstant) -> @bigint.BigInt {
  let bsecs = @bigint.BigInt::from_int64(self.secs)
  let bnanos = @bigint.BigInt::from_int(self.nanos)
  let b1e9 = @bigint.BigInt::from_int(1_000_000_000)
  @bigint.BigInt::add(@bigint.BigInt::mul(bsecs, b1e9), bnanos)
}

///|
/// The amount of time elapsed from another instant to this one.
///
/// Returns `None` if `earlier` is later than `self`.
pub fn StreamInstant::duration_since(
  self : StreamInstant,
  earlier : StreamInstant,
) -> Duration? {
  if self.secs < earlier.secs ||
    (self.secs == earlier.secs && self.nanos < earlier.nanos) {
    return None
  }
  let diff = @bigint.BigInt::sub(
    self.as_nanos_bigint(),
    earlier.as_nanos_bigint(),
  )
  // diff is guaranteed non-negative due to the comparison above.

  let b1e9 = @bigint.BigInt::from_int(1_000_000_000)
  let secs_b = @bigint.BigInt::div(diff, b1e9)
  let nanos_b = @bigint.BigInt::sub(diff, @bigint.BigInt::mul(secs_b, b1e9))

  // Guard against overflowing Duration's `UInt64` seconds.
  let max_u64 = @bigint.BigInt::from_string("18446744073709551615")
  if @bigint.BigInt::compare(secs_b, max_u64) > 0 {
    return None
  }
  let secs_u64 = @bigint.BigInt::to_uint64(secs_b)
  let nanos_i = @bigint.BigInt::to_int(nanos_b)
  Some({ secs: secs_u64, nanos: nanos_i })
}

///|
fn StreamInstant::from_nanos_bigint(total : @bigint.BigInt) -> StreamInstant? {
  let b1e9 = @bigint.BigInt::from_int(1_000_000_000)
  let mut secs = @bigint.BigInt::div(total, b1e9)
  let mut rem = @bigint.BigInt::sub(total, @bigint.BigInt::mul(secs, b1e9))

  // Adjust to keep remainder non-negative (Euclidean division normalization).
  if @bigint.BigInt::op_lt(rem, @bigint.BigInt::from_int(0)) {
    secs = @bigint.BigInt::sub(secs, @bigint.BigInt::from_int(1))
    rem = @bigint.BigInt::add(rem, b1e9)
  }
  let max_i64 = 9223372036854775807L
  let min_i64 = -9223372036854775808L
  if @bigint.BigInt::compare_int64(secs, max_i64) > 0 {
    return None
  }
  if @bigint.BigInt::compare_int64(secs, min_i64) < 0 {
    return None
  }
  let secs_i64 = @bigint.BigInt::to_int64(secs)
  let nanos_i = @bigint.BigInt::to_int(rem)
  Some(StreamInstant(secs_i64, nanos_i))
}

///|
/// Return the instant after the given duration has passed.
pub fn StreamInstant::add(
  self : StreamInstant,
  duration : Duration,
) -> StreamInstant? {
  let a = self.as_nanos_bigint()
  let b = duration.as_nanos_bigint()
  StreamInstant::from_nanos_bigint(@bigint.BigInt::add(a, b))
}

///|
/// Return the instant one duration ago.
pub fn StreamInstant::sub(
  self : StreamInstant,
  duration : Duration,
) -> StreamInstant? {
  let a = self.as_nanos_bigint()
  let b = duration.as_nanos_bigint()
  StreamInstant::from_nanos_bigint(@bigint.BigInt::sub(a, b))
}
