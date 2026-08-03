#include <stdint.h>

#if defined(_WIN32)

// Provide GUID/IID/CLSID definitions for MinGW builds.
//
// Some Windows SDK headers declare various CLSID/IID symbols as `extern`.
// On MSVC these are typically provided by `uuid.lib`, but on MinGW they may be missing.
// Including `initguid.h` before the relevant headers makes `DEFINE_GUID(...)` instantiate
// the symbols in this translation unit.
//
// This file is compiled into the wasapi native stub library for all native targets, but
// does nothing on non-Windows.

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <initguid.h>

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <propidl.h>
#include <functiondiscoverykeys_devpkey.h>

#endif

void moon_cpal_wasapi_guid_anchor(void) {
#if defined(_WIN32)
  volatile const void *refs[] = {
      (const void *)&IID_IAudioClient,
      (const void *)&IID_IAudioClient2,
      (const void *)&IID_IAudioRenderClient,
      (const void *)&IID_IAudioCaptureClient,
      (const void *)&IID_IMMEndpoint,
      (const void *)&IID_IMMDeviceEnumerator,
      (const void *)&CLSID_MMDeviceEnumerator,
  };
  (void)refs;
#endif
}
