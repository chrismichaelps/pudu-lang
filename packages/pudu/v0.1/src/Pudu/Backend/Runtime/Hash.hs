{-| @Pudu.Backend.Runtime.Hash — `hashOf` over text, bytes and integers, and
    the index an indexed store is addressed by: an Int's low word mixed with
    a seed the process draws once. -}
module Pudu.Backend.Runtime.Hash (hashRuntimeParts, hashRuntimeDependencies) where

import Data.Text (Text)

hashRuntimeParts :: [(Text, [Text])]
hashRuntimeParts =
  [ ("hash_step",
      [ "#define PUDU_HASH_BASIS UINT64_C(0xcbf29ce484222325)"
      , "static inline uint64_t pudu_hash_step(uint64_t held, unsigned char byte) {"
      , "  return (held ^ byte) * UINT64_C(0x100000001b3);"
      , "}"
      ])
  , ("hash_text",
      [ "static pudu_int pudu_hash_text(pudu_text text) {"
      , "  uint64_t held = PUDU_HASH_BASIS;"
      , "  for (size_t i = 0; i < text.length; ++i) held = pudu_hash_step(held, text.bytes[i]);"
      , "  return pudu_make(held, 0);"
      , "}"
      ])
  , ("hash_int",
      [ "/* The magnitude's bytes from its highest non-zero one, then the sign. */"
      , "static pudu_int pudu_hash_words(uint64_t high, uint64_t low, int negative) {"
      , "  uint64_t held = PUDU_HASH_BASIS;"
      , "  int started = 0;"
      , "  for (int shift = 120; shift >= 0; shift -= 8) {"
      , "    unsigned char byte = (unsigned char)(shift >= 64 ? high >> (shift - 64) : low >> shift);"
      , "    if (!started && byte == 0 && shift != 0) continue;"
      , "    started = 1;"
      , "    held = pudu_hash_step(held, byte);"
      , "  }"
      , "  return pudu_make(pudu_hash_step(held, negative ? 1 : 0), 0);"
      , "}"
      , "static inline pudu_int pudu_hash_int(pudu_int value) {"
      , "  uint64_t magnitude = pudu_magnitude(value);"
      , "  return pudu_hash_words(0, magnitude, value.negative && magnitude != 0);"
      , "}"
      ])
  , ("hash_wide",
      [ "static inline pudu_int pudu_hash_wide(pudu_wide_int value) {"
      , "  pudu_word128 magnitude = pudu_wide_magnitude(value);"
      , "  return pudu_hash_words(magnitude.high, magnitude.low, value.negative && (magnitude.high | magnitude.low) != 0);"
      , "}"
      ])
  , ("hash_big",
      [ "static pudu_int pudu_hash_big(const pudu_big *value) {"
      , "  uint64_t held = PUDU_HASH_BASIS;"
      , "  int started = 0;"
      , "  if (value != NULL)"
      , "    for (size_t limb = value->length; limb-- > 0;)"
      , "      for (int shift = 24; shift >= 0; shift -= 8) {"
      , "        unsigned char byte = (unsigned char)(value->limbs[limb] >> shift);"
      , "        if (!started && byte == 0) continue;"
      , "        started = 1;"
      , "        held = pudu_hash_step(held, byte);"
      , "      }"
      , "  if (!started) held = pudu_hash_step(held, 0);"
      , "  return pudu_make(pudu_hash_step(held, value != NULL && value->negative ? 1 : 0), 0);"
      , "}"
      ])
  , ("mix_hash",
      [ "#if !defined(_WIN32)"
      , "#include <fcntl.h>"
      , "#endif"
      , "/* Eight bytes from the system's random source, read once; a fixed word"
      , "   where that cannot answer. */"
      , "static uint64_t pudu_mix_seed(void) {"
      , "  static uint64_t seed = UINT64_C(0x9e3779b97f4a7c15);"
      , "  static int ready = 0;"
      , "  if (ready) return seed;"
      , "  ready = 1;"
      , "#if !defined(_WIN32)"
      , "  {"
      , "    unsigned char drawn[8];"
      , "    size_t count = 0;"
      , "    int source = open(\"/dev/urandom\", O_RDONLY);"
      , "    if (source < 0) return seed;"
      , "    while (count < sizeof drawn) {"
      , "      ssize_t got = read(source, drawn + count, sizeof drawn - count);"
      , "      if (got <= 0) break;"
      , "      count += (size_t)got;"
      , "    }"
      , "    close(source);"
      , "    if (count == sizeof drawn) {"
      , "      uint64_t packed = 0;"
      , "      for (size_t i = 0; i < sizeof drawn; ++i) packed = (packed << 8) + drawn[i];"
      , "      seed = packed;"
      , "    }"
      , "  }"
      , "#endif"
      , "  return seed;"
      , "}"
      , "/* Every input bit reaches every output bit; the word is the Int itself. */"
      , "static inline pudu_int pudu_mix_hash(pudu_int value) {"
      , "  uint64_t start = value.bits ^ pudu_mix_seed();"
      , "  uint64_t first = (start ^ (start >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);"
      , "  uint64_t second = (first ^ (first >> 27)) * UINT64_C(0x94d049bb133111eb);"
      , "  return pudu_make(second ^ (second >> 31), 0);"
      , "}"
      ])
  ]

hashRuntimeDependencies :: Text -> [Text]
hashRuntimeDependencies name = maybe [] id (lookup name
  [ ("hash_text", ["hash_step", "text", "make"])
  , ("hash_int", ["hash_step", "magnitude", "make"])
  , ("hash_wide", ["hash_int", "wide_magnitude"])
  , ("hash_big", ["hash_step", "big_value", "make"])
  , ("mix_hash", ["make"])
  ])
