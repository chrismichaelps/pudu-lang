{-| @Pudu.Backend.Runtime.Integer.Wide.Display — full-width decimal output and status. -}
module Pudu.Backend.Runtime.Integer.Wide.Display
  ( wideDisplayRuntimeParts, wideDisplayRuntimeDependencies ) where

import Data.Text (Text)

wideDisplayRuntimeParts :: [(Text, [Text])]
wideDisplayRuntimeParts =
  [ ("wide_print_int",
      [ "static inline void pudu_wide_print_int(pudu_wide_int value) {"
      , "  char buffer[41], *end = buffer + sizeof buffer, *cursor = end;"
      , "  value = pudu_wide_normal(value);"
      , "  pudu_word128 magnitude = pudu_wide_magnitude(value);"
      , "  *--cursor = '\\n';"
      , "  do {"
      , "    pudu_word128_division digit = pudu_word128_divide(magnitude, (pudu_word128){10, 0});"
      , "    *--cursor = (char)('0' + digit.remainder.low);"
      , "    magnitude = digit.quotient;"
      , "  } while (!pudu_word128_zero(magnitude));"
      , "  if (value.negative) *--cursor = '-';"
      , "  fwrite(cursor, 1, (size_t)(end - cursor), stdout);"
      , "  fflush(stdout);"
      , "}"
      ])
  , ("wide_status",
      [ "static inline int pudu_wide_status(pudu_wide_int value) {"
      , "  if ((value.bits.low | value.bits.high) == 0) return 0;"
      , "  if (value.negative) return 1;"
      , "  if (value.bits.high != 0 || value.bits.low > 255) return 255;"
      , "  return (int)value.bits.low;"
      , "}"
      ])
  ]

wideDisplayRuntimeDependencies :: Text -> [Text]
wideDisplayRuntimeDependencies name = maybe [] id (lookup name
  [ ("wide_print_int", ["wide_normal", "wide_magnitude", "word128_divide", "word128_zero"])
  , ("wide_status", ["wide_value"])
  ])
