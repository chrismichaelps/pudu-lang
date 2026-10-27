{-| @Pudu.Backend.Runtime.Integer — defined C11 platform-Int bit and range operations. -}
module Pudu.Backend.Runtime.Integer (integerRuntimeParts) where

import Data.Text (Text)

{-| Dependencies precede their consumers; emission selects only reachable helpers. -}
integerRuntimeParts :: [(Text, [Text])]
integerRuntimeParts =
  [ ("from_bits",
      [ "static inline int64_t pudu_from_bits(uint64_t bits) {"
      , "  if (bits <= (uint64_t)INT64_MAX) return (int64_t)bits;"
      , "  return -1 - (int64_t)(~bits);"
      , "}"
      ])
  , ("bit_and",
      [ "static inline int64_t pudu_bit_and(int64_t a, int64_t b) {"
      , "  return pudu_from_bits((uint64_t)a & (uint64_t)b);"
      , "}"
      ])
  , ("bit_or",
      [ "static inline int64_t pudu_bit_or(int64_t a, int64_t b) {"
      , "  return pudu_from_bits((uint64_t)a | (uint64_t)b);"
      , "}"
      ])
  , ("bit_xor",
      [ "static inline int64_t pudu_bit_xor(int64_t a, int64_t b) {"
      , "  return pudu_from_bits((uint64_t)a ^ (uint64_t)b);"
      , "}"
      ])
  , ("bit_not",
      [ "static inline int64_t pudu_bit_not(int64_t a) {"
      , "  return pudu_from_bits(~(uint64_t)a);"
      , "}"
      ])
  , ("shift_left",
      [ "static inline int64_t pudu_shift_left(int64_t a, int64_t count, const pudu_site *negative, const pudu_site *wide) {"
      , "  if (count < 0) pudu_fail(negative);"
      , "  if (count >= 64) pudu_fail(wide);"
      , "  return pudu_from_bits((uint64_t)a << count);"
      , "}"
      ])
  , ("shift_right",
      [ "static inline int64_t pudu_shift_right(int64_t a, int64_t count, const pudu_site *negative, const pudu_site *wide) {"
      , "  uint64_t bits;"
      , "  if (count < 0) pudu_fail(negative);"
      , "  if (count >= 64) pudu_fail(wide);"
      , "  if (count == 0) return a;"
      , "  bits = (uint64_t)a >> count;"
      , "  if (a < 0) bits |= UINT64_MAX << (64 - count);"
      , "  return pudu_from_bits(bits);"
      , "}"
      ])
  , ("wrap_add",
      [ "static inline int64_t pudu_wrap_add(int64_t a, int64_t b) {"
      , "  return pudu_from_bits((uint64_t)a + (uint64_t)b);"
      , "}"
      ])
  , ("wrap_sub",
      [ "static inline int64_t pudu_wrap_sub(int64_t a, int64_t b) {"
      , "  return pudu_from_bits((uint64_t)a - (uint64_t)b);"
      , "}"
      ])
  , ("wrap_mul",
      [ "static inline int64_t pudu_wrap_mul(int64_t a, int64_t b) {"
      , "  return pudu_from_bits((uint64_t)a * (uint64_t)b);"
      , "}"
      ])
  , ("sat_add",
      [ "static inline int64_t pudu_sat_add(int64_t a, int64_t b) {"
      , "  if (b > 0 && a > INT64_MAX - b) return INT64_MAX;"
      , "  if (b < 0 && a < INT64_MIN - b) return INT64_MIN;"
      , "  return a + b;"
      , "}"
      ])
  , ("sat_sub",
      [ "static inline int64_t pudu_sat_sub(int64_t a, int64_t b) {"
      , "  if (b < 0 && a > INT64_MAX + b) return INT64_MAX;"
      , "  if (b > 0 && a < INT64_MIN + b) return INT64_MIN;"
      , "  return a - b;"
      , "}"
      ])
  , ("sat_mul",
      [ "static inline int64_t pudu_sat_mul(int64_t a, int64_t b) {"
      , "  if (a == 0 || b == 0) return 0;"
      , "  if ((a == -1 && b == INT64_MIN) || (b == -1 && a == INT64_MIN)) return INT64_MAX;"
      , "  if (a > 0) {"
      , "    if (b > 0) { if (a > INT64_MAX / b) return INT64_MAX; }"
      , "    else { if (b < INT64_MIN / a) return INT64_MIN; }"
      , "  } else {"
      , "    if (b > 0) { if (a < INT64_MIN / b) return INT64_MIN; }"
      , "    else { if (a < INT64_MAX / b) return INT64_MAX; }"
      , "  }"
      , "  return a * b;"
      , "}"
      ])
  ]
