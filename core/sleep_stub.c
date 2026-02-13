#include <stdint.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <time.h>
#endif

void moon_cpal_sleep_millis(uint32_t ms) {
  if (ms == 0) {
    return;
  }
#if defined(_WIN32)
  Sleep((DWORD)ms);
#else
  struct timespec ts;
  ts.tv_sec = (time_t)(ms / 1000u);
  ts.tv_nsec = (long)((ms % 1000u) * 1000000u);
  (void)nanosleep(&ts, NULL);
#endif
}

