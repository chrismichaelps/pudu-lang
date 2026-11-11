{-| @Backend.Runtime.Host.Math — the binary64 kernels, each the platform
    math library's own function as `Pudu.Runtime.FloatKernel` calls it. -}
module Pudu.Backend.Runtime.Host.Math (hostMathParts, hostMathFunctions) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| A kernel's part name after `host_math_`, the library function behind it,
    and how many floats it takes. -}
hostMathFunctions :: [(Text, Text, Int)]
hostMathFunctions =
  [ ("sqrt", "sqrt", 1), ("cbrt", "cbrt", 1), ("floor", "floor", 1), ("ceil", "ceil", 1), ("trunc", "trunc", 1)
  , ("round", "round", 1), ("sin", "sin", 1), ("cos", "cos", 1), ("tan", "tan", 1), ("asin", "asin", 1)
  , ("acos", "acos", 1), ("atan", "atan", 1), ("atan2", "atan2", 2), ("exp", "exp", 1), ("ln", "log", 1)
  , ("log2", "log2", 1), ("log10", "log10", 1), ("pow", "pow", 2), ("hypot", "hypot", 2), ("sinh", "sinh", 1)
  , ("cosh", "cosh", 1), ("tanh", "tanh", 1), ("fma", "fma", 3) ]

{-| Each part: its name, the parts it needs, and its lines. -}
hostMathParts :: [(Text, [Text], [Text])]
hostMathParts =
  ("host_math", [], ["#include <math.h>"])
  : [ ("host_math_" <> name, ["host_math", "float_decode", "float_encode"],
        [ "static inline uint64_t pudu_host_math_" <> name <> "(" <> Text.intercalate ", " ["uint64_t " <> operand | operand <- operands] <> ") {"
        , "  return pudu_float_encode(" <> function <> "(" <> Text.intercalate ", " ["pudu_float_decode(" <> operand <> ")" | operand <- operands] <> "));"
        , "}" ])
    | (name, function, count) <- hostMathFunctions, let operands = take count ["x", "y", "z"] ]
  <>
  [ ("host_math_to_bits", ["make"],
      [ "static inline pudu_int pudu_host_math_to_bits(uint64_t x) { return pudu_make(x, 0); }" ])
  , ("host_math_from_bits", [],
      [ "static inline uint64_t pudu_host_math_from_bits(pudu_int word) { return word.bits; }" ])
  , ("host_math_from_int", ["float_encode", "kernel_signed"],
      [ "static inline uint64_t pudu_host_math_from_int(pudu_int number) {"
      , "  return pudu_float_encode((double)pudu_kernel_signed(number.bits));"
      , "}" ])
  , ("host_math_whole", ["host_math", "float_decode"],
      [ "/* Whether the float, cut toward zero, is an Int. */"
      , "static inline int pudu_host_math_whole(uint64_t x) {"
      , "  double cut = trunc(pudu_float_decode(x));"
      , "  return cut >= -9223372036854775808.0 && cut < 9223372036854775808.0;"
      , "}" ])
  , ("host_math_to_int", ["host_math", "float_decode", "kernel_int"],
      [ "static inline pudu_int pudu_host_math_to_int(uint64_t x) {"
      , "  return pudu_kernel_int((int64_t)trunc(pudu_float_decode(x)));"
      , "}" ])
  ]
