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
test "coreaudio OSStatus kind + stream error mapping (unit)" {
  if @core.native_os() != @core.NativeOs::Macos {
    inspect(true, content="true")
    return
  }

  // See `macos/coreaudio_stub.c` for the classification rules and constants.
  inspect(osstatus_kind(-50) == 4, content="true") // kAudio_ParamError
  inspect(osstatus_kind(50) == 4, content="true")
  inspect(osstatus_kind(-66668) == 5, content="true") // kAudioQueueErr_RecordUnderrun
  inspect(osstatus_kind(-66671) == 3, content="true") // kAudioQueueErr_QueueInvalidated
  inspect(osstatus_kind(-66680) == 1, content="true") // kAudioQueueErr_InvalidDevice
  inspect(osstatus_kind(560226676) == 2, content="true") // kAudioDeviceUnsupportedFormatError
  inspect(osstatus_kind(0) == 0, content="true")
  let slot = FixedArray::make(1, @core.stream_error_backend_specific("init"))
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, -66668)
  inspect(slot[0], content="BufferUnderrun")
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, -66671)
  inspect(slot[0], content="StreamInvalidated")
  call_stream_error_callback(fn(e) { slot[0] = e }, 1, -66680)
  inspect(slot[0], content="DeviceNotAvailable")
}
