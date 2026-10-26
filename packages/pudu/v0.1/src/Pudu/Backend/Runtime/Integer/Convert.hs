{-| @Pudu.Backend.Runtime.Integer.Convert — `convertInteger`: does a value fit
    another integer kind, and the same value in that kind's form once it does. -}
module Pudu.Backend.Runtime.Integer.Convert
  ( integerConversionRuntimeParts, integerConversionRuntimeDependencies ) where

import Data.Text (Text)

integerConversionRuntimeParts :: [(Text, [Text])]
integerConversionRuntimeParts =
  [ ("int_fits",
      [ "static inline int pudu_int_fits(pudu_int value, pudu_int_kind kind) {"
      , "  value = pudu_normal(value);"
      , "  return value.negative ? pudu_magnitude(value) <= kind.negative_max : value.bits <= kind.positive_max;"
      , "}"
      ])
  , ("int_fits_wide",
      [ "/* Every narrow value fits Int128; UInt128 only takes the non-negative ones. */"
      , "static inline int pudu_int_fits_wide(pudu_int value, pudu_wide_kind kind) {"
      , "  return kind.is_signed || !pudu_normal(value).negative;"
      , "}"
      ])
  , ("wide_fits_int",
      [ "static inline int pudu_wide_fits_int(pudu_wide_int value, pudu_int_kind kind) {"
      , "  pudu_word128 magnitude;"
      , "  value = pudu_wide_normal(value);"
      , "  magnitude = pudu_wide_magnitude(value);"
      , "  if (magnitude.high != 0) return 0;"
      , "  return magnitude.low <= (value.negative ? kind.negative_max : kind.positive_max);"
      , "}"
      ])
  , ("wide_fits",
      [ "static inline int pudu_wide_fits(pudu_wide_int value, pudu_wide_kind kind) {"
      , "  value = pudu_wide_normal(value);"
      , "  return pudu_word128_compare(pudu_wide_magnitude(value), pudu_wide_limit(kind, value.negative)) <= 0;"
      , "}"
      ])
  , ("int_to_wide",
      [ "static inline pudu_wide_int pudu_int_to_wide(pudu_int value) {"
      , "  value = pudu_normal(value);"
      , "  return (pudu_wide_int){{value.bits, value.negative ? UINT64_MAX : 0}, value.negative};"
      , "}"
      ])
  , ("wide_to_int",
      [ "/* Only called on a value wide_fits_int accepted. */"
      , "static inline pudu_int pudu_wide_to_int(pudu_wide_int value) {"
      , "  value = pudu_wide_normal(value);"
      , "  return pudu_make(pudu_wide_magnitude(value).low, value.negative);"
      , "}"
      ])
  ]

integerConversionRuntimeDependencies :: Text -> [Text]
integerConversionRuntimeDependencies name = maybe [] id (lookup name
  [ ("int_fits", ["normal", "magnitude"])
  , ("int_fits_wide", ["normal", "wide_value"])
  , ("wide_fits_int", ["wide_normal", "wide_magnitude"])
  , ("wide_fits", ["wide_normal", "wide_magnitude", "wide_limit", "word128_compare"])
  , ("int_to_wide", ["normal", "wide_value"])
  , ("wide_to_int", ["wide_normal", "wide_magnitude", "make"])
  ])
