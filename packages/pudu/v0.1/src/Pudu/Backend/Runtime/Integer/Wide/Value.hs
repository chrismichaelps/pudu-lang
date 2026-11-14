{-| @Pudu.Backend.Runtime.Integer.Wide.Value — exact signs for two-word values. -}
module Pudu.Backend.Runtime.Integer.Wide.Value
  ( wideValueRuntimeParts, wideValueRuntimeDependencies ) where

import Data.Text (Text)

wideValueRuntimeParts :: [(Text, [Text])]
wideValueRuntimeParts =
  [ ("wide_value",
      [ "typedef struct { pudu_word128 bits; int negative; } pudu_wide_int;"
      , "typedef struct { int is_signed; } pudu_wide_kind;"
      , "typedef struct { pudu_wide_int value; int overflow; } pudu_wide_calculation;"
      ])
  , ("wide_magnitude",
      [ "static inline pudu_word128 pudu_wide_magnitude(pudu_wide_int value) {"
      , "  return value.negative ? pudu_word128_sub((pudu_word128){0, 0}, value.bits) : value.bits;"
      , "}"
      ])
  , ("wide_make",
      [ "static inline pudu_wide_int pudu_wide_make(pudu_word128 magnitude, int negative) {"
      , "  return (pudu_wide_int){negative ? pudu_word128_sub((pudu_word128){0, 0}, magnitude) : magnitude, negative != 0};"
      , "}"
      ])
  , ("wide_normal",
      [ "static inline pudu_wide_int pudu_wide_normal(pudu_wide_int value) {"
      , "  if (pudu_word128_zero(value.bits)) value.negative = 0;"
      , "  return value;"
      , "}"
      ])
  , ("wide_from_bits",
      [ "static inline pudu_wide_int pudu_wide_from_bits(pudu_word128 bits, pudu_wide_kind kind) {"
      , "  return (pudu_wide_int){bits, kind.is_signed && (bits.high >> 63) != 0};"
      , "}"
      ])
  , ("wide_compare",
      [ "static inline int pudu_wide_compare(pudu_wide_int a, pudu_wide_int b) {"
      , "  a = pudu_wide_normal(a); b = pudu_wide_normal(b);"
      , "  if (a.negative != b.negative) return a.negative ? -1 : 1;"
      , "  return pudu_word128_compare(a.bits, b.bits);"
      , "}"
      ])
  , ("wide_limit",
      [ "static inline pudu_word128 pudu_wide_limit(pudu_wide_kind kind, int negative) {"
      , "  if (negative) return (pudu_word128){0, kind.is_signed ? UINT64_C(1) << 63 : 0};"
      , "  return (pudu_word128){UINT64_MAX, kind.is_signed ? UINT64_MAX >> 1 : UINT64_MAX};"
      , "}"
      ])
  ]

wideValueRuntimeDependencies :: Text -> [Text]
wideValueRuntimeDependencies name = maybe [] id (lookup name
  [ ("wide_value", ["word128_value"])
  , ("wide_magnitude", ["wide_value", "word128_sub"])
  , ("wide_make", ["wide_value", "word128_sub"])
  , ("wide_normal", ["wide_value", "word128_zero"])
  , ("wide_from_bits", ["wide_value"])
  , ("wide_compare", ["wide_normal", "word128_compare"])
  , ("wide_limit", ["wide_value"])
  ])
