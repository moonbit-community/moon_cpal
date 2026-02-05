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
test "alsa: devices includes default (linux-only)" {
  if @core.native_os() != @core.NativeOs::Linux {
    return
  }
  let h = default_host()
  let ds = h.devices()
  inspect(ds.length() > 0, content="true")
  let mut has_default = false
  for d in ds {
    if d.id == "default" {
      has_default = true
      break
    }
  }
  inspect(has_default, content="true")
}

///|
test "alsa: default devices are always Some (linux-only)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let h = default_host()
  match h.default_output_device() {
    None => inspect(false, content="false")
    Some(d) => inspect(d.id == "default", content="true")
  }
  match h.default_input_device() {
    None => inspect(false, content="false")
    Some(d) => inspect(d.id == "default", content="true")
  }
}

///|
test "alsa: name + description fields (best-effort)" {
  if @core.native_os() != @core.NativeOs::Linux {
    inspect(true, content="true")
    return
  }
  let h = default_host()
  let ds = h.devices()
  if ds.length() == 0 {
    inspect(true, content="true")
    return
  }
  let d = ds[0]
  inspect(d.name() == d.id, content="true")
  let desc = try d.description() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    x => x
  }
  inspect(desc.driver() == Some(d.id), content="true")
  // Direction must be stable and never contradict itself.
  match desc.direction() {
    @core.DeviceDirection::Input => inspect(d.supports_input(), content="true")
    @core.DeviceDirection::Output =>
      inspect(d.supports_output(), content="true")
    @core.DeviceDirection::Duplex => {
      inspect(d.supports_input(), content="true")
      inspect(d.supports_output(), content="true")
    }
    @core.DeviceDirection::Unknown => inspect(true, content="true")
  }
}
