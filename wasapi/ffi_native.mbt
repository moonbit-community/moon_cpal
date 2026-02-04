///|
/// Native FFI hooks for WASAPI (Windows).

///|
extern "C" fn wasapi_devices_utf8() -> Bytes = "moon_cpal_wasapi_devices_utf8"

///|
#owned(device_id_utf8)
extern "C" fn wasapi_device_name_utf8_len(
  device_id_utf8 : Bytes,
  device_id_len : Int,
) -> Int = "moon_cpal_wasapi_device_name_utf8_len"

///|
#borrow(out)
#owned(device_id_utf8)
extern "C" fn wasapi_device_name_utf8(
  device_id_utf8 : Bytes,
  device_id_len : Int,
  out : Bytes,
  out_len : Int,
) -> Int = "moon_cpal_wasapi_device_name_utf8"

///|
#borrow(out)
#owned(device_id_utf8)
extern "C" fn wasapi_default_config_u32(
  device_id_utf8 : Bytes,
  device_id_len : Int,
  is_input : Int,
  out : FixedArray[UInt],
  out_len : Int,
) -> Int = "moon_cpal_wasapi_default_config_u32"

///|
#owned(device_id_utf8)
extern "C" fn wasapi_device_data_flow_tag(
  device_id_utf8 : Bytes,
  device_id_len : Int,
) -> Int = "moon_cpal_wasapi_device_data_flow_tag"

///|
#borrow(out)
#owned(device_id_utf8)
extern "C" fn wasapi_default_config_ex_u32(
  device_id_utf8 : Bytes,
  device_id_len : Int,
  is_input : Int,
  out : FixedArray[UInt],
  out_len : Int,
) -> Int = "moon_cpal_wasapi_default_config_ex_u32"

///|
#borrow(out)
#owned(device_id_utf8)
extern "C" fn wasapi_supported_configs_u32(
  device_id_utf8 : Bytes,
  device_id_len : Int,
  is_input : Int,
  out : FixedArray[UInt],
  out_len : Int,
) -> Int = "moon_cpal_wasapi_supported_configs_u32"

///|
pub fn devices_utf8() -> Bytes {
  wasapi_devices_utf8()
}

///|
pub fn device_name_utf8(id : String) -> String? {
  if id.length() == 0 {
    return None
  }
  let b1 = @moon_cpal.string_to_utf8_bytes(id)
  let id_len = b1.length()
  let n = wasapi_device_name_utf8_len(b1, id_len)
  if n <= 0 {
    return None
  }
  let out = Bytes::make(n, (0 : Int).to_byte())
  let b2 = @moon_cpal.string_to_utf8_bytes(id)
  let used = wasapi_device_name_utf8(b2, id_len, out, out.length())
  if used <= 0 {
    return None
  }
  let need = if used > out.length() { out.length() } else { used }
  Some(@moon_cpal.utf8_bytes_to_string(out, need))
}

///|
pub fn default_config_u32(id : String, is_input : Bool) -> (UInt, UInt, UInt)? {
  let b = @moon_cpal.string_to_utf8_bytes(id)
  let out = FixedArray::make(3, (0 : UInt))
  let st = wasapi_default_config_u32(
    b,
    b.length(),
    if is_input {
      1
    } else {
      0
    },
    out,
    3,
  )
  if st < 0 {
    None
  } else {
    Some((out[0], out[1], out[2]))
  }
}

///|
pub fn data_flow_tag(id : String) -> Int? {
  let b = @moon_cpal.string_to_utf8_bytes(id)
  let st = wasapi_device_data_flow_tag(b, b.length())
  if st <= 0 {
    None
  } else {
    Some(st)
  }
}

///|
pub fn default_config_ex_u32(
  id : String,
  is_input : Bool,
) -> (UInt, UInt, UInt, UInt, UInt)? {
  let b = @moon_cpal.string_to_utf8_bytes(id)
  let out = FixedArray::make(5, (0 : UInt))
  let st = wasapi_default_config_ex_u32(
    b,
    b.length(),
    if is_input {
      1
    } else {
      0
    },
    out,
    5,
  )
  if st < 0 {
    None
  } else {
    Some((out[0], out[1], out[2], out[3], out[4]))
  }
}

///|
pub fn supported_configs_u32(
  id : String,
  is_input : Bool,
) -> (Int, FixedArray[UInt])? {
  // 21 sample rates * 2 formats => 42 entries, each uses 5 u32s.
  let out = FixedArray::make(5 * 64, (0 : UInt))
  let b = @moon_cpal.string_to_utf8_bytes(id)
  let st = wasapi_supported_configs_u32(
    b,
    b.length(),
    if is_input {
      1
    } else {
      0
    },
    out,
    out.length(),
  )
  if st < 0 {
    None
  } else {
    Some((st, out))
  }
}
