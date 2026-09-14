#ifndef PUDU_AUDIO_STREAM_H
#define PUDU_AUDIO_STREAM_H

#include <stddef.h>
#include <stdint.h>

typedef struct pudu_audio_stream pudu_audio_stream;

enum pudu_audio_stream_status {
  PUDU_AUDIO_STREAM_OK = 0,
  PUDU_AUDIO_STREAM_INVALID_ARGUMENT = -1,
  PUDU_AUDIO_STREAM_DEADLINE_EXCEEDED = -2,
  PUDU_AUDIO_STREAM_QUEUE_CREATE_FAILED = -3,
  PUDU_AUDIO_STREAM_BUFFER_ALLOCATE_FAILED = -4,
  PUDU_AUDIO_STREAM_ENQUEUE_FAILED = -5,
  PUDU_AUDIO_STREAM_CONTROL_FAILED = -6,
  PUDU_AUDIO_STREAM_RELEASE_FAILED = -7,
  PUDU_AUDIO_STREAM_TIMELINE_FAILED = -8
};

enum pudu_audio_stream_state {
  PUDU_AUDIO_STREAM_READY = 0,
  PUDU_AUDIO_STREAM_RUNNING = 1,
  PUDU_AUDIO_STREAM_PAUSED = 2,
  PUDU_AUDIO_STREAM_STARVED = 3,
  PUDU_AUDIO_STREAM_INTERRUPTED = 4
};

typedef struct {
  uint64_t submitted_frames;
  uint64_t acquired_frames;
  uint64_t clock_frames;
  uint64_t clock_nanoseconds;
  uint64_t underruns;
  uint64_t interruptions;
  uint64_t device_changes;
  uint64_t timeline_failures;
  int32_t state;
} pudu_audio_stream_snapshot;

int32_t pudu_audio_stream_open(
    int32_t sample_rate,
    int32_t channels,
    int32_t frames_per_buffer,
    int32_t buffer_count,
    pudu_audio_stream **stream,
    int32_t *actual_sample_rate,
    int32_t *actual_channels);

int32_t pudu_audio_stream_write(
    pudu_audio_stream *stream,
    const uint8_t *pcm,
    size_t pcm_length,
    int32_t timeout_ms,
    uint64_t *accepted_frames);

int32_t pudu_audio_stream_pause(pudu_audio_stream *stream);
int32_t pudu_audio_stream_resume(pudu_audio_stream *stream);
int32_t pudu_audio_stream_set_volume(pudu_audio_stream *stream, double volume);
int32_t pudu_audio_stream_snapshot_read(
    pudu_audio_stream *stream,
    pudu_audio_stream_snapshot *snapshot);
int32_t pudu_audio_stream_close(
    pudu_audio_stream *stream,
    int32_t drain,
    int32_t timeout_ms);

#endif
