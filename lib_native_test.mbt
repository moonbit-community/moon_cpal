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
test "root API routes to spec platform dispatch" {
  let h = default_host()
  let id = h.id()
  let all = all_hosts()
  inspect(all.contains(id), content="true")
  let avail = available_hosts()
  if avail.length() > 0 {
    inspect(avail.contains(id), content="true")
  } else {
    // Unsupported target: allow an empty available host set.
    inspect(true, content="true")
  }
}

///|
test "root API exports sample_cast helper" {
  let zero_u16 : UInt16 = Sample::equilibrium()
  let z : Float = sample_cast(zero_u16)
  inspect(z, content="0")
  let a : Int16 = sample_cast(0.5)
  inspect(a.to_int() > 0, content="true")
}

///|
test "root API exports common_sample_rates table" {
  let rs = common_sample_rates()
  inspect(rs.length() > 0, content="true")
  inspect(rs.contains(44_100), content="true")
}
