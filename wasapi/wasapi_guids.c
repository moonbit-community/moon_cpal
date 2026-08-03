#include <stdint.h>

#if defined(_WIN32)

// Provide GUID/IID/CLSID definitions for Windows builds.
//
// Some Windows SDK/header/lib combinations declare these WASAPI symbols but do not provide
// linkable definitions in `uuid.lib`. Keep local definitions so the native stubs link reliably.
//
// This file is compiled into the wasapi native stub library for all native targets, but
// does nothing on non-Windows.

#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <propidl.h>
#include <functiondiscoverykeys_devpkey.h>

const IID IID_IAudioClient = {
    0x1CB9AD4C, 0xDBFA, 0x4C32, {0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2}};
const IID IID_IAudioClient2 = {
    0x726778CD, 0xF60A, 0x4EDA, {0x82, 0xDE, 0xE4, 0x76, 0x10, 0xCD, 0x78, 0xAA}};
const IID IID_IAudioRenderClient = {
    0xF294ACFC, 0x3146, 0x4483, {0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2}};
const IID IID_IAudioCaptureClient = {
    0xC8ADBD64, 0xE71E, 0x48A0, {0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17}};
const IID IID_IMMEndpoint = {
    0x1BE09788, 0x6894, 0x4089, {0x85, 0x86, 0x9A, 0x2A, 0x6C, 0x26, 0x5A, 0xC5}};
const IID IID_IMMDeviceEnumerator = {
    0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}};
const CLSID CLSID_MMDeviceEnumerator = {
    0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}};

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
