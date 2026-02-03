#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include <mach/mach_time.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "moonbit.h"

static int32_t ca_err(OSStatus st) {
  if (st == noErr) {
    return 0;
  }
  int32_t s = (int32_t)st;
  // Ensure all errors are negative regardless of OSStatus sign convention.
  return s < 0 ? s : -s;
}

static int32_t ca_get_property_data_size(AudioObjectID object,
                                        const AudioObjectPropertyAddress *addr,
                                        uint32_t *out_size) {
  UInt32 size = 0;
  OSStatus st = AudioObjectGetPropertyDataSize(object, addr, 0, NULL, &size);
  if (st != noErr) {
    return ca_err(st);
  }
  *out_size = (uint32_t)size;
  return 0;
}

static int32_t ca_get_property_data(AudioObjectID object,
                                   const AudioObjectPropertyAddress *addr,
                                   uint32_t *io_size,
                                   void *out_data) {
  UInt32 size = (UInt32)(*io_size);
  OSStatus st = AudioObjectGetPropertyData(object, addr, 0, NULL, &size, out_data);
  if (st != noErr) {
    return ca_err(st);
  }
  *io_size = (uint32_t)size;
  return 0;
}

uint32_t moon_cpal_ca_default_output_device_id(void) {
  AudioObjectPropertyAddress addr = {
      kAudioHardwarePropertyDefaultOutputDevice,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain};
  AudioDeviceID dev = kAudioObjectUnknown;
  uint32_t size = (uint32_t)sizeof(dev);
  if (ca_get_property_data(kAudioObjectSystemObject, &addr, &size, &dev) != 0) {
    return 0;
  }
  return (uint32_t)dev;
}

uint32_t moon_cpal_ca_default_input_device_id(void) {
  AudioObjectPropertyAddress addr = {
      kAudioHardwarePropertyDefaultInputDevice,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain};
  AudioDeviceID dev = kAudioObjectUnknown;
  uint32_t size = (uint32_t)sizeof(dev);
  if (ca_get_property_data(kAudioObjectSystemObject, &addr, &size, &dev) != 0) {
    return 0;
  }
  return (uint32_t)dev;
}

// Drive the current thread's CFRunLoop for the given duration (seconds).
// Useful for CLI smoke tests where no GUI runloop is running.
void moon_cpal_ca_run_loop_for(double seconds) {
  if (seconds <= 0.0) {
    return;
  }
  (void)CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false);
}

int32_t moon_cpal_ca_device_count(void) {
  AudioObjectPropertyAddress addr = {
      kAudioHardwarePropertyDevices,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain};
  uint32_t size = 0;
  int32_t st = ca_get_property_data_size(kAudioObjectSystemObject, &addr, &size);
  if (st != 0) {
    return st;
  }
  return (int32_t)(size / (uint32_t)sizeof(AudioDeviceID));
}

int32_t moon_cpal_ca_get_devices(uint32_t *out, int32_t max) {
  if (out == NULL || max <= 0) {
    return 0;
  }

  AudioObjectPropertyAddress addr = {
      kAudioHardwarePropertyDevices,
      kAudioObjectPropertyScopeGlobal,
      kAudioObjectPropertyElementMain};

  uint32_t size = 0;
  int32_t st = ca_get_property_data_size(kAudioObjectSystemObject, &addr, &size);
  if (st != 0) {
    return st;
  }

  AudioDeviceID *ids = (AudioDeviceID *)malloc(size);
  if (ids == NULL) {
    return -1;
  }
  st = ca_get_property_data(kAudioObjectSystemObject, &addr, &size, ids);
  if (st != 0) {
    free(ids);
    return st;
  }

  int32_t count = (int32_t)(size / (uint32_t)sizeof(AudioDeviceID));
  if (count > max) {
    count = max;
  }
  for (int32_t i = 0; i < count; i++) {
    out[i] = (uint32_t)ids[i];
  }
  free(ids);
  return count;
}

int32_t moon_cpal_ca_device_name_utf8_len(uint32_t device_id) {
  AudioObjectPropertyAddress addr = {kAudioObjectPropertyName,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMain};
  CFStringRef name = NULL;
  uint32_t size = (uint32_t)sizeof(name);
  int32_t st = ca_get_property_data((AudioObjectID)device_id, &addr, &size, &name);
  if (st != 0) {
    return st;
  }
  if (name == NULL) {
    return -1;
  }

  CFRange range = CFRangeMake(0, CFStringGetLength(name));
  CFIndex used = 0;
  CFStringGetBytes(name, range, kCFStringEncodingUTF8, 0, false, NULL, 0, &used);
  return (int32_t)used;
}

