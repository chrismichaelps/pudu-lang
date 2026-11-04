{-| @Pudu.Backend.Runtime.Float — selected floating arithmetic and exact output. -}
module Pudu.Backend.Runtime.Float (floatRuntimeParts, floatRuntimeDependencies) where

import Data.Text (Text)
import Pudu.Backend.Runtime.Float.Format (floatFormatRuntimeParts, floatFormatRuntimeDependencies)
import Pudu.Backend.Runtime.Float.Value (floatValueRuntimeParts, floatValueRuntimeDependencies)

floatRuntimeParts :: [(Text, [Text])]
floatRuntimeParts = floatValueRuntimeParts <> floatFormatRuntimeParts <>
  [ ("print_float",
      [ "static inline void pudu_print_float(uint64_t bits) {"
      , "  char buffer[32];"
      , "  size_t count = pudu_format_float64(bits, buffer);"
      , "  buffer[count++] = '\\n';"
      , "  (void)fwrite(buffer, 1, count, stdout);"
      , "  (void)fflush(stdout);"
      , "}"
      ])
  ]

floatRuntimeDependencies :: Text -> [Text]
floatRuntimeDependencies name = floatValueRuntimeDependencies name
  <> floatFormatRuntimeDependencies name <> ["float_format" | name == "print_float"]
