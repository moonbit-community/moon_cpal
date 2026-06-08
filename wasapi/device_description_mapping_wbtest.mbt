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
test "wasapi interface type: enumerator mapping" {
  @debug.debug_inspect(
    wasapi_interface_type_from_enumerator("usb"),
    content="Some(Usb)",
  )
  @debug.debug_inspect(
    wasapi_interface_type_from_enumerator("mmdevapi"),
    content="Some(Virtual)",
  )
  @debug.debug_inspect(
    wasapi_interface_type_from_enumerator("unknown"),
    content="None",
  )
}

///|
test "wasapi interface type: jack subtype mapping" {
  @debug.debug_inspect(
    wasapi_interface_type_from_jack_subtype(
      "{d9e55ea0-0c89-4692-84ff-eb3c4b0d172f}",
    ),
    content="Some(Hdmi)",
  )
  @debug.debug_inspect(
    wasapi_interface_type_from_jack_subtype(
      "{E47E4031-3EA6-418D-8F9B-B73843CCB2AD}",
    ),
    content="Some(DisplayPort)",
  )
  @debug.debug_inspect(
    wasapi_interface_type_from_jack_subtype("not-a-guid"),
    content="None",
  )
}

///|
test "wasapi device type: form factor mapping" {
  let (dt1, it1) = wasapi_types_from_form_factor((1 : UInt))
  inspect(dt1, content="Speaker")
  @debug.debug_inspect(it1, content="None")
  let (dt3, it3) = wasapi_types_from_form_factor((3 : UInt))
  inspect(dt3, content="Headphones")
  @debug.debug_inspect(it3, content="None")
  let (dt8, it8) = wasapi_types_from_form_factor((8 : UInt))
  inspect(dt8, content="Unknown")
  @debug.debug_inspect(it8, content="Some(Spdif)")
}

///|
test "wasapi description name selection parity" {
  inspect(
    wasapi_description_name(Some("Device Desc"), Some("Friendly Name")),
    content="Device Desc",
  )
  inspect(
    wasapi_description_name(None, Some("Friendly Name")),
    content="Friendly Name",
  )
  inspect(
    wasapi_description_name(Some("   "), Some("Friendly Name")),
    content="Friendly Name",
  )
  let err_desc = try wasapi_description_name(None, None) catch {
    BackendSpecific(err) => Some(err.description())
  } noraise {
    _ => None
  }
  @debug.debug_inspect(
    err_desc,
    content="Some(\"failed to retrieve device name\")",
  )
}
