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
test "jack callback timestamps + format tags" {
  let want_cb = @core.StreamInstant(1, 2)
  let want_pb = @core.StreamInstant(3, 4)
  let got = FixedArray::make(3, false)
  call_output_data_callback(
    fn(d, info) {
      got[0] = d.sample_format() == @core.SampleFormat::F32
      got[1] = info.timestamp().callback() == want_cb
      got[2] = info.timestamp().playback() == want_pb
    },
    1,
    FixedArray::make(4, Int::to_byte(0)),
    1,
    2,
    3,
    4,
  )
  inspect(got[0], content="true")
  inspect(got[1], content="true")
  inspect(got[2], content="true")
  let want_cb2 = @core.StreamInstant(5, 6)
  let want_cap = @core.StreamInstant(7, 8)
  let got2 = FixedArray::make(3, false)
  call_input_data_callback(
    fn(d, info) {
      got2[0] = d.sample_format() == @core.SampleFormat::F32
      got2[1] = info.timestamp().callback() == want_cb2
      got2[2] = info.timestamp().capture() == want_cap
    },
    1,
    FixedArray::make(4, Int::to_byte(0)),
    5,
    6,
    7,
    8,
  )
  inspect(got2[0], content="true")
  inspect(got2[1], content="true")
  inspect(got2[2], content="true")
}
