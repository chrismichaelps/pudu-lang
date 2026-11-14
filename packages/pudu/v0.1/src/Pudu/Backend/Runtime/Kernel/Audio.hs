{-| @Backend.Runtime.Kernel.Audio — the tone and ramp byte generators, as
    `Pudu.Eval.AudioKernel` answers them. -}
module Pudu.Backend.Runtime.Kernel.Audio (audioKernelParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
audioKernelParts :: [(Text, [Text], [Text])]
audioKernelParts =
  [ ("audio_sample", [],
      [ "/* A sample as two little-endian bytes of its 16-bit pattern. */"
      , "static inline void pudu_audio_sample(unsigned char *at, int64_t sample) {"
      , "  uint64_t word = (uint64_t)sample & 0xFFFF;"
      , "  at[0] = (unsigned char)word;"
      , "  at[1] = (unsigned char)(word >> 8);"
      , "}"
      ])
  , ("audio_scale", [],
      [ "/* The whole part of small * value / divisor, for small below 2^18 and value"
      , "   below divisor, without forming the product. */"
      , "static uint64_t pudu_audio_scale(uint64_t small, uint64_t value, uint64_t divisor) {"
      , "  uint64_t whole = 0, rest = 0;"
      , "  for (int bit = 17; bit >= 0; --bit) {"
      , "    whole *= 2;"
      , "    rest *= 2;"
      , "    if (rest >= divisor) { rest -= divisor; whole += 1; }"
      , "    if (((small >> bit) & 1) != 0) rest += value;"
      , "    if (rest >= divisor) { rest -= divisor; whole += 1; }"
      , "  }"
      , "  return whole;"
      , "}"
      ])
  , ("audio_tone_fits", [],
      [ "static int pudu_audio_tone_fits(pudu_int wave, pudu_int period, pudu_int amplitude, pudu_int channels, pudu_int start, pudu_int frames) {"
      , "  return !wave.negative && wave.bits <= 2 && !period.negative && period.bits >= 2"
      , "    && !amplitude.negative && amplitude.bits <= 32767 && !channels.negative && channels.bits >= 1 && channels.bits <= 8"
      , "    && !start.negative && !frames.negative && frames.bits <= 4096;"
      , "}"
      ])
  , ("audio_tone", ["audio_sample", "audio_scale", "bytes_wrap", "text_allocate"],
      [ "/* Square (0), rising saw (1) or triangle (2) frames, each on every channel. */"
      , "static pudu_box *pudu_audio_tone(pudu_int wave, pudu_int period, pudu_int amplitude, pudu_int channels, pudu_int start, pudu_int frames) {"
      , "  unsigned char *out;"
      , "  pudu_text tone = pudu_text_allocate((size_t)(frames.bits * channels.bits * 2), &out);"
      , "  int64_t level = (int64_t)amplitude.bits;"
      , "  for (uint64_t frame = 0; frame < frames.bits; ++frame) {"
      , "    /* The start may pass the period, so the sum is reduced in two steps. */"
      , "    uint64_t phase = (start.bits % period.bits + frame % period.bits) % period.bits;"
      , "    int64_t sample;"
      , "    if (wave.bits == 0) sample = phase < (period.bits + 1) / 2 ? level : -level;"
      , "    else if (wave.bits == 1) sample = -level + (int64_t)pudu_audio_scale(2 * (uint64_t)level, phase, period.bits);"
      , "    else {"
      , "      uint64_t half = period.bits / 2;"
      , "      sample = phase < half ? -level + (int64_t)pudu_audio_scale(2 * (uint64_t)level, phase, half)"
      , "        : level - (int64_t)pudu_audio_scale(2 * (uint64_t)level, phase - half, period.bits - half);"
      , "    }"
      , "    for (uint64_t channel = 0; channel < channels.bits; ++channel, out += 2) pudu_audio_sample(out, sample);"
      , "  }"
      , "  return pudu_bytes_wrap(tone);"
      , "}"
      ])
  , ("audio_ramp_fits", [],
      [ "static int pudu_audio_ramp_fits(pudu_box *source, pudu_int channels, pudu_int start, pudu_int from_frame, pudu_int from_gain, pudu_int to_frame, pudu_int to_gain) {"
      , "  size_t length = source->fields[0].text.length;"
      , "  if (channels.negative || channels.bits < 1 || channels.bits > 8) return 0;"
      , "  if (start.negative || from_frame.negative || to_frame.negative || to_frame.bits <= from_frame.bits) return 0;"
      , "  if (from_gain.negative || from_gain.bits > 131072 || to_gain.negative || to_gain.bits > 131072) return 0;"
      , "  return length <= 4096 * (size_t)channels.bits * 2 && length % ((size_t)channels.bits * 2) == 0;"
      , "}"
      ])
  , ("audio_ramp", ["audio_sample", "audio_scale", "bytes_wrap", "text_allocate"],
      [ "/* Each 16-bit sample scaled by a gain that moves linearly between two"
      , "   frames, in fifteen fractional bits, rounded half away from zero and held"
      , "   inside 16 bits. */"
      , "static pudu_box *pudu_audio_ramp(pudu_box *source, pudu_int channels, pudu_int start, pudu_int from_frame, pudu_int from_gain, pudu_int to_frame, pudu_int to_gain) {"
      , "  pudu_text bytes = source->fields[0].text;"
      , "  unsigned char *out;"
      , "  pudu_text ramped = pudu_text_allocate(bytes.length, &out);"
      , "  for (size_t index = 0; index < bytes.length / 2; ++index) {"
      , "    uint64_t frame = start.bits + index / channels.bits;"
      , "    int64_t gain = (int64_t)from_gain.bits, sample = (int64_t)bytes.bytes[2 * index] + 256 * (int64_t)bytes.bytes[2 * index + 1], scaled;"
      , "    if (frame >= to_frame.bits) gain = (int64_t)to_gain.bits;"
      , "    else if (frame > from_frame.bits) {"
      , "      uint64_t span = to_frame.bits - from_frame.bits, passed = frame - from_frame.bits;"
      , "      if (to_gain.bits >= from_gain.bits) gain += (int64_t)pudu_audio_scale(to_gain.bits - from_gain.bits, passed, span);"
      , "      else gain -= (int64_t)pudu_audio_scale(from_gain.bits - to_gain.bits, passed, span);"
      , "    }"
      , "    if (sample >= 32768) sample -= 65536;"
      , "    scaled = sample * gain;"
      , "    scaled = scaled >= 0 ? (scaled + 16384) / 32768 : -((16384 - scaled) / 32768);"
      , "    pudu_audio_sample(out + 2 * index, scaled > 32767 ? 32767 : scaled < -32768 ? -32768 : scaled);"
      , "  }"
      , "  return pudu_bytes_wrap(ramped);"
      , "}"
      ])
  ]
