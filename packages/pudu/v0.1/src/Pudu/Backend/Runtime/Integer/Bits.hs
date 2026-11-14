{-| @Pudu.Backend.Runtime.Integer.Bits — exact C11 integer bits operations. -}
module Pudu.Backend.Runtime.Integer.Bits (bitRuntimeParts) where

import Data.Text (Text)

bitRuntimeParts :: [(Text, [Text])]
bitRuntimeParts =
  [ ("bit_and",
      [ "static inline pudu_int pudu_bit_and(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_from_bits(pudu_bits(a) & pudu_bits(b), kind);"
      , "}"
      ])
  , ("bit_or",
      [ "static inline pudu_int pudu_bit_or(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_from_bits(pudu_bits(a) | pudu_bits(b), kind);"
      , "}"
      ])
  , ("bit_xor",
      [ "static inline pudu_int pudu_bit_xor(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_from_bits(pudu_bits(a) ^ pudu_bits(b), kind);"
      , "}"
      ])
  , ("wrap_add",
      [ "static inline pudu_int pudu_wrap_add(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_from_bits(pudu_bits(a) + pudu_bits(b), kind);"
      , "}"
      ])
  , ("wrap_sub",
      [ "static inline pudu_int pudu_wrap_sub(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_from_bits(pudu_bits(a) - pudu_bits(b), kind);"
      , "}"
      ])
  , ("wrap_mul",
      [ "static inline pudu_int pudu_wrap_mul(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_from_bits(pudu_bits(a) * pudu_bits(b), kind);"
      , "}"
      ])
  , ("bit_not",
      [ "static inline pudu_int pudu_bit_not(pudu_int a, pudu_int_kind kind) {"
      , "  return pudu_from_bits(~pudu_bits(a), kind);"
      , "}"
      ])
  , ("shift_left",
      [ "static inline pudu_int pudu_shift_left(pudu_int a, pudu_int count, pudu_int_kind kind, const pudu_site *negative, const pudu_site *wide) {"
      , "  if (count.negative && count.bits != 0) pudu_fail(negative);"
      , "  if (count.bits >= kind.width) pudu_fail(wide);"
      , "  return pudu_from_bits(pudu_bits(a) << (unsigned)count.bits, kind);"
      , "}"
      ])
  , ("shift_right",
      [ "static inline pudu_int pudu_shift_right(pudu_int a, pudu_int count, pudu_int_kind kind, const pudu_site *negative, const pudu_site *wide) {"
      , "  uint64_t word;"
      , "  unsigned places;"
      , "  if (count.negative && count.bits != 0) pudu_fail(negative);"
      , "  if (count.bits >= kind.width) pudu_fail(wide);"
      , "  places = (unsigned)count.bits;"
      , "  word = pudu_bits(a);"
      , "  if (!kind.is_signed) word &= pudu_mask(kind);"
      , "  word >>= places;"
      , "  if (kind.is_signed && a.negative && places != 0) word |= UINT64_MAX << (64 - places);"
      , "  return pudu_from_bits(word, kind);"
      , "}"
      ])
  ]
