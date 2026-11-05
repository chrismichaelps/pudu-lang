{-| @Pudu.Backend.Runtime.Integer.Wide.Operations — exact portable 128-bit result policies. -}
module Pudu.Backend.Runtime.Integer.Wide.Operations
  ( wideOperationRuntimeParts, wideOperationRuntimeDependencies ) where

import Data.Text (Text)

wideOperationRuntimeParts :: [(Text, [Text])]
wideOperationRuntimeParts =
  [ ("wide_add_math",
      [ "static inline pudu_wide_calculation pudu_wide_add_math(pudu_wide_int a, pudu_wide_int b) {"
      , "  pudu_word128 am = pudu_wide_magnitude(a), bm = pudu_wide_magnitude(b);"
      , "  if (a.negative == b.negative) {"
      , "    pudu_word128_sum sum = pudu_word128_add(am, bm);"
      , "    return (pudu_wide_calculation){pudu_wide_make(sum.value, a.negative), sum.carry};"
      , "  }"
      , "  if (pudu_word128_compare(am, bm) >= 0) return (pudu_wide_calculation){pudu_wide_make(pudu_word128_sub(am, bm), a.negative), 0};"
      , "  return (pudu_wide_calculation){pudu_wide_make(pudu_word128_sub(bm, am), b.negative), 0};"
      , "}"
      ])
  , ("wide_multiply_math",
      [ "static inline pudu_wide_calculation pudu_wide_multiply_math(pudu_wide_int a, pudu_wide_int b) {"
      , "  pudu_word128_product product = pudu_word128_multiply(pudu_wide_magnitude(a), pudu_wide_magnitude(b));"
      , "  return (pudu_wide_calculation){pudu_wide_make(product.value, a.negative != b.negative), product.overflow};"
      , "}"
      ])
  , ("wide_checked_result",
      [ "static inline pudu_wide_int pudu_wide_checked_result(pudu_wide_calculation answer, pudu_wide_kind kind, const pudu_site *site) {"
      , "  pudu_word128 limit = pudu_wide_limit(kind, answer.value.negative);"
      , "  if (answer.overflow || pudu_word128_compare(pudu_wide_magnitude(answer.value), limit) > 0) pudu_fail(site);"
      , "  return pudu_wide_from_bits(answer.value.bits, kind);"
      , "}"
      ])
  , ("wide_saturate_result",
      [ "static inline pudu_wide_int pudu_wide_saturate_result(pudu_wide_calculation answer, pudu_wide_kind kind) {"
      , "  pudu_word128 limit = pudu_wide_limit(kind, answer.value.negative);"
      , "  if (answer.overflow || pudu_word128_compare(pudu_wide_magnitude(answer.value), limit) > 0)"
      , "    answer.value = pudu_wide_make(limit, answer.value.negative);"
      , "  return pudu_wide_from_bits(answer.value.bits, kind);"
      , "}"
      ])
  , ("wide_add",
      [ "static inline pudu_wide_int pudu_wide_add(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind, const pudu_site *site) {"
      , "  return pudu_wide_checked_result(pudu_wide_add_math(a, b), kind, site);"
      , "}"
      ])
  , ("wide_mul",
      [ "static inline pudu_wide_int pudu_wide_mul(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind, const pudu_site *site) {"
      , "  return pudu_wide_checked_result(pudu_wide_multiply_math(a, b), kind, site);"
      , "}"
      ])
  , ("wide_sub",
      [ "static inline pudu_wide_int pudu_wide_sub(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind, const pudu_site *site) {"
      , "  b.bits = pudu_word128_sub((pudu_word128){0, 0}, b.bits); b.negative = !b.negative;"
      , "  return pudu_wide_checked_result(pudu_wide_add_math(a, b), kind, site);"
      , "}"
      ])
  , ("wide_div",
      [ "static inline pudu_wide_int pudu_wide_div(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind, const pudu_site *zero, const pudu_site *overflow) {"
      , "  pudu_word128_division divided = pudu_word128_divide(pudu_wide_magnitude(a), pudu_wide_magnitude(b));"
      , "  if (divided.zero) pudu_fail(zero);"
      , "  pudu_wide_int value = pudu_wide_make(divided.quotient, a.negative != b.negative);"
      , "  return pudu_wide_checked_result((pudu_wide_calculation){value, 0}, kind, overflow);"
      , "}"
      ])
  , ("wide_rem",
      [ "static inline pudu_wide_int pudu_wide_rem(pudu_wide_int a, pudu_wide_int b, const pudu_site *zero) {"
      , "  pudu_word128_division divided = pudu_word128_divide(pudu_wide_magnitude(a), pudu_wide_magnitude(b));"
      , "  if (divided.zero) pudu_fail(zero);"
      , "  return pudu_wide_normal(pudu_wide_make(divided.remainder, a.negative));"
      , "}"
      ])
  , ("wide_neg",
      [ "static inline pudu_wide_int pudu_wide_neg(pudu_wide_int a, pudu_wide_kind kind, const pudu_site *site) {"
      , "  a.bits = pudu_word128_sub((pudu_word128){0, 0}, a.bits); a.negative = !a.negative;"
      , "  return pudu_wide_checked_result((pudu_wide_calculation){a, 0}, kind, site);"
      , "}"
      ])
  , ("wide_sat_add",
      [ "static inline pudu_wide_int pudu_wide_sat_add(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_saturate_result(pudu_wide_add_math(a, b), kind);"
      , "}"
      ])
  , ("wide_sat_mul",
      [ "static inline pudu_wide_int pudu_wide_sat_mul(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_saturate_result(pudu_wide_multiply_math(a, b), kind);"
      , "}"
      ])
  , ("wide_sat_sub",
      [ "static inline pudu_wide_int pudu_wide_sat_sub(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  b.bits = pudu_word128_sub((pudu_word128){0, 0}, b.bits); b.negative = !b.negative;"
      , "  return pudu_wide_saturate_result(pudu_wide_add_math(a, b), kind);"
      , "}"
      ])
  , ("wide_bit_and",
      [ "static inline pudu_wide_int pudu_wide_bit_and(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits((pudu_word128){a.bits.low & b.bits.low, a.bits.high & b.bits.high}, kind);"
      , "}"
      ])
  , ("wide_bit_or",
      [ "static inline pudu_wide_int pudu_wide_bit_or(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits((pudu_word128){a.bits.low | b.bits.low, a.bits.high | b.bits.high}, kind);"
      , "}"
      ])
  , ("wide_bit_xor",
      [ "static inline pudu_wide_int pudu_wide_bit_xor(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits((pudu_word128){a.bits.low ^ b.bits.low, a.bits.high ^ b.bits.high}, kind);"
      , "}"
      ])
  , ("wide_wrap_add",
      [ "static inline pudu_wide_int pudu_wide_wrap_add(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits(pudu_word128_add(a.bits, b.bits).value, kind);"
      , "}"
      ])
  , ("wide_wrap_sub",
      [ "static inline pudu_wide_int pudu_wide_wrap_sub(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits(pudu_word128_sub(a.bits, b.bits), kind);"
      , "}"
      ])
  , ("wide_wrap_mul",
      [ "static inline pudu_wide_int pudu_wide_wrap_mul(pudu_wide_int a, pudu_wide_int b, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits(pudu_word128_multiply(a.bits, b.bits).value, kind);"
      , "}"
      ])
  , ("wide_bit_not",
      [ "static inline pudu_wide_int pudu_wide_bit_not(pudu_wide_int a, pudu_wide_kind kind) {"
      , "  return pudu_wide_from_bits((pudu_word128){~a.bits.low, ~a.bits.high}, kind);"
      , "}"
      ])
  , ("wide_shift_left",
      [ "static inline pudu_wide_int pudu_wide_shift_left(pudu_wide_int a, pudu_int count, pudu_wide_kind kind, const pudu_site *negative, const pudu_site *wide) {"
      , "  if (count.negative && count.bits != 0) pudu_fail(negative);"
      , "  if (count.bits >= 128) pudu_fail(wide);"
      , "  return pudu_wide_from_bits(pudu_word128_left(a.bits, (unsigned)count.bits), kind);"
      , "}"
      ])
  , ("wide_shift_right",
      [ "static inline pudu_wide_int pudu_wide_shift_right(pudu_wide_int a, pudu_int count, pudu_wide_kind kind, const pudu_site *negative, const pudu_site *wide) {"
      , "  if (count.negative && count.bits != 0) pudu_fail(negative);"
      , "  if (count.bits >= 128) pudu_fail(wide);"
      , "  unsigned places = (unsigned)count.bits;"
      , "  pudu_word128 word = pudu_word128_right(a.bits, places);"
      , "  if (kind.is_signed && a.negative && places != 0) {"
      , "    pudu_word128 fill = pudu_word128_left((pudu_word128){UINT64_MAX, UINT64_MAX}, 128 - places);"
      , "    word.low |= fill.low; word.high |= fill.high;"
      , "  }"
      , "  return pudu_wide_from_bits(word, kind);"
      , "}"
      ])
  ]

