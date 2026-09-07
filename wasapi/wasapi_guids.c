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

#if defined(_MSC_VER)
// Windows SDK headers only declare these IDs; uuid.lib does not define them.
// Values match the Windows interfaces in the MinGW-w64 SDK headers:
// https://github.com/mingw-w64/mingw-w64/tree/master/mingw-w64-headers/include
DEFINE_GUID(IID_IAudioClient, 0x1cb9ad4c, 0xdbfa, 0x4c32, 0xb1,0x78, 0xc2,0xf5,0x68,0xa7,0x03,0xb2);
DEFINE_GUID(IID_IAudioClient2, 0x726778cd, 0xf60a, 0x4eda, 0x82,0xde, 0xe4,0x76,0x10,0xcd,0x78,0xaa);
DEFINE_GUID(IID_IAudioRenderClient, 0xf294acfc, 0x3146, 0x4483, 0xa7,0xbf, 0xad,0xdc,0xa7,0xc2,0x60,0xe2);
DEFINE_GUID(IID_IAudioCaptureClient, 0xc8adbd64, 0xe71e, 0x48a0, 0xa4,0xde, 0x18,0x5c,0x39,0x5c,0xd3,0x17);
DEFINE_GUID(IID_IMMEndpoint, 0x1be09788, 0x6894, 0x4089, 0x85,0x86, 0x9a,0x2a,0x6c,0x26,0x5a,0xc5);
DEFINE_GUID(IID_IMMDeviceEnumerator, 0xa95664d2, 0x9614, 0x4f35, 0xa7,0x46, 0xde,0x8d,0xb6,0x36,0x17,0xe6);
DEFINE_GUID(CLSID_MMDeviceEnumerator, 0xbcde0395, 0xe52f, 0x467c, 0x8e,0x3d, 0xc4,0x57,0x92,0x91,0x69,0x2e);
#endif

#endif
