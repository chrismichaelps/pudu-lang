{-| @Pudu.Backend.Runtime.Integer.Value — exact C11 integer value operations. -}
module Pudu.Backend.Runtime.Integer.Value (valueRuntimeParts) where

import Data.Text (Text)

valueRuntimeParts :: [(Text, [Text])]
valueRuntimeParts =
  [ ("integer_value",
      [ "typedef struct { uint64_t bits; int negative; } pudu_int;"
      , "typedef struct {"
      , "  uint64_t positive_max;"
      , "  uint64_t negative_max;"
      , "  unsigned width;"
      , "  int is_signed;"
      , "} pudu_int_kind;"
      , "typedef struct { pudu_int value; int overflow; } pudu_calculation;"
      ])
  , ("magnitude",
      [ "static inline uint64_t pudu_magnitude(pudu_int value) {"
      , "  return value.negative ? UINT64_C(0) - value.bits : value.bits;"
      , "}"
      ])
  , ("make",
      [ "static inline pudu_int pudu_make(uint64_t magnitude, int negative) {"
      , "  return (pudu_int){negative ? UINT64_C(0) - magnitude : magnitude, negative};"
      , "}"
      ])
  , ("normal",
      [ "static inline pudu_int pudu_normal(pudu_int value) {"
      , "  if (value.bits == 0) value.negative = 0;"
      , "  return value;"
      , "}"
      ])
  , ("bits",
      [ "static inline uint64_t pudu_bits(pudu_int value) { return value.bits; }"
      ])
  , ("mask",
      [ "static inline uint64_t pudu_mask(pudu_int_kind kind) {"
      , "  return UINT64_MAX >> (64 - kind.width);"
      , "}"
      ])
  , ("from_bits",
      [ "static inline pudu_int pudu_from_bits(uint64_t bits, pudu_int_kind kind) {"
      , "  uint64_t mask = pudu_mask(kind);"
      , "  int negative;"
      , "  bits &= mask;"
      , "  negative = kind.is_signed && (bits & (UINT64_C(1) << (kind.width - 1))) != 0;"
      , "  if (negative) bits |= ~mask;"
      , "  return (pudu_int){bits, negative};"
      , "}"
      ])
  , ("compare",
      [ "static inline int pudu_compare(pudu_int a, pudu_int b) {"
      , "  if (a.negative != b.negative) return a.negative ? -1 : 1;"
      , "  return (a.bits > b.bits) - (a.bits < b.bits);"
      , "}"
      ])
  ]