int32_t moon_cpal_ca_device_name_utf8(uint32_t device_id,
                                     uint8_t *out,
                                     int32_t out_len) {
  if (out == NULL || out_len <= 0) {
    return 0;
  }

  AudioObjectPropertyAddress addr = {kAudioObjectPropertyName,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMain};
  CFStringRef name = NULL;
  uint32_t size = (uint32_t)sizeof(name);
  int32_t st = ca_get_property_data((AudioObjectID)device_id, &addr, &size, &name);
  if (st != 0) {
    return st;
  }
  if (name == NULL) {
    return -1;
  }

  CFRange range = CFRangeMake(0, CFStringGetLength(name));
  CFIndex used = 0;
  CFIndex chars = CFStringGetBytes(name,
                                  range,
                                  kCFStringEncodingUTF8,
                                  0,
                                  false,
                                  out,
                                  (CFIndex)out_len,
                                  &used);
  if (chars != range.length) {
    // Buffer too small or conversion failed.
    int32_t need = moon_cpal_ca_device_name_utf8_len(device_id);
    return need > 0 ? need : -1;
  }
  return (int32_t)used;
}

static int32_t ca_stream_channel_count(uint32_t device_id,
                                      AudioObjectPropertyScope scope) {
  AudioObjectPropertyAddress addr = {kAudioDevicePropertyStreamConfiguration,
                                     scope,
                                     kAudioObjectPropertyElementMain};

  uint32_t size = 0;
  OSStatus st =
      AudioObjectGetPropertyDataSize((AudioObjectID)device_id, &addr, 0, NULL, &size);
  if (st != noErr) {
    return ca_err(st);
  }
  if (size == 0) {
    return 0;
  }

  AudioBufferList *list = (AudioBufferList *)malloc(size);
  if (list == NULL) {
    return -1;
  }

  st = AudioObjectGetPropertyData((AudioObjectID)device_id, &addr, 0, NULL, &size, list);
  if (st != noErr) {
    free(list);
    return ca_err(st);
  }

  uint32_t n_buffers = list->mNumberBuffers;
  if (n_buffers == 0) {
    free(list);
    return 0;
  }

  int32_t channels = 0;
  for (uint32_t i = 0; i < n_buffers; i++) {
    channels += (int32_t)list->mBuffers[i].mNumberChannels;
  }

  free(list);
  return channels;
}

int32_t moon_cpal_ca_input_channel_count(uint32_t device_id) {
  return ca_stream_channel_count(device_id, kAudioObjectPropertyScopeInput);
}

int32_t moon_cpal_ca_output_channel_count(uint32_t device_id) {
  return ca_stream_channel_count(device_id, kAudioObjectPropertyScopeOutput);
}

static int32_t ca_sample_rate_ranges_count(uint32_t device_id,
                                          AudioObjectPropertyScope scope) {
  AudioObjectPropertyAddress addr = {kAudioDevicePropertyAvailableNominalSampleRates,
                                     scope,
                                     kAudioObjectPropertyElementMain};
  uint32_t size = 0;
  OSStatus st =
      AudioObjectGetPropertyDataSize((AudioObjectID)device_id, &addr, 0, NULL, &size);
  if (st != noErr) {
    return ca_err(st);
  }
  return (int32_t)(size / (uint32_t)sizeof(AudioValueRange));
}

static int32_t ca_sample_rate_ranges(uint32_t device_id,
                                    AudioObjectPropertyScope scope,
                                    double *out_mins,
                                    double *out_maxs,
                                    int32_t max) {
  if (max <= 0) {
    return 0;
  }
  if (out_mins == NULL || out_maxs == NULL) {
    return -1;
  }

  AudioObjectPropertyAddress addr = {kAudioDevicePropertyAvailableNominalSampleRates,
                                     scope,
                                     kAudioObjectPropertyElementMain};

  uint32_t size = 0;
  OSStatus st =
      AudioObjectGetPropertyDataSize((AudioObjectID)device_id, &addr, 0, NULL, &size);
  if (st != noErr) {
    return ca_err(st);
  }

  int32_t count = (int32_t)(size / (uint32_t)sizeof(AudioValueRange));
  if (count > max) {
    count = max;
  }
  if (count <= 0) {
    return 0;
  }

  AudioValueRange *ranges = (AudioValueRange *)malloc(size);
  if (ranges == NULL) {
    return -1;
  }

  st = AudioObjectGetPropertyData((AudioObjectID)device_id, &addr, 0, NULL, &size, ranges);
  if (st != noErr) {
    free(ranges);
    return ca_err(st);
  }

  for (int32_t i = 0; i < count; i++) {
    out_mins[i] = ranges[i].mMinimum;
    out_maxs[i] = ranges[i].mMaximum;
  }

  free(ranges);
  return count;
}

