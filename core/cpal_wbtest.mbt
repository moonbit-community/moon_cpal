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
test "cmp_default_heuristics (ported from upstream cpal/src/lib.rs)" {
  let formats : Array[SupportedStreamConfigRange] = [
    {
      buffer_size: Range(min=256, max=512),
      channels: 2,
      min_sample_rate: 1,
      max_sample_rate: 96000,
      sample_format: F32,
    },
    {
      buffer_size: Range(min=256, max=512),
      channels: 1,
      min_sample_rate: 1,
      max_sample_rate: 96000,
      sample_format: F32,
    },
    {
      buffer_size: Range(min=256, max=512),
      channels: 2,
      min_sample_rate: 1,
      max_sample_rate: 96000,
      sample_format: I16,
    },
    {
      buffer_size: Range(min=256, max=512),
      channels: 2,
      min_sample_rate: 1,
      max_sample_rate: 96000,
      sample_format: U16,
    },
    {
      buffer_size: Range(min=256, max=512),
      channels: 2,
      min_sample_rate: 1,
      max_sample_rate: 22050,
      sample_format: F32,
    },
  ]

  // Simple in-place bubble sort to avoid relying on any particular std sort API.
  let n = formats.length()
  for i = 0; i < n; i = i + 1 {
    for j = 0; j + 1 < n; j = j + 1 {
      if formats[j].cmp_default_heuristics(formats[j + 1]) > 0 {
        let tmp = formats[j]
        formats[j] = formats[j + 1]
        formats[j + 1] = tmp
      }
    }
  }
  inspect(formats[0].sample_format(), content="F32")
  inspect(formats[0].min_sample_rate(), content="1")
  inspect(formats[0].max_sample_rate(), content="96000")
  inspect(formats[0].channels(), content="1")
  inspect(formats[1].sample_format(), content="U16")
  inspect(formats[1].min_sample_rate(), content="1")
  inspect(formats[1].max_sample_rate(), content="96000")
  inspect(formats[1].channels(), content="2")
  inspect(formats[2].sample_format(), content="I16")
  inspect(formats[2].min_sample_rate(), content="1")
  inspect(formats[2].max_sample_rate(), content="96000")
  inspect(formats[2].channels(), content="2")
  inspect(formats[3].sample_format(), content="F32")
  inspect(formats[3].min_sample_rate(), content="1")
  inspect(formats[3].max_sample_rate(), content="22050")
  inspect(formats[3].channels(), content="2")
  inspect(formats[4].sample_format(), content="F32")
  inspect(formats[4].min_sample_rate(), content="1")
  inspect(formats[4].max_sample_rate(), content="96000")
  inspect(formats[4].channels(), content="2")
}

///|
test "stream_instant add/sub (ported from upstream cpal/src/lib.rs)" {
  let a = StreamInstant(2L, 0)
  let b = StreamInstant(-2L, 0)
  let min = StreamInstant(-9223372036854775808L, 0)
  let max = StreamInstant(9223372036854775807L, 0)
  @debug.debug_inspect(
    a.sub(Duration::from_secs(1)),
    content=(
      #|Some({ secs: 1, nanos: 0 })
    ),
  )
  @debug.debug_inspect(
    a.sub(Duration::from_secs(2)),
    content=(
      #|Some({ secs: 0, nanos: 0 })
    ),
  )
  @debug.debug_inspect(
    a.sub(Duration::from_secs(3)),
    content=(
      #|Some({ secs: -1, nanos: 0 })
    ),
  )
  @debug.debug_inspect(min.sub(Duration::from_secs(1)), content="None")
  @debug.debug_inspect(
    b.add(Duration::from_secs(1)),
    content=(
      #|Some({ secs: -1, nanos: 0 })
    ),
  )
  @debug.debug_inspect(
    b.add(Duration::from_secs(2)),
    content=(
      #|Some({ secs: 0, nanos: 0 })
    ),
  )
  @debug.debug_inspect(
    b.add(Duration::from_secs(3)),
    content=(
      #|Some({ secs: 1, nanos: 0 })
    ),
  )
  @debug.debug_inspect(max.add(Duration::from_secs(1)), content="None")
}

///|
test "stream_instant duration_since (ported from upstream cpal/src/lib.rs)" {
  let a = StreamInstant(2L, 0)
  let b = StreamInstant(1L, 0)
  @debug.debug_inspect(a.duration_since(b), content=(
    #|Some({ secs: 1, nanos: 0 })
  ))
  @debug.debug_inspect(b.duration_since(a), content="None")
  let c = StreamInstant(1L, 100)
  let d = StreamInstant(0L, 200)
  @debug.debug_inspect(
    c.duration_since(d),
    content=(
      #|Some({ secs: 0, nanos: 999999900 })
    ),
  )
}

