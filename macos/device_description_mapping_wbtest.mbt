///|
test "coreaudio interface type tag mapping" {
  inspect(coreaudio_interface_type_from_tag(1), content="BuiltIn")
  inspect(coreaudio_interface_type_from_tag(2), content="Usb")
  inspect(coreaudio_interface_type_from_tag(3), content="Bluetooth")
  inspect(coreaudio_interface_type_from_tag(4), content="Pci")
  inspect(coreaudio_interface_type_from_tag(5), content="FireWire")
  inspect(coreaudio_interface_type_from_tag(6), content="Thunderbolt")
  inspect(coreaudio_interface_type_from_tag(7), content="Hdmi")
  inspect(coreaudio_interface_type_from_tag(10), content="Network")
  inspect(coreaudio_interface_type_from_tag(11), content="Virtual")
  inspect(coreaudio_interface_type_from_tag(12), content="DisplayPort")
  inspect(coreaudio_interface_type_from_tag(13), content="Aggregate")
  inspect(coreaudio_interface_type_from_tag(0), content="Unknown")
}
