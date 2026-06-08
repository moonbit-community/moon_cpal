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
test "alsa errno mapping (unit)" {
  if @core.native_os() != Linux {
    inspect(true, content="true")
    return
  }
  inspect(
    alsa_stream_error_from_errno(-19, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_stream_error_from_errno(-2, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_stream_error_from_errno(-1, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_stream_error_from_errno(-13, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(alsa_stream_error_from_errno(-32, "xrun"), content="BufferUnderrun")
  inspect(
    alsa_stream_error_from_errno(-5, "snd_pcm_writei"),
    content="StreamInvalidated",
  )
  inspect(
    alsa_stream_error_from_errno(-77, "snd_pcm_writei"),
    content="StreamInvalidated",
  )
  inspect(
    alsa_stream_error_from_errno(-86, "snd_pcm_writei"),
    content="StreamInvalidated",
  )
  inspect(
    alsa_build_error_from_errno(-19, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-2, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-1, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-13, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-524, "snd_pcm_open"),
    content="DeviceNotAvailable",
  )
  inspect(
    alsa_build_error_from_errno(-16, "snd_pcm_open"),
    content="DeviceBusy",
  )
  inspect(
    alsa_build_error_from_errno(-11, "snd_pcm_open"),
    content="DeviceBusy",
  )
  inspect(
    alsa_build_error_from_errno(-22, "snd_pcm_hw_params"),
    content="InvalidArgument",
  )
}
