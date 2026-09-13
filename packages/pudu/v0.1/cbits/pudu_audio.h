#ifndef PUDU_AUDIO_H
#define PUDU_AUDIO_H

#include <stddef.h>
#include <stdint.h>

enum pudu_audio_status {
  PUDU_AUDIO_OK = 0,
  PUDU_AUDIO_INVALID_ARGUMENT = -1,
  PUDU_AUDIO_DEADLINE_EXCEEDED = -2,
  PUDU_AUDIO_QUEUE_CREATE_FAILED = -3,
  PUDU_AUDIO_BUFFER_ALLOCATE_FAILED = -4,
  PUDU_AUDIO_ENQUEUE_FAILED = -5,
  PUDU_AUDIO_START_FAILED = -6,
  PUDU_AUDIO_RELEASE_FAILED = -7,
  PUDU_AUDIO_DRAIN_FAILED = -8
};

int32_t pudu_audio_play(
    int32_t sample_rate,
    int32_t channels,
    const uint8_t *pcm,
    size_t pcm_length,
    int32_t frames_per_buffer,
    int32_t buffer_count,
    int32_t timeout_ms,
    uint64_t *completed_frames);

#endif
