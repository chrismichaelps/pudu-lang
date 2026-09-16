#include "pudu_audio_stream.h"

#include <AudioToolbox/AudioToolbox.h>
#include <math.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define PUDU_AUDIO_STREAM_MAX_BUFFERS 8

_Static_assert(offsetof(pudu_audio_stream_snapshot, submitted_frames) == 0, "snapshot submitted offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, acquired_frames) == 8, "snapshot acquired offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, clock_frames) == 16, "snapshot clock offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, clock_nanoseconds) == 24, "snapshot nanos offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, underruns) == 32, "snapshot underrun offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, interruptions) == 40, "snapshot interruption offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, device_changes) == 48, "snapshot device offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, timeline_failures) == 56, "snapshot timeline failure offset");
_Static_assert(offsetof(pudu_audio_stream_snapshot, state) == 64, "snapshot state offset");
_Static_assert(sizeof(pudu_audio_stream_snapshot) == 72, "snapshot size");

struct pudu_audio_stream {
  AudioQueueRef queue;
  AudioQueueTimelineRef timeline;
  AudioQueueBufferRef buffers[PUDU_AUDIO_STREAM_MAX_BUFFERS];
  atomic_bool available[PUDU_AUDIO_STREAM_MAX_BUFFERS];
  atomic_bool ever_started;
  atomic_bool closing;
  atomic_uint_fast64_t submitted_frames;
  atomic_uint_fast64_t acquired_frames;
  atomic_uint_fast64_t underruns;
  atomic_uint_fast64_t interruptions;
  atomic_uint_fast64_t device_changes;
  atomic_uint_fast64_t timeline_failures;
  atomic_uint_fast64_t last_clock_frames;
  atomic_uint_fast64_t last_clock_nanoseconds;
  atomic_uint_fast64_t starvation_frontier;
  atomic_int state;
  uint32_t bytes_per_frame;
  uint32_t buffer_bytes;
  int32_t buffer_count;
  int32_t sample_rate;
  int32_t channels;
  bool running_listener;
  bool device_listener;
};

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

static bool deadline_reached(uint64_t deadline) {
  const uint64_t now = monotonic_milliseconds();
  return now == 0 || now >= deadline;
}

static void completed_buffer(
    void *context,
    AudioQueueRef queue,
    AudioQueueBufferRef buffer) {
  (void)queue;
  pudu_audio_stream *stream = context;
  atomic_fetch_add_explicit(
      &stream->acquired_frames,
      buffer->mAudioDataByteSize / stream->bytes_per_frame,
      memory_order_relaxed);
  for (int32_t index = 0; index < stream->buffer_count; ++index) {
    if (stream->buffers[index] == buffer) {
      atomic_store_explicit(&stream->available[index], true, memory_order_release);
      return;
    }
  }
}

static void queue_property_changed(
    void *context,
    AudioQueueRef queue,
    AudioQueuePropertyID property) {
  pudu_audio_stream *stream = context;
  if (property == kAudioQueueProperty_CurrentDevice) {
    atomic_fetch_add_explicit(&stream->device_changes, 1, memory_order_relaxed);
    return;
  }
  if (property != kAudioQueueProperty_IsRunning ||
      !atomic_load_explicit(&stream->ever_started, memory_order_acquire) ||
      atomic_load_explicit(&stream->closing, memory_order_acquire) ||
      atomic_load_explicit(&stream->state, memory_order_acquire) == PUDU_AUDIO_STREAM_PAUSED) {
    return;
  }
  UInt32 running = 0;
  UInt32 size = sizeof(running);
  if (AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &running, &size) != noErr ||
      running != 0) {
    return;
  }
  const uint64_t submitted =
      atomic_load_explicit(&stream->submitted_frames, memory_order_acquire);
  const uint64_t acquired =
      atomic_load_explicit(&stream->acquired_frames, memory_order_acquire);
  if (acquired >= submitted) {
    const uint64_t previous = atomic_exchange_explicit(
        &stream->starvation_frontier, submitted, memory_order_acq_rel);
    if (previous != submitted) {
      atomic_fetch_add_explicit(&stream->underruns, 1, memory_order_relaxed);
    }
    atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_STARVED, memory_order_release);
  } else {
    atomic_fetch_add_explicit(&stream->interruptions, 1, memory_order_relaxed);
    atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_INTERRUPTED, memory_order_release);
  }
}

