#include <stdint.h>
#include <stddef.h>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <time.h>
#endif

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

// Cross-platform sleep helper for native smoke tests.
//
// Note: This is *not* part of the CPAL API surface; it just avoids per-OS `extern` symbols
// (`sleep` on Unix vs `Sleep` on Windows).
void moon_cpal_sleep_ms(int32_t ms) {
  if (ms <= 0) {
    return;
  }
#if defined(_WIN32)
  Sleep((DWORD)ms);
#else
  struct timespec ts;
  ts.tv_sec = (time_t)(ms / 1000);
  ts.tv_nsec = (long)((ms % 1000) * 1000000);
  (void)nanosleep(&ts, NULL);
#endif
}