int32_t moon_cpal_ca_input_sample_rate_ranges_count(uint32_t device_id) {
  return ca_sample_rate_ranges_count(device_id, kAudioObjectPropertyScopeInput);
}

int32_t moon_cpal_ca_output_sample_rate_ranges_count(uint32_t device_id) {
  return ca_sample_rate_ranges_count(device_id, kAudioObjectPropertyScopeOutput);
}

int32_t moon_cpal_ca_input_sample_rate_ranges(uint32_t device_id,
                                              double *out_mins,
                                              double *out_maxs,
                                              int32_t max) {
  return ca_sample_rate_ranges(
      device_id, kAudioObjectPropertyScopeInput, out_mins, out_maxs, max);
}

int32_t moon_cpal_ca_output_sample_rate_ranges(uint32_t device_id,
                                               double *out_mins,
                                               double *out_maxs,
                                               int32_t max) {
  return ca_sample_rate_ranges(
      device_id, kAudioObjectPropertyScopeOutput, out_mins, out_maxs, max);
}

int32_t moon_cpal_ca_buffer_frame_size_range(uint32_t device_id,
                                             uint32_t *out,
                                             int32_t out_len) {
  if (out == NULL || out_len < 2) {
    return -1;
  }

  AudioObjectPropertyAddress addr = {kAudioDevicePropertyBufferFrameSizeRange,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMain};
  AudioValueRange range;
  uint32_t size = (uint32_t)sizeof(range);
  OSStatus st =
      AudioObjectGetPropertyData((AudioObjectID)device_id, &addr, 0, NULL, &size, &range);
  if (st != noErr) {
    return ca_err(st);
  }

  out[0] = (uint32_t)range.mMinimum;
  out[1] = (uint32_t)range.mMaximum;
  return 0;
}

