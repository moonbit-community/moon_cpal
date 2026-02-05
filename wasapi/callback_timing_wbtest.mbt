///|
test "wasapi callback timestamps + format tags" {
  let want_cb = @core.StreamInstant::new(1, 2)
  let want_pb = @core.StreamInstant::new(3, 4)
  let got = FixedArray::make(3, false)
  call_output_data_callback(
    fn(d, info) {
      got[0] = d.sample_format() == @core.SampleFormat::F32
      got[1] = info.timestamp().callback() == want_cb
      got[2] = info.timestamp().playback() == want_pb
    },
    1,
    FixedArray::make(4, Int::to_byte(0)),
    1,
    2,
    3,
    4,
  )
  inspect(got[0], content="true")
  inspect(got[1], content="true")
  inspect(got[2], content="true")
  let want_cb2 = @core.StreamInstant::new(5, 6)
  let want_cap = @core.StreamInstant::new(7, 8)
  let got2 = FixedArray::make(3, false)
  call_input_data_callback(
    fn(d, info) {
      got2[0] = d.sample_format() == @core.SampleFormat::I16
      got2[1] = info.timestamp().callback() == want_cb2
      got2[2] = info.timestamp().capture() == want_cap
    },
    2,
    FixedArray::make(4, Int::to_byte(0)),
    5,
    6,
    7,
    8,
  )
  inspect(got2[0], content="true")
  inspect(got2[1], content="true")
  inspect(got2[2], content="true")
}