wideOperationRuntimeDependencies :: Text -> [Text]
wideOperationRuntimeDependencies name = maybe [] id (lookup name
  [ ("wide_add_math", ["wide_magnitude", "wide_make", "word128_add", "word128_compare", "word128_sub"])
  , ("wide_multiply_math", ["wide_magnitude", "wide_make", "word128_multiply"])
  , ("wide_checked_result", ["wide_limit", "wide_magnitude", "word128_compare", "wide_from_bits", "site", "fail"])
  , ("wide_saturate_result", ["wide_limit", "wide_magnitude", "word128_compare", "wide_make", "wide_from_bits"])
  , ("wide_add", ["wide_add_math", "wide_checked_result"])
  , ("wide_mul", ["wide_multiply_math", "wide_checked_result"])
  , ("wide_sub", ["word128_sub", "wide_add_math", "wide_checked_result"])
  , ("wide_div", ["word128_divide", "wide_magnitude", "wide_make", "wide_checked_result"])
  , ("wide_rem", ["word128_divide", "wide_magnitude", "wide_make", "wide_normal", "site", "fail"])
  , ("wide_neg", ["word128_sub", "wide_checked_result"])
  , ("wide_sat_add", ["wide_add_math", "wide_saturate_result"])
  , ("wide_sat_mul", ["wide_multiply_math", "wide_saturate_result"])
  , ("wide_sat_sub", ["word128_sub", "wide_add_math", "wide_saturate_result"])
  , ("wide_bit_and", ["wide_from_bits"])
  , ("wide_bit_or", ["wide_from_bits"])
  , ("wide_bit_xor", ["wide_from_bits"])
  , ("wide_wrap_add", ["word128_add", "wide_from_bits"])
  , ("wide_wrap_sub", ["word128_sub", "wide_from_bits"])
  , ("wide_wrap_mul", ["word128_multiply", "wide_from_bits"])
  , ("wide_bit_not", ["wide_from_bits"])
  , ("wide_shift_left", ["word128_left", "wide_from_bits", "integer_value", "site", "fail"])
  , ("wide_shift_right", ["word128_right", "word128_left", "wide_from_bits", "integer_value", "site", "fail"])
  ])