///|
test "duration constructor supports nanos" {
  inspect(Duration(2UL, 123), content="{secs: 2, nanos: 123}")
  inspect(Duration(2UL, 1_000_000_123), content="{secs: 3, nanos: 123}")
}

///|
test "sample_format properties (ported from upstream cpal/src/samples_formats.rs)" {
  let formats : Array[SampleFormat] = [
    I8,
    I16,
    I24,
    I32,
    I64,
    U8,
    U16,
    U24,
    U32,
    U64,
    F32,
    F64,
    DsdU8,
    DsdU16,
    DsdU32,
  ]
  let out = formats.map(fn(fmt) {
    "\{fmt.to_string()}:size=\{fmt.sample_size()}:bits=\{fmt.bits_per_sample()}:int=\{fmt.is_int()}:uint=\{fmt.is_uint()}:float=\{fmt.is_float()}:dsd=\{fmt.is_dsd()}"
  })
  @debug.debug_inspect(
    out,
    content=(
      #|[
      #|  "i8:size=1:bits=8:int=true:uint=false:float=false:dsd=false",
      #|  "i16:size=2:bits=16:int=true:uint=false:float=false:dsd=false",
      #|  "i24:size=4:bits=24:int=true:uint=false:float=false:dsd=false",
      #|  "i32:size=4:bits=32:int=true:uint=false:float=false:dsd=false",
      #|  "i64:size=8:bits=64:int=true:uint=false:float=false:dsd=false",
      #|  "u8:size=1:bits=8:int=false:uint=true:float=false:dsd=false",
      #|  "u16:size=2:bits=16:int=false:uint=true:float=false:dsd=false",
      #|  "u24:size=4:bits=24:int=false:uint=true:float=false:dsd=false",
      #|  "u32:size=4:bits=32:int=false:uint=true:float=false:dsd=false",
      #|  "u64:size=8:bits=64:int=false:uint=true:float=false:dsd=false",
      #|  "f32:size=4:bits=32:int=false:uint=false:float=true:dsd=false",
      #|  "f64:size=8:bits=64:int=false:uint=false:float=true:dsd=false",
      #|  "dsdu8:size=1:bits=1:int=false:uint=false:float=false:dsd=true",
      #|  "dsdu16:size=2:bits=1:int=false:uint=false:float=false:dsd=true",
      #|  "dsdu32:size=4:bits=1:int=false:uint=false:float=false:dsd=true",
      #|]
    ),
  )
}

///|
test "supported_config_range sample-rate helpers" {
  let range = SupportedStreamConfigRange(
    2,
    10,
    20,
    Range(min=128, max=256),
    I16,
  )
  @debug.debug_inspect(range.try_with_sample_rate(9), content="None")
  match range.try_with_sample_rate(10) {
    None => inspect(false, content="true")
    Some(cfg) => {
      inspect(cfg.channels(), content="2")
      inspect(cfg.sample_rate(), content="10")
      inspect(cfg.sample_format(), content="I16")
      inspect(cfg.buffer_size(), content="Range(min=128, max=256)")
    }
  }
  let cfg_max = range.with_max_sample_rate()
  inspect(cfg_max.sample_rate(), content="20")
  let cfg_in = range.with_sample_rate(15)
  inspect(cfg_in.sample_rate(), content="15")
}

///|
test "supported_buffer_size contains" {
  inspect(Range(min=128, max=256).contains(0), content="false")
  inspect(Range(min=128, max=256).contains(127), content="false")
  inspect(Range(min=128, max=256).contains(128), content="true")
  inspect(Range(min=128, max=256).contains(200), content="true")
  inspect(Range(min=128, max=256).contains(256), content="true")
  inspect(Range(min=128, max=256).contains(257), content="false")
  inspect(SupportedBufferSize::Unknown.contains(1), content="true")
  inspect(SupportedBufferSize::Unknown.contains(-1), content="false")
}

///|
test "device description formatting" {
  let d0 = DeviceDescription("My Device")
  inspect(d0.to_string(), content="My Device")
  inspect(d0.supports_input(), content="false")
  inspect(d0.supports_output(), content="false")
  let d1 = DeviceDescription(
    "My Device",
    manufacturer=Some("ACME"),
    device_type=Speaker,
    interface_type=Usb,
    direction=Output,
  )
  inspect(d1.to_string(), content="My Device (ACME) [Speaker] via USB")
  inspect(d1.supports_input(), content="false")
  inspect(d1.supports_output(), content="true")
}

