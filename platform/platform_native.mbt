///|
pub fn default_host() -> Host {
  match @core.native_os() {
    @core.NativeOs::Macos => Host::CoreAudio(@macos.default_host())
    @core.NativeOs::Linux => Host::Alsa(@alsa.default_host())
    @core.NativeOs::Windows => Host::Wasapi(@wasapi.default_host())
    @core.NativeOs::Unknown => Host::Null(@null.default_host())
  }
}