int32_t moon_cpal_ca_default_stream_config(uint32_t device_id,
                                           int32_t input,
                                           uint32_t *out,
                                           int32_t out_len) {
  if (out == NULL || out_len < 3) {
    return -1;
  }

  AudioObjectPropertyScope scope =
      input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput;
  AudioObjectPropertyAddress addr = {kAudioDevicePropertyStreamFormat,
                                     scope,
                                     kAudioObjectPropertyElementMain};

  AudioStreamBasicDescription asbd;
  uint32_t size = (uint32_t)sizeof(asbd);
  OSStatus st =
      AudioObjectGetPropertyData((AudioObjectID)device_id, &addr, 0, NULL, &size, &asbd);
  if (st != noErr) {
    return ca_err(st);
  }

  // Match upstream cpal's behavior on macOS: support f32 and i16 for default config.
  // (Supported config ranges are currently reported as f32-only.)
  uint32_t sample_format_tag = 0;
  if (asbd.mFormatID == kAudioFormatLinearPCM) {
    if ((asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0 &&
        asbd.mBitsPerChannel == 32) {
      sample_format_tag = 1; // F32
    } else if ((asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0 &&
               asbd.mBitsPerChannel == 16) {
      sample_format_tag = 2; // I16
    }
  }

  out[0] = (uint32_t)asbd.mSampleRate;
  out[1] = (uint32_t)asbd.mChannelsPerFrame;
  out[2] = sample_format_tag;
  return 0;
}

// Classify a CPAL stub error code (negative) into a small set of categories.
//
// Returns:
// - 0: other/unknown
// - 1: device not available
// - 2: stream type not supported
int32_t moon_cpal_ca_osstatus_kind(int32_t status) {
  if (status == 0) {
    return 0;
  }
  // `status` is a negative error code (see `ca_err`). We try both sign conventions.
  OSStatus a = (OSStatus)status;
  OSStatus b = (OSStatus)(-status);

#define MATCH(x) (a == (x) || b == (x))

  if (MATCH(kAudioHardwareBadDeviceError) || MATCH(kAudioHardwareNotRunningError) ||
      MATCH(kAudioHardwareBadObjectError)) {
    return 1;
  }

  if (MATCH(kAudioDeviceUnsupportedFormatError)) {
    return 2;
  }

  return 0;
#undef MATCH
}

// -----------------------------------------------------------------------------
// AudioQueue stream lifecycle (MVP)
// -----------------------------------------------------------------------------

typedef struct {
  AudioQueueRef queue;
  int is_input;
  uint32_t buffer_bytes;
  uint32_t sample_format_tag;
  uint32_t channels;
  double sample_rate;

  // Pre-allocated MoonBit byte buffers to avoid per-callback heap allocation.
  // For output, we use a small ring so in-flight callbacks don't contend for the same buffer.
  // For input, we currently use a single scratch buffer.
  moonbit_bytes_t mb_buffer_pool[3];
  uint32_t mb_buffer_pool_len;
  uint32_t mb_buffer_pool_index;

  // MoonBit callbacks (closures) + trampolines (closed function pointers).
  //
  // NOTE: We must keep the closures alive across callbacks. Each invocation of the trampoline will
  // decref its parameters, so we incref the stored closure before calling the trampoline.
  void *mb_data_callback;
  void *mb_error_callback;
  void (*call_data_callback)(void *data_cb,
                             uint32_t sample_format_tag,
                             moonbit_bytes_t bytes,
                             int64_t callback_secs,
                             int32_t callback_nanos,
                             int64_t other_secs,
                             int32_t other_nanos);
  void (*call_error_callback)(void *err_cb, int32_t op_tag, int32_t status);
} moon_cpal_ca_stream_t;

static void ca_now_stream_instant(int64_t *out_secs, int32_t *out_nanos) {
  if (out_secs == NULL || out_nanos == NULL) {
    return;
  }
  static mach_timebase_info_data_t tb = {0};
  if (tb.denom == 0) {
    (void)mach_timebase_info(&tb);
  }
  uint64_t t = mach_absolute_time();
  __int128 ns = (__int128)t * (__int128)tb.numer / (__int128)tb.denom;
  __int128 s = ns / 1000000000;
  __int128 n = ns - s * 1000000000;
  *out_secs = (int64_t)s;
  *out_nanos = (int32_t)n;
}

static void ca_stream_instant_from_host_time(uint64_t host_time,
                                             int64_t *out_secs,
                                             int32_t *out_nanos) {
  if (out_secs == NULL || out_nanos == NULL) {
    return;
  }
  static mach_timebase_info_data_t tb = {0};
  if (tb.denom == 0) {
    (void)mach_timebase_info(&tb);
  }
  __int128 ns = (__int128)host_time * (__int128)tb.numer / (__int128)tb.denom;
  __int128 s = ns / 1000000000;
  __int128 n = ns - s * 1000000000;
  *out_secs = (int64_t)s;
  *out_nanos = (int32_t)n;
}

static void ca_invoke_error(moon_cpal_ca_stream_t *s, int32_t op_tag, int32_t status) {
  if (s == NULL || s->call_error_callback == NULL || s->mb_error_callback == NULL) {
    return;
  }
  // Keep the stored closure alive across the trampoline call.
  moonbit_incref(s->mb_error_callback);
  s->call_error_callback(s->mb_error_callback, op_tag, status);
}

static void ca_fill_output_buffer(moon_cpal_ca_stream_t *s,
                                  AudioQueueRef in_aq,
                                  AudioQueueBufferRef in_buffer) {
  if (s == NULL || in_buffer == NULL || in_buffer->mAudioData == NULL || s->buffer_bytes == 0 ||
      s->call_data_callback == NULL || s->mb_data_callback == NULL) {
    return;
  }
  if (s->mb_buffer_pool_len == 0 || s->mb_buffer_pool[0] == NULL) {
    return;
  }
  // Select a preallocated MoonBit buffer in a small ring.
  uint32_t idx = s->mb_buffer_pool_index % s->mb_buffer_pool_len;
  s->mb_buffer_pool_index = (idx + 1) % s->mb_buffer_pool_len;
  moonbit_bytes_t bytes = s->mb_buffer_pool[idx];
  memset(bytes, 0, s->buffer_bytes);

  int64_t cb_secs = 0;
  int32_t cb_nanos = 0;
  ca_now_stream_instant(&cb_secs, &cb_nanos);

  // Best-effort playback timestamp: use AudioQueue's host time when available.
  int64_t pb_secs = cb_secs;
  int32_t pb_nanos = cb_nanos;
  if (in_aq != NULL) {
    AudioTimeStamp ts;
    memset(&ts, 0, sizeof(ts));
    OSStatus os = AudioQueueGetCurrentTime(in_aq, NULL, &ts, NULL);
    if (os == noErr && (ts.mFlags & kAudioTimeStampHostTimeValid) != 0) {
      ca_stream_instant_from_host_time(ts.mHostTime, &pb_secs, &pb_nanos);
    }
  }

  // Keep the stored closure alive across the trampoline call.
  moonbit_incref(s->mb_data_callback);
  // Keep the buffer alive across the trampoline call (callee decrefs owned params).
  moonbit_incref(bytes);
  s->call_data_callback(s->mb_data_callback, s->sample_format_tag, bytes, cb_secs, cb_nanos, pb_secs,
                        pb_nanos);

  memcpy(in_buffer->mAudioData, bytes, s->buffer_bytes);
  in_buffer->mAudioDataByteSize = s->buffer_bytes;
}

static void ca_output_callback(void *in_user_data,
                               AudioQueueRef in_aq,
                               AudioQueueBufferRef in_buffer) {
  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)in_user_data;
  if (s == NULL || in_buffer == NULL) {
    return;
  }
  ca_fill_output_buffer(s, in_aq, in_buffer);
  OSStatus st = AudioQueueEnqueueBuffer(in_aq, in_buffer, 0, NULL);
  if (st != noErr) {
    // During Reset/Stop/Dispose, enqueueing is not permitted; don't surface this as a user error.
    if (st != kAudioQueueErr_EnqueueDuringReset && st != kAudioQueueErr_DisposalPending) {
      ca_invoke_error(s, 1 /* AudioQueueEnqueueBuffer */, ca_err(st));
    }
  }
}

static void ca_input_callback(void *in_user_data,
                              AudioQueueRef in_aq,
                              AudioQueueBufferRef in_buffer,
                              const AudioTimeStamp *in_start_time,
                              UInt32 in_num_packets,
                              const AudioStreamPacketDescription *in_packet_desc) {
  (void)in_num_packets;
  (void)in_packet_desc;
  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)in_user_data;
  if (s == NULL || in_buffer == NULL) {
    return;
  }
  if (s->call_data_callback != NULL && s->mb_data_callback != NULL &&
      in_buffer->mAudioData != NULL && in_buffer->mAudioDataByteSize > 0) {
    if (s->mb_buffer_pool_len == 0 || s->mb_buffer_pool[0] == NULL) {
      goto input_reenqueue;
    }
    moonbit_bytes_t bytes = s->mb_buffer_pool[0];
    uint32_t n = (uint32_t)in_buffer->mAudioDataByteSize;
    uint32_t cap = s->buffer_bytes;
    if (n > cap) {
      n = cap;
    }
    memcpy(bytes, in_buffer->mAudioData, n);
    if (n < cap) {
      memset(bytes + n, 0, cap - n);
    }

    int64_t cb_secs = 0;
    int32_t cb_nanos = 0;
    ca_now_stream_instant(&cb_secs, &cb_nanos);

    int64_t cap_secs = cb_secs;
    int32_t cap_nanos = cb_nanos;
    if (in_start_time != NULL) {
      if ((in_start_time->mFlags & kAudioTimeStampHostTimeValid) != 0) {
        ca_stream_instant_from_host_time(in_start_time->mHostTime, &cap_secs, &cap_nanos);
      } else if ((in_start_time->mFlags & kAudioTimeStampSampleTimeValid) != 0 && s->sample_rate > 0.0) {
        // Relative-to-queue-start sample time fallback. Keep callback/capture epochs aligned.
        double secs_f = in_start_time->mSampleTime / s->sample_rate;
        int64_t secs_i = (int64_t)secs_f;
        double frac = secs_f - (double)secs_i;
        if (frac < 0.0) {
          frac = 0.0;
        }
        int32_t nanos_i = (int32_t)(frac * 1000000000.0);
        cap_secs = secs_i;
        cap_nanos = nanos_i;
        cb_secs = secs_i;
        cb_nanos = nanos_i;
      }
    }

    // Keep the stored closure alive across the trampoline call.
    moonbit_incref(s->mb_data_callback);
    // Keep the buffer alive across the trampoline call (callee decrefs owned params).
    moonbit_incref(bytes);
    s->call_data_callback(s->mb_data_callback, s->sample_format_tag, bytes, cb_secs, cb_nanos, cap_secs,
                          cap_nanos);
  }

  // Re-enqueue buffer for continued capture.
input_reenqueue:
  in_buffer->mAudioDataByteSize = s->buffer_bytes;
  OSStatus st = AudioQueueEnqueueBuffer(in_aq, in_buffer, 0, NULL);
  if (st != noErr) {
    if (st != kAudioQueueErr_EnqueueDuringReset && st != kAudioQueueErr_DisposalPending) {
      ca_invoke_error(s, 1 /* AudioQueueEnqueueBuffer */, ca_err(st));
    }
  }
}

