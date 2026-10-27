{-| @Pudu.Backend.Runtime.Float.Value — bit-preserving IEEE arithmetic helpers. -}
module Pudu.Backend.Runtime.Float.Value
  ( floatValueRuntimeParts, floatValueRuntimeDependencies ) where

import Data.Text (Text)

floatValueRuntimeParts :: [(Text, [Text])]
floatValueRuntimeParts =
  [ ("float_target",
      [ "#if defined(__FAST_MATH__) || (defined(__FINITE_MATH_ONLY__) && __FINITE_MATH_ONLY__ != 0)"
      , "#error Pudu floating runtime requires precise IEEE arithmetic"
      , "#endif"
      , "_Static_assert(CHAR_BIT == 8 && sizeof(double) == 8 && sizeof(float) == 4, \"Pudu floating runtime requires binary32/binary64 storage\");"
      , "_Static_assert(FLT_RADIX == 2 && DBL_MANT_DIG == 53 && DBL_MIN_EXP == -1021 && DBL_MAX_EXP == 1024, \"Pudu floating runtime requires binary64 arithmetic\");"
      , "_Static_assert(FLT_MANT_DIG == 24 && FLT_MIN_EXP == -125 && FLT_MAX_EXP == 128 && FLT_EVAL_METHOD == 0, \"Pudu floating runtime requires binary32 and direct evaluation\");"
      ])
  , ("float_decode",
      [ "static inline double pudu_float_decode(uint64_t bits) {"
      , "  double value; memcpy(&value, &bits, sizeof value); return value;"
      , "}"
      ])
  , ("float_encode",
      [ "static inline uint64_t pudu_float_encode(double value) {"
      , "  uint64_t bits; memcpy(&bits, &value, sizeof bits); return bits;"
      , "}"
      ])
  , ("float_normalize",
      [ "static inline uint64_t pudu_float_normalize(double value, int narrow) {"
      , "  if (narrow) { volatile float rounded = (float)value; return pudu_float_encode((double)rounded); }"
      , "  return pudu_float_encode(value);"
      , "}"
      ])
  , ("float_neg",
      [ "static inline uint64_t pudu_float_neg(uint64_t value) { return value ^ (UINT64_C(1) << 63); }" ])
  ] <> map arithmetic arithmeticOperators <> map comparison comparisonOperators
 where
  arithmetic (name, operator) = (name,
    [ "static inline uint64_t pudu_" <> name <> "(uint64_t a, uint64_t b, int narrow) {"
    , "  /* Each Pudu operation rounds before the next operation starts. */"
    , "  volatile double left = pudu_float_decode(a);"
    , "  volatile double right = pudu_float_decode(b);"
    , "  if ((a & UINT64_C(0x7fffffffffffffff)) > UINT64_C(0x7ff0000000000000) || (b & UINT64_C(0x7fffffffffffffff)) > UINT64_C(0x7ff0000000000000)) {"
    , "    /* Subtraction keeps operand order when propagating NaNs. */"
    , "    volatile double result = left - right;"
    , "    return pudu_float_normalize(result, narrow);"
    , "  }"
    , "  volatile double result = left " <> operator <> " right;"
    , "  return pudu_float_normalize(result, narrow);"
    , "}"
    ])
  comparison (name, operator) = (name,
    [ "static inline int pudu_" <> name <> "(uint64_t a, uint64_t b) {"
    , "  return pudu_float_decode(a) " <> operator <> " pudu_float_decode(b);"
    , "}"
    ])

arithmeticOperators, comparisonOperators :: [(Text, Text)]
arithmeticOperators = [("float_add", "+"), ("float_sub", "-"), ("float_mul", "*"), ("float_div", "/")]
comparisonOperators = [("float_eq", "=="), ("float_ne", "!="), ("float_lt", "<"), ("float_le", "<="), ("float_gt", ">"), ("float_ge", ">=")]

floatValueRuntimeDependencies :: Text -> [Text]
floatValueRuntimeDependencies name
  | name `elem` map fst arithmeticOperators = ["float_decode", "float_normalize"]
  | name `elem` map fst comparisonOperators = ["float_decode"]
  | otherwise = maybe [] id (lookup name
      [ ("float_decode", ["float_target"]), ("float_encode", ["float_target"])
      , ("float_normalize", ["float_encode"])
      ])