static int32_t release_stream(pudu_audio_stream *stream, int32_t status) {
  if (stream->queue != NULL) {
    const OSStatus stopped = AudioQueueStop(stream->queue, true);
    if (stream->device_listener) {
      AudioQueueRemovePropertyListener(
          stream->queue, kAudioQueueProperty_CurrentDevice, queue_property_changed, stream);
    }
    if (stream->running_listener) {
      AudioQueueRemovePropertyListener(
          stream->queue, kAudioQueueProperty_IsRunning, queue_property_changed, stream);
    }
    if (stream->timeline != NULL) {
      AudioQueueDisposeTimeline(stream->queue, stream->timeline);
    }
    const OSStatus disposed = AudioQueueDispose(stream->queue, true);
    if (status == PUDU_AUDIO_STREAM_OK && (stopped != noErr || disposed != noErr)) {
      status = PUDU_AUDIO_STREAM_RELEASE_FAILED;
    }
  }
  free(stream);
  return status;
}

int32_t pudu_audio_stream_open(
    int32_t sample_rate,
    int32_t channels,
    int32_t frames_per_buffer,
    int32_t buffer_count,
    pudu_audio_stream **stream_out,
    int32_t *actual_sample_rate,
    int32_t *actual_channels) {
  if (sample_rate < 8000 || sample_rate > 384000 || channels < 1 || channels > 8 ||
      frames_per_buffer < 16 || frames_per_buffer > 4096 || buffer_count < 2 ||
      buffer_count > PUDU_AUDIO_STREAM_MAX_BUFFERS || stream_out == NULL ||
      actual_sample_rate == NULL || actual_channels == NULL) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  const uint32_t bytes_per_frame = (uint32_t)channels * 2u;
  if ((uint32_t)frames_per_buffer > UINT32_MAX / bytes_per_frame) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  *stream_out = NULL;
  pudu_audio_stream *stream = calloc(1, sizeof(*stream));
  if (stream == NULL) {
    return PUDU_AUDIO_STREAM_QUEUE_CREATE_FAILED;
  }
  stream->bytes_per_frame = bytes_per_frame;
  stream->buffer_bytes = (uint32_t)frames_per_buffer * bytes_per_frame;
  stream->buffer_count = buffer_count;
  stream->sample_rate = sample_rate;
  stream->channels = channels;
  atomic_init(&stream->ever_started, false);
  atomic_init(&stream->closing, false);
  atomic_init(&stream->submitted_frames, 0);
  atomic_init(&stream->acquired_frames, 0);
  atomic_init(&stream->underruns, 0);
  atomic_init(&stream->interruptions, 0);
  atomic_init(&stream->device_changes, 0);
  atomic_init(&stream->timeline_failures, 0);
  atomic_init(&stream->last_clock_frames, 0);
  atomic_init(&stream->last_clock_nanoseconds, 0);
  atomic_init(&stream->starvation_frontier, UINT64_MAX);
  atomic_init(&stream->state, PUDU_AUDIO_STREAM_READY);
  for (int32_t index = 0; index < buffer_count; ++index) {
    atomic_init(&stream->available[index], true);
  }

  AudioStreamBasicDescription format = {0};
  format.mSampleRate = sample_rate;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
  format.mBytesPerPacket = bytes_per_frame;
  format.mFramesPerPacket = 1;
  format.mBytesPerFrame = bytes_per_frame;
  format.mChannelsPerFrame = (UInt32)channels;
  format.mBitsPerChannel = 16;
  if (AudioQueueNewOutput(&format, completed_buffer, stream, NULL, NULL, 0, &stream->queue) !=
      noErr) {
    return release_stream(stream, PUDU_AUDIO_STREAM_QUEUE_CREATE_FAILED);
  }
  for (int32_t index = 0; index < buffer_count; ++index) {
    if (AudioQueueAllocateBuffer(
            stream->queue, stream->buffer_bytes, &stream->buffers[index]) != noErr) {
      return release_stream(stream, PUDU_AUDIO_STREAM_BUFFER_ALLOCATE_FAILED);
    }
  }
  if (AudioQueueCreateTimeline(stream->queue, &stream->timeline) != noErr) {
    return release_stream(stream, PUDU_AUDIO_STREAM_TIMELINE_FAILED);
  }
  if (AudioQueueAddPropertyListener(
          stream->queue, kAudioQueueProperty_IsRunning, queue_property_changed, stream) != noErr) {
    return release_stream(stream, PUDU_AUDIO_STREAM_CONTROL_FAILED);
  }
  stream->running_listener = true;
  if (AudioQueueAddPropertyListener(
          stream->queue, kAudioQueueProperty_CurrentDevice, queue_property_changed, stream) !=
      noErr) {
    return release_stream(stream, PUDU_AUDIO_STREAM_CONTROL_FAILED);
  }
  stream->device_listener = true;

  AudioStreamBasicDescription actual = {0};
  UInt32 actual_size = sizeof(actual);
  if (AudioQueueGetProperty(
          stream->queue, kAudioQueueProperty_StreamDescription, &actual, &actual_size) != noErr ||
      actual.mSampleRate < 1 || actual.mSampleRate > INT32_MAX ||
      actual.mChannelsPerFrame < 1 || actual.mChannelsPerFrame > INT32_MAX) {
    return release_stream(stream, PUDU_AUDIO_STREAM_CONTROL_FAILED);
  }
  stream->sample_rate = (int32_t)llround(actual.mSampleRate);
  stream->channels = (int32_t)actual.mChannelsPerFrame;
  *actual_sample_rate = stream->sample_rate;
  *actual_channels = stream->channels;
  *stream_out = stream;
  return PUDU_AUDIO_STREAM_OK;
}