static int32_t ca_make_asbd(double sample_rate,
                            uint32_t channels,
                            uint32_t sample_format_tag,
                            AudioStreamBasicDescription *out) {
  if (out == NULL || channels == 0 || sample_rate <= 0.0) {
    return -1;
  }

  uint32_t bytes_per_sample = 0;
  uint32_t bits_per_channel = 0;
  uint32_t flags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;

  switch (sample_format_tag) {
    case 1: // F32
      bytes_per_sample = 4;
      bits_per_channel = 32;
      flags |= kAudioFormatFlagIsFloat;
      break;
    case 2: // I16
      bytes_per_sample = 2;
      bits_per_channel = 16;
      flags |= kAudioFormatFlagIsSignedInteger;
      break;
    default:
      // Match `moon_cpal_ca_osstatus_kind`: treat as "stream type not supported".
      return ca_err(kAudioDeviceUnsupportedFormatError);
  }

  memset(out, 0, sizeof(*out));
  out->mSampleRate = sample_rate;
  out->mFormatID = kAudioFormatLinearPCM;
  out->mFormatFlags = flags;
  out->mFramesPerPacket = 1;
  out->mChannelsPerFrame = channels;
  out->mBitsPerChannel = bits_per_channel;
  out->mBytesPerFrame = channels * bytes_per_sample;
  out->mBytesPerPacket = out->mBytesPerFrame;
  return 0;
}

