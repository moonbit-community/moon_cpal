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
fn expected_device_id(device_id : UInt) -> @core.DeviceId {
  match device_uid(device_id) {
    Some(uid) if uid.trim().length() > 0 =>
      @core.DeviceId::new(@core.HostId::CoreAudio, uid)
    _ => @core.DeviceId::new(@core.HostId::CoreAudio, device_id.to_string())
  }
}

///|
fn contains_device_id(devices : Array[Device], id : @core.DeviceId) -> Bool {
  for d in devices {
    if d.id() == id {
      return true
    }
  }
  false
}

///|
test "macos enumerate parity: devices ordering + default device mapping" {
  if @core.native_os() != @core.NativeOs::Macos {
    inspect(true, content="true")
    return
  }
  let host = default_host()
  let devices = try host.devices() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    xs => xs
  }
  let raw_ids = try device_ids() catch {
    _ => {
      inspect(true, content="true")
      return
    }
  } noraise {
    xs => xs
  }
  inspect(devices.length() == raw_ids.length(), content="true")
  let n = if devices.length() < raw_ids.length() {
    devices.length()
  } else {
    raw_ids.length()
  }
  for i in 0..<n {
    inspect(devices[i].id() == expected_device_id(raw_ids[i]), content="true")
  }
  match default_output_device_id() {
    None => inspect(host.default_output_device() is None, content="true")
    Some(raw_id) => {
      let expected = expected_device_id(raw_id)
      match host.default_output_device() {
        None => inspect(false, content="true")
        Some(dev) => {
          inspect(dev.id() == expected, content="true")
          inspect(contains_device_id(devices, expected), content="true")
        }
      }
    }
  }
  match default_input_device_id() {
    None => inspect(host.default_input_device() is None, content="true")
    Some(raw_id) => {
      let expected = expected_device_id(raw_id)
      match host.default_input_device() {
        None => inspect(false, content="true")
        Some(dev) => {
          inspect(dev.id() == expected, content="true")
          inspect(contains_device_id(devices, expected), content="true")
        }
      }
    }
  }
}
