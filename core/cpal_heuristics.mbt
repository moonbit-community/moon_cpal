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
fn cmp_bool(a : Bool, b : Bool) -> Int {
  if a == b {
    0
  } else if a {
    1
  } else {
    -1
  }
}

///|
fn cmp_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn cmp_sample_format(a : SampleFormat, b : SampleFormat) -> Int {
  // For the heuristics we only need equality checks against the preferred formats.
  // To keep the implementation simple and portable, we compare by a stable ranking
  // derived from the upstream priority list.
  fn rank(fmt : SampleFormat) -> Int {
    match fmt {
      F32 => 7
      I32 => 6
      U32 => 5
      I24 => 4
      U24 => 3
      I16 => 2
      U16 => 1
      _ => 0
    }
  }

  cmp_int(rank(a), rank(b))
}

///|
/// Compare two supported config ranges using the same "default config" heuristics as upstream.
///
/// Returns:
/// - negative if `self` has lower priority
/// - 0 if equal priority
/// - positive if `self` has higher priority
pub fn SupportedStreamConfigRange::cmp_default_heuristics(
  self : SupportedStreamConfigRange,
  other : SupportedStreamConfigRange,
) -> Int {
  let cmp_stereo = cmp_bool(self.channels == 2, other.channels == 2)
  if cmp_stereo != 0 {
    return cmp_stereo
  }
  let cmp_mono = cmp_bool(self.channels == 1, other.channels == 1)
  if cmp_mono != 0 {
    return cmp_mono
  }
  let cmp_channels = cmp_int(self.channels, other.channels)
  if cmp_channels != 0 {
    return cmp_channels
  }
  let cmp_sf = cmp_sample_format(self.sample_format, other.sample_format)
  if cmp_sf != 0 {
    return cmp_sf
  }
  let hz_44100 = 44100
  let r44100_in_self = self.min_sample_rate <= hz_44100 &&
    hz_44100 <= self.max_sample_rate
  let r44100_in_other = other.min_sample_rate <= hz_44100 &&
    hz_44100 <= other.max_sample_rate
  let cmp_r44100 = cmp_bool(r44100_in_self, r44100_in_other)
  if cmp_r44100 != 0 {
    return cmp_r44100
  }
  cmp_int(self.max_sample_rate, other.max_sample_rate)
}
