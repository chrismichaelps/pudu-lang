#include "pudu_audio.h"

#include <AudioToolbox/AudioToolbox.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>

#define PUDU_AUDIO_MAX_BUFFERS 8

typedef struct {
  AudioQueueBufferRef buffers[PUDU_AUDIO_MAX_BUFFERS];
  atomic_bool available[PUDU_AUDIO_MAX_BUFFERS];
  atomic_uint_fast64_t completed_frames;
  uint32_t bytes_per_frame;
  int32_t buffer_count;
} pudu_audio_state;

static uint64_t monotonic_milliseconds(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    return 0;
  }
  return (uint64_t)now.tv_sec * 1000u + (uint64_t)now.tv_nsec / 1000000u;
}

static void wait_one_millisecond(void) {
  const struct timespec duration = {.tv_sec = 0, .tv_nsec = 1000000};
  nanosleep(&duration, NULL);
}

static void completed_buffer(
    void *context,
    AudioQueueRef queue,
    AudioQueueBufferRef buffer) {
  (void)queue;
  pudu_audio_state *state = context;
  atomic_fetch_add_explicit(
      &state->completed_frames,
      buffer->mAudioDataByteSize / state->bytes_per_frame,
      memory_order_relaxed);
  for (int32_t index = 0; index < state->buffer_count; ++index) {
    if (state->buffers[index] == buffer) {
      atomic_store_explicit(&state->available[index], true, memory_order_release);
      return;
    }
  }
}

static int32_t enqueue_chunk(
    AudioQueueRef queue,
    AudioQueueBufferRef buffer,
    const uint8_t *source,
    size_t count) {
  memcpy(buffer->mAudioData, source, count);
  buffer->mAudioDataByteSize = (UInt32)count;
  return AudioQueueEnqueueBuffer(queue, buffer, 0, NULL) == noErr
      ? PUDU_AUDIO_OK
      : PUDU_AUDIO_ENQUEUE_FAILED;
}

// The token is written by the controlling thread and read by the playing one,
// so both sides go through the same atomic view of its four bytes.
static bool cancel_requested(int32_t *cancel_token) {
  return atomic_load_explicit((atomic_int_least32_t *)cancel_token, memory_order_acquire) != 0;
}

void pudu_audio_request_cancel(int32_t *cancel_token) {
  if (cancel_token != NULL) {
    atomic_store_explicit((atomic_int_least32_t *)cancel_token, 1, memory_order_release);
  }
}

