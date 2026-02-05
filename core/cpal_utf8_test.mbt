///|
test "utf8 encode/decode roundtrip" {
  // Include BMP + surrogate pair codepoints.
  let s = "Hello, 你好, 😈"[:].to_string()
  let bytes = string_to_utf8_bytes(s)
  let out = utf8_bytes_to_string(bytes, bytes.length())
  inspect(out, content="Hello, 你好, 😈")
}