///|
test "device description builder + direction_from_caps" {
  inspect(direction_from_caps(true, true), content="Duplex")
  inspect(direction_from_caps(true, false), content="Input")
  inspect(direction_from_caps(false, true), content="Output")
  inspect(direction_from_caps(false, false), content="Unknown")
  inspect(direction_from_counts(Some(2), Some(2)), content="Duplex")
  inspect(direction_from_counts(Some(2), Some(0)), content="Input")
  inspect(direction_from_counts(None, Some(2)), content="Output")
  inspect(direction_from_counts(None, None), content="Unknown")
  let built = DeviceDescriptionBuilder("X")
    .manufacturer("ACME")
    .driver("drv")
    .device_type(DeviceType::speaker())
    .interface_type(InterfaceType::usb())
    .direction(DeviceDirection::output())
    .address("addr")
    .add_extended_line("line1")
    .add_extended_line("line2")
    .build()
  inspect(built.to_string(), content="X (ACME) [Speaker] via USB")
  @debug.debug_inspect(built.driver(), content="Some(\"drv\")")
  @debug.debug_inspect(built.address(), content="Some(\"addr\")")
  inspect(built.extended().length(), content="2")
}

///|
test "callback timestamp types" {
  let callback = StreamInstant(1L, 2)
  let capture = StreamInstant(3L, 4)
  let playback = StreamInstant(5L, 6)
  let in_ts = InputStreamTimestamp(callback, capture)
  let out_ts = OutputStreamTimestamp(callback, playback)
  inspect(in_ts.callback(), content="{secs: 1, nanos: 2}")
  inspect(in_ts.capture(), content="{secs: 3, nanos: 4}")
  inspect(out_ts.callback(), content="{secs: 1, nanos: 2}")
  inspect(out_ts.playback(), content="{secs: 5, nanos: 6}")
  let in_info = InputCallbackInfo(in_ts)
  let out_info = OutputCallbackInfo(out_ts)
  inspect(
    in_info.timestamp(),
    content="{callback: {secs: 1, nanos: 2}, capture: {secs: 3, nanos: 4}}",
  )
  inspect(
    out_info.timestamp(),
    content="{callback: {secs: 1, nanos: 2}, playback: {secs: 5, nanos: 6}}",
  )
}

///|
test "host_id parsing" {
  @debug.debug_inspect(
    HostId::from_string("coreaudio"),
    content="Some(CoreAudio)",
  )
  @debug.debug_inspect(
    HostId::from_string("CoReAuDiO"),
    content="Some(CoreAudio)",
  )
  inspect(HostId::name(CoreAudio), content="CoreAudio")
  @debug.debug_inspect(HostId::from_string("unknown"), content="None")
  try HostId::parse("unknown") catch {
    HostUnavailable => inspect(true, content="true")
  } noraise {
    _ => inspect(false, content="true")
  }
}

///|
test "device_id parsing and formatting" {
  let id = DeviceId(CoreAudio, "abc")
  inspect(id.to_string(), content="coreaudio:abc")
  try DeviceId::from_string("coreaudio:abc") catch {
    _ => inspect(false, content="true")
  } noraise {
    parsed => inspect(parsed == id, content="true")
  }
  try DeviceId::from_string("unknown:abc") catch {
    UnsupportedPlatform => inspect(true, content="true")
    _ => inspect(false, content="true")
  } noraise {
    _ => inspect(false, content="true")
  }
  try DeviceId::from_string("coreaudio") catch {
    BackendSpecific(_) => inspect(true, content="true")
    _ => inspect(false, content="true")
  } noraise {
    _ => inspect(false, content="true")
  }
}

///|
test "error helper constructors" {
  inspect(
    build_stream_error_device_not_available(),
    content="DeviceNotAvailable",
  )
  inspect(
    play_stream_error_backend_specific("x"),
    content="BackendSpecific({description: \"x\"})",
  )
  inspect(
    pause_stream_error_device_not_available(),
    content="DeviceNotAvailable",
  )
  inspect(stream_error_stream_invalidated(), content="StreamInvalidated")
  inspect(
    devices_error_backend_specific("x"),
    content="BackendSpecific({description: \"x\"})",
  )
  inspect(
    device_name_error_backend_specific("x"),
    content="BackendSpecific({description: \"x\"})",
  )
}