int32_t pudu_audio_play(
    int32_t sample_rate,
    int32_t channels,
    const uint8_t *pcm,
    size_t pcm_length,
    int32_t frames_per_buffer,
    int32_t buffer_count,
    int32_t timeout_ms,
    int32_t *cancel_token,
    uint64_t *completed_frames) {
  if (sample_rate < 8000 || sample_rate > 384000 || channels < 1 || channels > 8 ||
      pcm == NULL || pcm_length == 0 || frames_per_buffer < 16 || frames_per_buffer > 4096 ||
      buffer_count < 2 || buffer_count > PUDU_AUDIO_MAX_BUFFERS || timeout_ms < 1 ||
      cancel_token == NULL || completed_frames == NULL) {
    return PUDU_AUDIO_INVALID_ARGUMENT;
  }

  const uint32_t bytes_per_frame = (uint32_t)channels * 2u;
  if (pcm_length % bytes_per_frame != 0 ||
      (size_t)frames_per_buffer > UINT32_MAX / bytes_per_frame) {
    return PUDU_AUDIO_INVALID_ARGUMENT;
  }
  *completed_frames = 0;

  AudioStreamBasicDescription format = {0};
  format.mSampleRate = sample_rate;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
  format.mBytesPerPacket = bytes_per_frame;
  format.mFramesPerPacket = 1;
  format.mBytesPerFrame = bytes_per_frame;
  format.mChannelsPerFrame = (UInt32)channels;
  format.mBitsPerChannel = 16;

  pudu_audio_state state = {0};
  state.bytes_per_frame = bytes_per_frame;
  state.buffer_count = buffer_count;
  atomic_init(&state.completed_frames, 0);
  for (int32_t index = 0; index < buffer_count; ++index) {
    atomic_init(&state.available[index], true);
  }

  AudioQueueRef queue = NULL;
  if (AudioQueueNewOutput(&format, completed_buffer, &state, NULL, NULL, 0, &queue) != noErr) {
    return PUDU_AUDIO_QUEUE_CREATE_FAILED;
  }

  int32_t status = PUDU_AUDIO_OK;
  const UInt32 buffer_bytes = (UInt32)frames_per_buffer * bytes_per_frame;
  for (int32_t index = 0; index < buffer_count; ++index) {
    if (AudioQueueAllocateBuffer(queue, buffer_bytes, &state.buffers[index]) != noErr) {
      status = PUDU_AUDIO_BUFFER_ALLOCATE_FAILED;
      goto release;
    }
  }

  size_t submitted = 0;
  for (int32_t index = 0; index < buffer_count && submitted < pcm_length; ++index) {
    size_t count = pcm_length - submitted;
    if (count > buffer_bytes) {
      count = buffer_bytes;
    }
    atomic_store_explicit(&state.available[index], false, memory_order_relaxed);
    status = enqueue_chunk(queue, state.buffers[index], pcm + submitted, count);
    if (status != PUDU_AUDIO_OK) {
      goto release;
    }
    submitted += count;
  }

  if (AudioQueueStart(queue, NULL) != noErr) {
    status = PUDU_AUDIO_START_FAILED;
    goto release;
  }

  const uint64_t started = monotonic_milliseconds();
  if (started == 0) {
    status = PUDU_AUDIO_DEADLINE_EXCEEDED;
    goto release;
  }
  const uint64_t deadline = started + (uint64_t)timeout_ms;
  const uint64_t total_frames = pcm_length / bytes_per_frame;
  // A buffer's callback means the queue consumed it, not that the device has
  // sounded it. Once every byte is submitted the queue is flushed and stopped
  // asynchronously, and success waits for the queue to report it stopped, so
  // the final buffers are heard rather than discarded by the immediate stop.
  bool draining = false;
  bool seen_running = false;
  for (;;) {
    // A cancelled play stops at once; the release below stops the queue
    // immediately, which discards the buffers not yet heard.
    if (cancel_requested(cancel_token)) {
      status = PUDU_AUDIO_CANCELLED;
      goto release;
    }
    if (!draining && submitted == pcm_length) {
      if (AudioQueueFlush(queue) != noErr || AudioQueueStop(queue, false) != noErr) {
        status = PUDU_AUDIO_DRAIN_FAILED;
        goto release;
      }
      draining = true;
    }
    UInt32 running = 0;
    UInt32 running_size = sizeof(running);
    if (AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &running, &running_size) !=
        noErr) {
      status = PUDU_AUDIO_DRAIN_FAILED;
      goto release;
    }
    if (running != 0) {
      seen_running = true;
    }
    const uint64_t completed =
        atomic_load_explicit(&state.completed_frames, memory_order_acquire);
    if (draining && running == 0 && (completed >= total_frames || seen_running)) {
      break;
    }
    for (int32_t index = 0; index < buffer_count && submitted < pcm_length; ++index) {
      if (!atomic_exchange_explicit(&state.available[index], false, memory_order_acq_rel)) {
        continue;
      }
      size_t count = pcm_length - submitted;
      if (count > buffer_bytes) {
        count = buffer_bytes;
      }
      status = enqueue_chunk(queue, state.buffers[index], pcm + submitted, count);
      if (status != PUDU_AUDIO_OK) {
        goto release;
      }
      submitted += count;
    }
    if (monotonic_milliseconds() >= deadline) {
      status = PUDU_AUDIO_DEADLINE_EXCEEDED;
      goto release;
    }
    wait_one_millisecond();
  }
  *completed_frames = atomic_load_explicit(&state.completed_frames, memory_order_acquire);

release:
  if (queue != NULL) {
    OSStatus stop_status = AudioQueueStop(queue, true);
    OSStatus dispose_status = AudioQueueDispose(queue, true);
    if (status == PUDU_AUDIO_OK && (stop_status != noErr || dispose_status != noErr)) {
      status = PUDU_AUDIO_RELEASE_FAILED;
    }
  }
  if (status != PUDU_AUDIO_OK) {
    *completed_frames = atomic_load_explicit(&state.completed_frames, memory_order_acquire);
  }
  return status;
}