int32_t pudu_audio_stream_write(
    pudu_audio_stream *stream,
    const uint8_t *pcm,
    size_t pcm_length,
    int32_t timeout_ms,
    uint64_t *accepted_frames) {
  if (stream == NULL || pcm == NULL || pcm_length == 0 || timeout_ms < 1 ||
      pcm_length % stream->bytes_per_frame != 0 || accepted_frames == NULL ||
      atomic_load_explicit(&stream->closing, memory_order_acquire)) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  *accepted_frames = 0;
  const uint64_t started = monotonic_milliseconds();
  if (started == 0 || UINT64_MAX - started < (uint64_t)timeout_ms) {
    return PUDU_AUDIO_STREAM_DEADLINE_EXCEEDED;
  }
  const uint64_t deadline = started + (uint64_t)timeout_ms;
  size_t submitted_bytes = 0;
  while (submitted_bytes < pcm_length) {
    bool progressed = false;
    for (int32_t index = 0; index < stream->buffer_count && submitted_bytes < pcm_length; ++index) {
      if (!atomic_exchange_explicit(&stream->available[index], false, memory_order_acq_rel)) {
        continue;
      }
      size_t count = pcm_length - submitted_bytes;
      if (count > stream->buffer_bytes) {
        count = stream->buffer_bytes;
      }
      memcpy(stream->buffers[index]->mAudioData, pcm + submitted_bytes, count);
      stream->buffers[index]->mAudioDataByteSize = (UInt32)count;
      if (AudioQueueEnqueueBuffer(stream->queue, stream->buffers[index], 0, NULL) != noErr) {
        atomic_store_explicit(&stream->available[index], true, memory_order_release);
        *accepted_frames = submitted_bytes / stream->bytes_per_frame;
        return PUDU_AUDIO_STREAM_ENQUEUE_FAILED;
      }
      const uint64_t frames = count / stream->bytes_per_frame;
      atomic_fetch_add_explicit(&stream->submitted_frames, frames, memory_order_release);
      submitted_bytes += count;
      progressed = true;
    }
    if (atomic_load_explicit(&stream->state, memory_order_acquire) != PUDU_AUDIO_STREAM_PAUSED) {
      UInt32 running = 0;
      UInt32 size = sizeof(running);
      if (AudioQueueGetProperty(
              stream->queue, kAudioQueueProperty_IsRunning, &running, &size) != noErr) {
        *accepted_frames = submitted_bytes / stream->bytes_per_frame;
        return PUDU_AUDIO_STREAM_CONTROL_FAILED;
      }
      if (running == 0 && submitted_bytes > 0) {
        if (!atomic_load_explicit(&stream->ever_started, memory_order_acquire) &&
            AudioQueuePrime(stream->queue, 0, NULL) != noErr) {
          *accepted_frames = submitted_bytes / stream->bytes_per_frame;
          return PUDU_AUDIO_STREAM_CONTROL_FAILED;
        }
        if (AudioQueueStart(stream->queue, NULL) != noErr) {
          *accepted_frames = submitted_bytes / stream->bytes_per_frame;
          return PUDU_AUDIO_STREAM_CONTROL_FAILED;
        }
        atomic_store_explicit(&stream->ever_started, true, memory_order_release);
        atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_RUNNING, memory_order_release);
      }
    }
    if (submitted_bytes < pcm_length) {
      if (deadline_reached(deadline)) {
        *accepted_frames = submitted_bytes / stream->bytes_per_frame;
        return PUDU_AUDIO_STREAM_DEADLINE_EXCEEDED;
      }
      if (!progressed) {
        wait_one_millisecond();
      }
    }
  }
  *accepted_frames = submitted_bytes / stream->bytes_per_frame;
  if (atomic_load_explicit(&stream->state, memory_order_acquire) != PUDU_AUDIO_STREAM_PAUSED) {
    atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_RUNNING, memory_order_release);
  }
  return PUDU_AUDIO_STREAM_OK;
}

