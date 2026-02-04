///|
/// Cross-platform host identifiers.
///
/// Ported from upstream `cpal::platform::HostId` (string representation is used for
/// cross-platform matching).

///|
pub suberror HostUnavailable {
  HostUnavailable
} derive(Show, Eq)

///|
pub fn HostUnavailable::to_string(self : HostUnavailable) -> String {
  match self {
    HostUnavailable::HostUnavailable => "the requested host is unavailable"
  }
}

///|
pub(all) enum HostId {
  AAudio
  Alsa
  Asio
  CoreAudio
  Custom
  Emscripten
  Jack
  Null
  Wasapi
  WebAudio
  AudioWorklet
} derive(Show, Eq)

///|
fn ascii_lower(c : Char) -> Int {
  let x = c.to_int()
  if 65 <= x && x <= 90 {
    x + 32
  } else {
    x
  }
}

///|
fn eq_ignore_ascii_case(a : StringView, b : StringView) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    let ca = a.get_char(i)
    let cb = b.get_char(i)
    match (ca, cb) {
      (Some(x), Some(y)) => if ascii_lower(x) != ascii_lower(y) { return false }
      _ => return false
    }
    i += 1
  }
  true
}

///|
pub fn HostId::to_string(self : HostId) -> String {
  match self {
    AAudio => "aaudio"
    Alsa => "alsa"
    Asio => "asio"
    CoreAudio => "coreaudio"
    Custom => "custom"
    Emscripten => "emscripten"
    Jack => "jack"
    Null => "null"
    Wasapi => "wasapi"
    WebAudio => "webaudio"
    AudioWorklet => "audioworklet"
  }
}

///|
pub fn HostId::from_view(v : StringView) -> HostId? {
  if eq_ignore_ascii_case(v, "aaudio") {
    Some(AAudio)
  } else if eq_ignore_ascii_case(v, "alsa") {
    Some(Alsa)
  } else if eq_ignore_ascii_case(v, "asio") {
    Some(Asio)
  } else if eq_ignore_ascii_case(v, "coreaudio") {
    Some(CoreAudio)
  } else if eq_ignore_ascii_case(v, "custom") {
    Some(Custom)
  } else if eq_ignore_ascii_case(v, "emscripten") {
    Some(Emscripten)
  } else if eq_ignore_ascii_case(v, "jack") {
    Some(Jack)
  } else if eq_ignore_ascii_case(v, "null") {
    Some(Null)
  } else if eq_ignore_ascii_case(v, "wasapi") {
    Some(Wasapi)
  } else if eq_ignore_ascii_case(v, "webaudio") {
    Some(WebAudio)
  } else if eq_ignore_ascii_case(v, "audioworklet") {
    Some(AudioWorklet)
  } else {
    None
  }
}

///|
pub fn HostId::from_string(s : String) -> HostId? {
  HostId::from_view(s[:])
}

///|
pub fn HostId::parse(s : String) -> HostId raise HostUnavailable {
  match HostId::from_string(s) {
    Some(id) => id
    None => raise HostUnavailable::HostUnavailable
  }
}

///|
pub fn host_unavailable() -> HostUnavailable {
  HostUnavailable::HostUnavailable
}
