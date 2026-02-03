///|
pub fn default_host() -> Host {
  match @moon_cpal.native_os() {
    @moon_cpal.NativeOs::Macos => Host::CoreAudio(@macos.default_host())
    @moon_cpal.NativeOs::Linux => Host::Alsa(@alsa.default_host())
    @moon_cpal.NativeOs::Windows => Host::Wasapi(@wasapi.default_host())
    @moon_cpal.NativeOs::Unknown => Host::Null(@null.default_host())
  }
}