int32_t pudu_audio_stream_pause(pudu_audio_stream *stream) {
  if (stream == NULL || atomic_load_explicit(&stream->closing, memory_order_acquire)) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  if (atomic_load_explicit(&stream->state, memory_order_acquire) == PUDU_AUDIO_STREAM_PAUSED) {
    return PUDU_AUDIO_STREAM_OK;
  }
  if (AudioQueuePause(stream->queue) != noErr) {
    return PUDU_AUDIO_STREAM_CONTROL_FAILED;
  }
  atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_PAUSED, memory_order_release);
  return PUDU_AUDIO_STREAM_OK;
}

int32_t pudu_audio_stream_resume(pudu_audio_stream *stream) {
  if (stream == NULL || atomic_load_explicit(&stream->closing, memory_order_acquire)) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  const uint64_t submitted =
      atomic_load_explicit(&stream->submitted_frames, memory_order_acquire);
  const uint64_t acquired =
      atomic_load_explicit(&stream->acquired_frames, memory_order_acquire);
  if (submitted > acquired) {
    if (AudioQueueStart(stream->queue, NULL) != noErr) {
      return PUDU_AUDIO_STREAM_CONTROL_FAILED;
    }
    atomic_store_explicit(&stream->ever_started, true, memory_order_release);
    atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_RUNNING, memory_order_release);
  } else {
    atomic_store_explicit(&stream->state, PUDU_AUDIO_STREAM_STARVED, memory_order_release);
  }
  return PUDU_AUDIO_STREAM_OK;
}

int32_t pudu_audio_stream_set_volume(pudu_audio_stream *stream, double volume) {
  if (stream == NULL || !isfinite(volume) || volume < 0.0 || volume > 1.0 ||
      atomic_load_explicit(&stream->closing, memory_order_acquire)) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  return AudioQueueSetParameter(
             stream->queue, kAudioQueueParam_Volume, (AudioQueueParameterValue)volume) == noErr
      ? PUDU_AUDIO_STREAM_OK
      : PUDU_AUDIO_STREAM_CONTROL_FAILED;
}