static int32_t ca_copy_device_uid(AudioDeviceID dev, CFStringRef *out_uid) {
  if (out_uid == NULL) {
    return -1;
  }
  *out_uid = NULL;
  AudioObjectPropertyAddress addr = {kAudioDevicePropertyDeviceUID,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMain};
  UInt32 size = (UInt32)sizeof(CFStringRef);
  CFStringRef uid = NULL;
  OSStatus st = AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, &uid);
  if (st != noErr) {
    return ca_err(st);
  }
  // Be conservative and retain; CoreAudio property ownership rules can be subtle.
  if (uid != NULL) {
    CFRetain(uid);
  }
  *out_uid = uid;
  return 0;
}

static int32_t ca_setup_queue_device(AudioQueueRef q, uint32_t device_id) {
  if (q == NULL) {
    return -1;
  }
  AudioDeviceID dev = (AudioDeviceID)device_id;

  // On modern macOS, `kAudioQueueProperty_CurrentDevice` expects a `CFStringRef` device UID
  // (not an `AudioDeviceID`).
  CFStringRef uid = NULL;
  int32_t st = ca_copy_device_uid(dev, &uid);
  if (st != 0) {
    return st;
  }
  OSStatus os = AudioQueueSetProperty(q, kAudioQueueProperty_CurrentDevice, &uid, (UInt32)sizeof(uid));
  if (uid != NULL) {
    CFRelease(uid);
  }
  if (os != noErr) {
    return ca_err(os);
  }
  return 0;
}

static uint32_t ca_default_buffer_frames(uint32_t requested) {
  // A conservative default similar to typical cpal buffers.
  return requested > 0 ? requested : 512;
}

static uint32_t ca_safe_mul_u32(uint32_t a, uint32_t b) {
  if (a == 0 || b == 0) {
    return 0;
  }
  if (a > UINT32_MAX / b) {
    return 0;
  }
  return a * b;
}

