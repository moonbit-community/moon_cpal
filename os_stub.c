#include <stdint.h>

// Expose a small, stable tag so MoonBit can select platform backends in native builds.
//
// Returns:
// - 1 => macOS
// - 2 => Windows
// - 3 => Linux
// - 0 => unknown/other
int32_t moon_cpal_os_tag(void) {
#if defined(__APPLE__) && defined(__MACH__)
  return 1;
#elif defined(_WIN32)
  return 2;
#elif defined(__linux__)
  return 3;
#else
  return 0;
#endif
}

