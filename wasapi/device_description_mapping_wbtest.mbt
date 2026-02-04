///|
test "wasapi interface type: enumerator mapping" {
  inspect(wasapi_interface_type_from_enumerator("usb"), content="Some(Usb)")
  inspect(
    wasapi_interface_type_from_enumerator("mmdevapi"),
    content="Some(Virtual)",
  )
  inspect(wasapi_interface_type_from_enumerator("unknown"), content="None")
}

///|
test "wasapi interface type: jack subtype mapping" {
  inspect(
    wasapi_interface_type_from_jack_subtype(
      "{d9e55ea0-0c89-4692-84ff-eb3c4b0d172f}",
    ),
    content="Some(Hdmi)",
  )
  inspect(
    wasapi_interface_type_from_jack_subtype(
      "{E47E4031-3EA6-418D-8F9B-B73843CCB2AD}",
    ),
    content="Some(DisplayPort)",
  )
  inspect(wasapi_interface_type_from_jack_subtype("not-a-guid"), content="None")
}

///|
test "wasapi device type: form factor mapping" {
  let (dt1, it1) = wasapi_types_from_form_factor((1 : UInt))
  inspect(dt1, content="Speaker")
  inspect(it1, content="None")
  let (dt3, it3) = wasapi_types_from_form_factor((3 : UInt))
  inspect(dt3, content="Headphones")
  inspect(it3, content="None")
  let (dt8, it8) = wasapi_types_from_form_factor((8 : UInt))
  inspect(dt8, content="Unknown")
  inspect(it8, content="Some(Spdif)")
}
