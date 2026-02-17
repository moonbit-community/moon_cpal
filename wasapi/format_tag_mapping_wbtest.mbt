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
  inspect(wasapi_sample_format_from_tag((1 : UInt)), content="Some(F32)")
  inspect(wasapi_sample_format_from_tag((2 : UInt)), content="Some(I16)")
  inspect(wasapi_sample_format_from_tag((3 : UInt)), content="Some(U16)")
  inspect(wasapi_sample_format_from_tag((4 : UInt)), content="Some(U8)")
  inspect(wasapi_sample_format_from_tag((6 : UInt)), content="Some(I24)")
  inspect(wasapi_sample_format_from_tag((7 : UInt)), content="Some(U24)")
  inspect(wasapi_sample_format_from_tag((8 : UInt)), content="Some(I32)")
  inspect(wasapi_sample_format_from_tag((10 : UInt)), content="Some(I64)")
  inspect(wasapi_sample_format_from_tag((0 : UInt)) == None, content="true")
  inspect(wasapi_sample_format_from_tag((5 : UInt)) == None, content="true")
  inspect(wasapi_sample_format_from_tag((11 : UInt)) == None, content="true")
  inspect(wasapi_sample_format_from_tag((12 : UInt)) == None, content="true")
}