int32_t moon_cpal_ca_stream_build_output(uint32_t device_id,
                                        double sample_rate,
                                        uint32_t channels,
                                        uint32_t sample_format_tag,
                                        uint32_t buffer_frames,
                                        void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t,
                                                                  int64_t, int32_t),
                                        void *data_callback,
                                        void (*call_error_callback)(void *, int32_t, int32_t),
                                        void *error_callback,
                                        uint64_t *out_handles,
                                        int32_t out_len) {
  if (out_handles == NULL || out_len <= 0) {
    return -1;
  }
  out_handles[0] = 0;

  AudioStreamBasicDescription asbd;
  int32_t st = ca_make_asbd(sample_rate, channels, sample_format_tag, &asbd);
  if (st != 0) {
    return st;
  }

  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)malloc(sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -1;
  }
  memset(s, 0, sizeof(*s));
  s->is_input = 0;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels;
  s->sample_rate = sample_rate;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;

  OSStatus os = AudioQueueNewOutput(&asbd,
                                   ca_output_callback,
                                   s,
                                   NULL,
                                   NULL,
                                   0,
                                   &s->queue);
  if (os != noErr) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    free(s);
    return ca_err(os);
  }

  st = ca_setup_queue_device(s->queue, device_id);
  if (st != 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    AudioQueueDispose(s->queue, true);
    free(s);
    return st;
  }

  uint32_t frames = ca_default_buffer_frames(buffer_frames);
  uint32_t buffer_bytes = ca_safe_mul_u32(frames, asbd.mBytesPerFrame);
  if (buffer_bytes == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    AudioQueueDispose(s->queue, true);
    free(s);
    return -1;
  }
  s->buffer_bytes = buffer_bytes;
  s->mb_buffer_pool_len = 3;
  s->mb_buffer_pool_index = 0;
  for (uint32_t i = 0; i < s->mb_buffer_pool_len; i++) {
    s->mb_buffer_pool[i] = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)buffer_bytes, 1);
    if (s->mb_buffer_pool[i] == NULL) {
      moonbit_decref(data_callback);
      moonbit_decref(error_callback);
      AudioQueueDispose(s->queue, true);
      free(s);
      return -1;
    }
  }

  // Prime with a few buffers. Fill using the user callback so the stream is non-silent immediately.
  for (int i = 0; i < 3; i++) {
    AudioQueueBufferRef buf = NULL;
    os = AudioQueueAllocateBuffer(s->queue, buffer_bytes, &buf);
    if (os != noErr) {
      moonbit_decref(data_callback);
      moonbit_decref(error_callback);
      AudioQueueDispose(s->queue, true);
      free(s);
      return ca_err(os);
    }
    ca_fill_output_buffer(s, s->queue, buf);
    os = AudioQueueEnqueueBuffer(s->queue, buf, 0, NULL);
    if (os != noErr) {
      moonbit_decref(data_callback);
      moonbit_decref(error_callback);
      AudioQueueDispose(s->queue, true);
      free(s);
      return ca_err(os);
    }
  }

  out_handles[0] = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_ca_stream_build_input(uint32_t device_id,
                                       double sample_rate,
                                       uint32_t channels,
                                       uint32_t sample_format_tag,
                                       uint32_t buffer_frames,
                                       void (*call_data_callback)(void *, uint32_t, moonbit_bytes_t, int64_t, int32_t,
                                                                  int64_t, int32_t),
                                       void *data_callback,
                                       void (*call_error_callback)(void *, int32_t, int32_t),
                                       void *error_callback,
                                       uint64_t *out_handles,
                                       int32_t out_len) {
  if (out_handles == NULL || out_len <= 0) {
    return -1;
  }
  out_handles[0] = 0;

  AudioStreamBasicDescription asbd;
  int32_t st = ca_make_asbd(sample_rate, channels, sample_format_tag, &asbd);
  if (st != 0) {
    return st;
  }

  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)malloc(sizeof(*s));
  if (s == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    return -1;
  }
  memset(s, 0, sizeof(*s));
  s->is_input = 1;
  s->sample_format_tag = sample_format_tag;
  s->channels = channels;
  s->sample_rate = sample_rate;
  s->call_data_callback = call_data_callback;
  s->mb_data_callback = data_callback;
  s->call_error_callback = call_error_callback;
  s->mb_error_callback = error_callback;

  OSStatus os = AudioQueueNewInput(&asbd,
                                  ca_input_callback,
                                  s,
                                  NULL,
                                  NULL,
                                  0,
                                  &s->queue);
  if (os != noErr) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    free(s);
    return ca_err(os);
  }

  st = ca_setup_queue_device(s->queue, device_id);
  if (st != 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    AudioQueueDispose(s->queue, true);
    free(s);
    return st;
  }

  uint32_t frames = ca_default_buffer_frames(buffer_frames);
  uint32_t buffer_bytes = ca_safe_mul_u32(frames, asbd.mBytesPerFrame);
  if (buffer_bytes == 0) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    AudioQueueDispose(s->queue, true);
    free(s);
    return -1;
  }
  s->buffer_bytes = buffer_bytes;
  s->mb_buffer_pool_len = 1;
  s->mb_buffer_pool_index = 0;
  s->mb_buffer_pool[0] = (moonbit_bytes_t)moonbit_make_scalar_valtype_array_raw((int32_t)buffer_bytes, 1);
  if (s->mb_buffer_pool[0] == NULL) {
    moonbit_decref(data_callback);
    moonbit_decref(error_callback);
    AudioQueueDispose(s->queue, true);
    free(s);
    return -1;
  }

  // Enqueue a few buffers for capture.
  for (int i = 0; i < 3; i++) {
    AudioQueueBufferRef buf = NULL;
    os = AudioQueueAllocateBuffer(s->queue, buffer_bytes, &buf);
    if (os != noErr) {
      moonbit_decref(data_callback);
      moonbit_decref(error_callback);
      AudioQueueDispose(s->queue, true);
      free(s);
      return ca_err(os);
    }
    buf->mAudioDataByteSize = buffer_bytes;
    os = AudioQueueEnqueueBuffer(s->queue, buf, 0, NULL);
    if (os != noErr) {
      moonbit_decref(data_callback);
      moonbit_decref(error_callback);
      AudioQueueDispose(s->queue, true);
      free(s);
      return ca_err(os);
    }
  }

  out_handles[0] = (uint64_t)(uintptr_t)s;
  return 0;
}

