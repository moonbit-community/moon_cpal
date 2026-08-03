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
/// Small UTF-8 decoding helpers used by native backends.
///
/// MoonBit `String` is UTF-16. Some backends expose UTF-8 byte strings via C FFI,
/// and decode them here for portability across toolchains.

///|
pub fn utf8_bytes_to_string(bytes : Bytes, length : Int) -> String {
  let res = StringBuilder::new()
  let len = if length < bytes.length() { length } else { bytes.length() }
  let mut i = 0
  while i < len {
    let mut c = bytes[i].to_int()
    if c < 0x80 {
      res.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 0xE0 {
      if i + 1 >= len {
        break
      }
      c = ((c & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      res.write_char(c.unsafe_to_char())
      i += 2
    } else if c < 0xF0 {
      if i + 2 >= len {
        break
      }
      c = ((c & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      res.write_char(c.unsafe_to_char())
      i += 3
    } else {
      if i + 3 >= len {
        break
      }
      c = ((c & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      c -= 0x10000
      res.write_char(((c >> 10) + 0xD800).unsafe_to_char())
      res.write_char(((c & 0x3FF) + 0xDC00).unsafe_to_char())
      i += 4
    }
  }
  res.to_string()
}

///|
/// Encode a string into ASCII bytes (best-effort).
///
/// This is intended for native backend identifiers like `default` or `hw:0,0`.
/// Any non-ASCII chars are replaced with `?`.
pub fn string_to_ascii_bytes(s : String) -> Bytes {
  Bytes::makei(s.length(), fn(i) {
    // For ASCII-only identifiers, code units equal chars.
    let cu = s.code_unit_at(i).to_int()
    if 0 <= cu && cu < 128 {
      cu.to_byte()
    } else {
      (63 : Int).to_byte()
    }
  })
}

///|
/// Encode a string into UTF-8 bytes.
///
/// This is needed for native backends that require UTF-8 identifiers (e.g. WASAPI endpoint IDs).
pub fn string_to_utf8_bytes(s : String) -> Bytes {
  // Pass 1: compute output length.
  let mut n = 0
  for c in s {
    let code = c.to_uint()
    if code < 0x80 {
      n += 1
    } else if code < 0x0800 {
      n += 2
    } else if code < 0x010000 {
      n += 3
    } else {
      n += 4
    }
  }
  if n <= 0 {
    return Default::default()
  }

  // Pass 2: write bytes.
  let buf = FixedArray::make(n, (0 : Int).to_byte())
  let mut off = 0
  for c in s {
    off = off + buf.set_utf8_char(off, c)
  }
  FixedArray::unsafe_reinterpret_as_bytes(buf)
}
