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
test "wasapi sample format tag mapping is explicit (unit)" {
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((1 : UInt32)),
    content="Some(F32)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((2 : UInt32)),
    content="Some(I16)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((3 : UInt32)),
    content="Some(U16)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((4 : UInt32)),
    content="Some(U8)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((6 : UInt32)),
    content="Some(I24)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((7 : UInt32)),
    content="Some(U24)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((8 : UInt32)),
    content="Some(I32)",
  )
  @debug.debug_inspect(
    wasapi_sample_format_from_tag((10 : UInt32)),
    content="Some(I64)",
  )
  inspect(wasapi_sample_format_from_tag((0 : UInt32)) == None, content="true")
  inspect(wasapi_sample_format_from_tag((5 : UInt32)) == None, content="true")
  inspect(wasapi_sample_format_from_tag((11 : UInt32)) == None, content="true")
  inspect(wasapi_sample_format_from_tag((12 : UInt32)) == None, content="true")
}
