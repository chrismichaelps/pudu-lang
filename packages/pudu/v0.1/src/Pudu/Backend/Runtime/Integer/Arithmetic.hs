{-| @Pudu.Backend.Runtime.Integer.Arithmetic — exact C11 integer arithmetic operations. -}
module Pudu.Backend.Runtime.Integer.Arithmetic (arithmeticRuntimeParts) where

import Data.Text (Text)

arithmeticRuntimeParts :: [(Text, [Text])]
arithmeticRuntimeParts =
  [ ("add_math",
      [ "static inline pudu_calculation pudu_add_math(pudu_int a, pudu_int b) {"
      , "  uint64_t am = pudu_magnitude(a), bm = pudu_magnitude(b);"
      , "  if (a.negative == b.negative) {"
      , "    uint64_t magnitude = am + bm;"
      , "    return (pudu_calculation){pudu_make(magnitude, a.negative), magnitude < am};"
      , "  }"
      , "  if (am >= bm) return (pudu_calculation){pudu_make(am - bm, a.negative), 0};"
      , "  return (pudu_calculation){pudu_make(bm - am, b.negative), 0};"
      , "}"
      ])
  , ("multiply_math",
      [ "static inline pudu_calculation pudu_multiply_math(pudu_int a, pudu_int b) {"
      , "  uint64_t am = pudu_magnitude(a), bm = pudu_magnitude(b);"
      , "  return (pudu_calculation){pudu_make(am * bm, a.negative != b.negative),"
      , "    bm != 0 && am > UINT64_MAX / bm};"
      , "}"
      ])
  , ("checked_result",
      [ "static inline pudu_int pudu_checked_result(pudu_calculation answer, pudu_int_kind kind, const pudu_site *site) {"
      , "  uint64_t limit = answer.value.negative ? kind.negative_max : kind.positive_max;"
      , "  if (answer.overflow || pudu_magnitude(answer.value) > limit) pudu_fail(site);"
      , "  return pudu_from_bits(answer.value.bits, kind);"
      , "}"
      ])
  , ("saturate_result",
      [ "static inline pudu_int pudu_saturate_result(pudu_calculation answer, pudu_int_kind kind) {"
      , "  uint64_t limit = answer.value.negative ? kind.negative_max : kind.positive_max;"
      , "  if (answer.overflow || pudu_magnitude(answer.value) > limit) answer.value = pudu_make(limit, answer.value.negative);"
      , "  return pudu_from_bits(answer.value.bits, kind);"
      , "}"
      ])
  , ("add",
      [ "static inline pudu_int pudu_add(pudu_int a, pudu_int b, pudu_int_kind kind, const pudu_site *site) {"
      , "  if (kind.width == 64 && kind.is_signed && a.negative == (int)(a.bits >> 63) && b.negative == (int)(b.bits >> 63)) {"
      , "    uint64_t bits = a.bits + b.bits;"
      , "    if ((~(a.bits ^ b.bits) & (a.bits ^ bits)) >> 63) pudu_fail(site);"
      , "    return (pudu_int){bits, (int)(bits >> 63)};"
      , "  }"
      , "  return pudu_checked_result(pudu_add_math(a,b),kind,site);"
      , "}"
      ])
  , ("sub",
      [ "static inline pudu_int pudu_sub(pudu_int a, pudu_int b, pudu_int_kind kind, const pudu_site *site) {"
      , "  b.bits = UINT64_C(0) - b.bits;"
      , "  b.negative = !b.negative;"
      , "  return pudu_checked_result(pudu_add_math(a, b), kind, site);"
      , "}"
      ])
  , ("mul",
      [ "static inline pudu_int pudu_mul(pudu_int a, pudu_int b, pudu_int_kind kind, const pudu_site *site) {"
      , "  return pudu_checked_result(pudu_multiply_math(a, b), kind, site);"
      , "}"
      ])
  , ("div",
      [ "static inline pudu_int pudu_div(pudu_int a, pudu_int b, pudu_int_kind kind, const pudu_site *zero, const pudu_site *overflow) {"
      , "  uint64_t bm = pudu_magnitude(b);"
      , "  if (bm == 0) pudu_fail(zero);"
      , "  pudu_int value = pudu_make(pudu_magnitude(a) / bm, a.negative != b.negative);"
      , "  return pudu_checked_result((pudu_calculation){value,0},kind,overflow);"
      , "}"
      ])
  , ("rem",
      [ "static inline pudu_int pudu_rem(pudu_int a, pudu_int b, const pudu_site *zero) {"
      , "  uint64_t bm = pudu_magnitude(b);"
      , "  if (bm == 0) pudu_fail(zero);"
      , "  return pudu_normal(pudu_make(pudu_magnitude(a) % bm, a.negative));"
      , "}"
      ])
  , ("neg",
      [ "static inline pudu_int pudu_neg(pudu_int a, pudu_int_kind kind, const pudu_site *site) {"
      , "  a.bits = UINT64_C(0) - a.bits;"
      , "  a.negative = !a.negative;"
      , "  return pudu_checked_result((pudu_calculation){a, 0}, kind, site);"
      , "}"
      ])
  , ("sat_add",
      [ "static inline pudu_int pudu_sat_add(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_saturate_result(pudu_add_math(a, b), kind);"
      , "}"
      ])
  , ("sat_sub",
      [ "static inline pudu_int pudu_sat_sub(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  b.bits = UINT64_C(0) - b.bits;"
      , "  b.negative = !b.negative;"
      , "  return pudu_saturate_result(pudu_add_math(a, b), kind);"
      , "}"
      ])
  , ("sat_mul",
      [ "static inline pudu_int pudu_sat_mul(pudu_int a, pudu_int b, pudu_int_kind kind) {"
      , "  return pudu_saturate_result(pudu_multiply_math(a, b), kind);"
      , "}"
      ])
  ]