int32_t moon_cpal_ca_stream_play(uint64_t handle) {
  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)(uintptr_t)handle;
  if (s == NULL || s->queue == NULL) {
    return -1;
  }
  OSStatus st = AudioQueueStart(s->queue, NULL);
  return ca_err(st);
}

int32_t moon_cpal_ca_stream_pause(uint64_t handle) {
  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)(uintptr_t)handle;
  if (s == NULL || s->queue == NULL) {
    return -1;
  }
  OSStatus st = AudioQueuePause(s->queue);
  return ca_err(st);
}

int32_t moon_cpal_ca_stream_destroy(uint64_t handle) {
  moon_cpal_ca_stream_t *s = (moon_cpal_ca_stream_t *)(uintptr_t)handle;
  if (s == NULL) {
    return 0;
  }
  if (s->queue != NULL) {
    AudioQueueStop(s->queue, true);
    AudioQueueDispose(s->queue, true);
    s->queue = NULL;
  }
  if (s->mb_data_callback != NULL) {
    moonbit_decref(s->mb_data_callback);
    s->mb_data_callback = NULL;
  }
  if (s->mb_error_callback != NULL) {
    moonbit_decref(s->mb_error_callback);
    s->mb_error_callback = NULL;
  }
  if (s->mb_buffer_pool_len > 0) {
    for (uint32_t i = 0; i < s->mb_buffer_pool_len && i < 3; i++) {
      if (s->mb_buffer_pool[i] != NULL) {
        moonbit_decref(s->mb_buffer_pool[i]);
        s->mb_buffer_pool[i] = NULL;
      }
    }
    s->mb_buffer_pool_len = 0;
    s->mb_buffer_pool_index = 0;
  }
  free(s);
  return 0;
}

// -----------------------------------------------------------------------------
// MoonBit-owned stream handle (finalizer-backed)
// -----------------------------------------------------------------------------

typedef struct {
  uint64_t handle;
} moon_cpal_ca_stream_owner_payload_t;

static void moon_cpal_ca_stream_owner_finalize(void *self) {
  moon_cpal_ca_stream_owner_payload_t *p = (moon_cpal_ca_stream_owner_payload_t *)self;
  if (p == NULL) {
    return;
  }
  if (p->handle != 0) {
    moon_cpal_ca_stream_destroy(p->handle);
    p->handle = 0;
  }
}

void *moon_cpal_ca_stream_owner_new(uint64_t handle) {
  moon_cpal_ca_stream_owner_payload_t *p =
      (moon_cpal_ca_stream_owner_payload_t *)moonbit_make_external_object(
          moon_cpal_ca_stream_owner_finalize, (uint32_t)sizeof(*p));
  if (p == NULL) {
    return NULL;
  }
  p->handle = handle;
  return (void *)p;
}

static uint64_t moon_cpal_ca_stream_owner_handle(void *owner) {
  moon_cpal_ca_stream_owner_payload_t *p = (moon_cpal_ca_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  return p->handle;
}

int32_t moon_cpal_ca_stream_owner_play(void *owner) {
  uint64_t h = moon_cpal_ca_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return moon_cpal_ca_stream_play(h);
}

int32_t moon_cpal_ca_stream_owner_pause(void *owner) {
  uint64_t h = moon_cpal_ca_stream_owner_handle(owner);
  if (h == 0) {
    return -1;
  }
  return moon_cpal_ca_stream_pause(h);
}

int32_t moon_cpal_ca_stream_owner_close(void *owner) {
  moon_cpal_ca_stream_owner_payload_t *p = (moon_cpal_ca_stream_owner_payload_t *)owner;
  if (p == NULL) {
    return 0;
  }
  if (p->handle != 0) {
    moon_cpal_ca_stream_destroy(p->handle);
    p->handle = 0;
  }
  return 0;
}