int32_t pudu_audio_stream_snapshot_read(
    pudu_audio_stream *stream,
    pudu_audio_stream_snapshot *snapshot) {
  if (stream == NULL || snapshot == NULL ||
      atomic_load_explicit(&stream->closing, memory_order_acquire)) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  memset(snapshot, 0, sizeof(*snapshot));
  snapshot->submitted_frames =
      atomic_load_explicit(&stream->submitted_frames, memory_order_acquire);
  snapshot->acquired_frames =
      atomic_load_explicit(&stream->acquired_frames, memory_order_acquire);
  snapshot->underruns = atomic_load_explicit(&stream->underruns, memory_order_acquire);
  snapshot->interruptions =
      atomic_load_explicit(&stream->interruptions, memory_order_acquire);
  snapshot->device_changes =
      atomic_load_explicit(&stream->device_changes, memory_order_acquire);
  snapshot->timeline_failures =
      atomic_load_explicit(&stream->timeline_failures, memory_order_acquire);
  snapshot->state = atomic_load_explicit(&stream->state, memory_order_acquire);
  snapshot->clock_frames =
      atomic_load_explicit(&stream->last_clock_frames, memory_order_acquire);
  snapshot->clock_nanoseconds =
      atomic_load_explicit(&stream->last_clock_nanoseconds, memory_order_acquire);

  if (atomic_load_explicit(&stream->ever_started, memory_order_acquire)) {
    AudioTimeStamp now = {0};
    Boolean discontinuity = false;
    if (AudioQueueGetCurrentTime(stream->queue, stream->timeline, &now, &discontinuity) != noErr) {
      atomic_fetch_add_explicit(&stream->timeline_failures, 1, memory_order_relaxed);
      snapshot->timeline_failures += 1;
    } else if ((now.mFlags & kAudioTimeStampSampleTimeValid) != 0 && now.mSampleTime > 0.0) {
      const long double frames = floorl((long double)now.mSampleTime);
      const uint64_t raw_clock_frames = frames >= (long double)UINT64_MAX
          ? UINT64_MAX
          : (uint64_t)frames;
      snapshot->clock_frames = raw_clock_frames > snapshot->submitted_frames
          ? snapshot->submitted_frames
          : raw_clock_frames;
      const long double nanos =
          (long double)snapshot->clock_frames * 1000000000.0L /
          (long double)stream->sample_rate;
      snapshot->clock_nanoseconds = nanos >= (long double)UINT64_MAX
          ? UINT64_MAX
          : (uint64_t)nanos;
      if (raw_clock_frames > snapshot->submitted_frames &&
          snapshot->acquired_frames >= snapshot->submitted_frames &&
          snapshot->submitted_frames > 0) {
        const uint64_t previous = atomic_exchange_explicit(
            &stream->starvation_frontier,
            snapshot->submitted_frames,
            memory_order_acq_rel);
        if (previous != snapshot->submitted_frames) {
          snapshot->underruns =
              atomic_fetch_add_explicit(&stream->underruns, 1, memory_order_relaxed) + 1;
        }
        snapshot->state = PUDU_AUDIO_STREAM_STARVED;
        atomic_store_explicit(
            &stream->state, PUDU_AUDIO_STREAM_STARVED, memory_order_release);
      }
      atomic_store_explicit(
          &stream->last_clock_frames, snapshot->clock_frames, memory_order_release);
      atomic_store_explicit(
          &stream->last_clock_nanoseconds, snapshot->clock_nanoseconds, memory_order_release);
    }
  }
  return PUDU_AUDIO_STREAM_OK;
}

int32_t pudu_audio_stream_close(
    pudu_audio_stream *stream,
    int32_t drain,
    int32_t timeout_ms) {
  if (stream == NULL || (drain != 0 && drain != 1) || timeout_ms < 1) {
    return PUDU_AUDIO_STREAM_INVALID_ARGUMENT;
  }
  atomic_store_explicit(&stream->closing, true, memory_order_release);
  int32_t status = PUDU_AUDIO_STREAM_OK;
  if (drain != 0) {
    const uint64_t started = monotonic_milliseconds();
    if (started == 0 || UINT64_MAX - started < (uint64_t)timeout_ms) {
      status = PUDU_AUDIO_STREAM_DEADLINE_EXCEEDED;
    } else {
      const uint64_t deadline = started + (uint64_t)timeout_ms;
      const uint64_t submitted =
          atomic_load_explicit(&stream->submitted_frames, memory_order_acquire);
      const uint64_t acquired =
          atomic_load_explicit(&stream->acquired_frames, memory_order_acquire);
      if (submitted > acquired &&
          atomic_load_explicit(&stream->state, memory_order_acquire) == PUDU_AUDIO_STREAM_PAUSED &&
          AudioQueueStart(stream->queue, NULL) != noErr) {
        status = PUDU_AUDIO_STREAM_CONTROL_FAILED;
      }
      if (status == PUDU_AUDIO_STREAM_OK &&
          (AudioQueueFlush(stream->queue) != noErr ||
           AudioQueueStop(stream->queue, false) != noErr)) {
        status = PUDU_AUDIO_STREAM_CONTROL_FAILED;
      }
      while (status == PUDU_AUDIO_STREAM_OK) {
        UInt32 running = 0;
        UInt32 size = sizeof(running);
        if (AudioQueueGetProperty(
                stream->queue, kAudioQueueProperty_IsRunning, &running, &size) != noErr) {
          status = PUDU_AUDIO_STREAM_CONTROL_FAILED;
          break;
        }
        if (running == 0) {
          break;
        }
        if (deadline_reached(deadline)) {
          status = PUDU_AUDIO_STREAM_DEADLINE_EXCEEDED;
          break;
        }
        wait_one_millisecond();
      }
    }
  }
  return release_stream(stream, status);
}
