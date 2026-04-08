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
/// Core CPAL-like types that are deterministic and portable.
///
/// This is an incremental MoonBit port of RustAudio/cpal. The current slice focuses on the
/// "pure core" types used by upstream unit tests.

///|
pub type ChannelCount = Int

///|
pub type SampleRate = Int

///|
pub type FrameCount = Int

///|
/// The buffer size requests the callback size for audio streams.
///
/// Mirrors upstream `cpal::BufferSize`:
/// - `Default` uses the host's default callback size.
/// - `Fixed(n)` requests approximately `n` frames per callback.
///
/// The actual callback size depends on the backend/host implementation and may differ from or
/// vary around the requested size.
pub enum BufferSize {
  Default
  Fixed(FrameCount)
} derive(Debug, Eq)

///|
pub fn BufferSize::default() -> BufferSize {
  Default
}

///|
pub fn BufferSize::fixed(n : FrameCount) -> BufferSize {
  Fixed(n)
}

///|
pub struct StreamConfig {
  channels : ChannelCount
  sample_rate : SampleRate
  buffer_size : BufferSize

  fn new(
    channels : ChannelCount,
    sample_rate : SampleRate,
    buffer_size : BufferSize,
  ) -> StreamConfig
} derive(Debug, Eq)

///|
pub fn StreamConfig::new(
  channels : ChannelCount,
  sample_rate : SampleRate,
  buffer_size : BufferSize,
) -> StreamConfig {
  { channels, sample_rate, buffer_size }
}

///|
pub(all) enum SupportedBufferSize {
  Range(min~ : FrameCount, max~ : FrameCount)
  Unknown
} derive(Debug, Eq)

///|
pub fn SupportedBufferSize::contains(
  self : SupportedBufferSize,
  frames : FrameCount,
) -> Bool {
  if frames <= 0 {
    return false
  }
  match self {
    Unknown => true
    Range(min=mn, max=mx) => mn <= frames && frames <= mx
  }
}

///|
pub(all) enum SampleFormat {
  I8
  I16
  I24
  I32
  I64
  U8
  U16
  U24
  U32
  U64
  F32
  F64
  DsdU8
  DsdU16
  DsdU32
} derive(Debug, Eq)

///|
/// A single supported stream configuration (as opposed to a range).
///
/// Mirrors cpal's `SupportedStreamConfig` shape used by `default_*_config`.
pub struct SupportedStreamConfig {
  buffer_size : SupportedBufferSize
  channels : ChannelCount
  sample_rate : SampleRate
  sample_format : SampleFormat

  fn new(
    channels : ChannelCount,
    sample_rate : SampleRate,
    buffer_size : SupportedBufferSize,
    sample_format : SampleFormat,
  ) -> SupportedStreamConfig
} derive(Debug, Eq)

///|
pub fn SupportedStreamConfig::new(
  channels : ChannelCount,
  sample_rate : SampleRate,
  buffer_size : SupportedBufferSize,
  sample_format : SampleFormat,
) -> SupportedStreamConfig {
  { channels, sample_rate, buffer_size, sample_format }
}

///|
pub fn SupportedStreamConfig::channels(
  self : SupportedStreamConfig,
) -> ChannelCount {
  self.channels
}

///|
pub fn SupportedStreamConfig::sample_rate(
  self : SupportedStreamConfig,
) -> SampleRate {
  self.sample_rate
}

///|
pub fn SupportedStreamConfig::sample_format(
  self : SupportedStreamConfig,
) -> SampleFormat {
  self.sample_format
}

///|
pub fn SupportedStreamConfig::buffer_size(
  self : SupportedStreamConfig,
) -> SupportedBufferSize {
  self.buffer_size
}

///|
pub fn SupportedStreamConfig::config(
  self : SupportedStreamConfig,
) -> StreamConfig {
  // Upstream cpal discards the "supported buffer size" range when producing
  // a buildable `StreamConfig`.
  {
    channels: self.channels,
    sample_rate: self.sample_rate,
    buffer_size: BufferSize::Default,
  }
}

///|
pub struct SupportedStreamConfigRange {
  buffer_size : SupportedBufferSize
  channels : ChannelCount
  min_sample_rate : SampleRate
  max_sample_rate : SampleRate
  sample_format : SampleFormat

  fn new(
    channels : ChannelCount,
    min_sample_rate : SampleRate,
    max_sample_rate : SampleRate,
    buffer_size : SupportedBufferSize,
    sample_format : SampleFormat,
  ) -> SupportedStreamConfigRange
} derive(Debug, Eq)

///|
/// Public constructor for black-box tests and downstream users.
pub fn SupportedStreamConfigRange::new(
  channels : ChannelCount,
  min_sample_rate : SampleRate,
  max_sample_rate : SampleRate,
  buffer_size : SupportedBufferSize,
  sample_format : SampleFormat,
) -> SupportedStreamConfigRange {
  { channels, min_sample_rate, max_sample_rate, buffer_size, sample_format }
}

///|
pub fn SupportedStreamConfigRange::channels(
  self : SupportedStreamConfigRange,
) -> ChannelCount {
  self.channels
}

///|
pub fn SupportedStreamConfigRange::min_sample_rate(
  self : SupportedStreamConfigRange,
) -> SampleRate {
  self.min_sample_rate
}

///|
pub fn SupportedStreamConfigRange::max_sample_rate(
  self : SupportedStreamConfigRange,
) -> SampleRate {
  self.max_sample_rate
}

///|
pub fn SupportedStreamConfigRange::sample_format(
  self : SupportedStreamConfigRange,
) -> SampleFormat {
  self.sample_format
}

///|
pub fn SupportedStreamConfigRange::buffer_size(
  self : SupportedStreamConfigRange,
) -> SupportedBufferSize {
  self.buffer_size
}

///|
/// Retrieve a `SupportedStreamConfig` with the given sample rate.
///
/// # Panics
///
/// Panics if `sample_rate` is outside `[min_sample_rate, max_sample_rate]`.
pub fn SupportedStreamConfigRange::with_sample_rate(
  self : SupportedStreamConfigRange,
  sample_rate : SampleRate,
) -> SupportedStreamConfig {
  match self.try_with_sample_rate(sample_rate) {
    Some(cfg) => cfg
    None => panic()
  }
}

///|
/// Retrieve a `SupportedStreamConfig` with the given sample rate.
///
/// Returns `None` if `sample_rate` is outside `[min_sample_rate, max_sample_rate]`.
pub fn SupportedStreamConfigRange::try_with_sample_rate(
  self : SupportedStreamConfigRange,
  sample_rate : SampleRate,
) -> SupportedStreamConfig? {
  if self.min_sample_rate <= sample_rate && sample_rate <= self.max_sample_rate {
    Some(
      SupportedStreamConfig(
        self.channels,
        sample_rate,
        self.buffer_size,
        self.sample_format,
      ),
    )
  } else {
    None
  }
}

///|
/// Turns this range into a `SupportedStreamConfig` corresponding to the maximum sample rate.
pub fn SupportedStreamConfigRange::with_max_sample_rate(
  self : SupportedStreamConfigRange,
) -> SupportedStreamConfig {
  SupportedStreamConfig(
    self.channels,
    self.max_sample_rate,
    self.buffer_size,
    self.sample_format,
  )
}

///|
pub fn common_sample_rates() -> Array[SampleRate] {
  [
    5512, 8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000, 64000, 88200,
    96000, 176400, 192000, 352800, 384000, 705600, 768000, 1411200, 1536000,
  ]
}
