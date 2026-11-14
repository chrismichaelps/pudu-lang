{-| @Pudu.Backend.Runtime.Integer.Big.Operations — BigInt operators in the frame emitter's
    integer ABI, its exit status and display, and conversions to and
    from the fixed integer kinds. -}
module Pudu.Backend.Runtime.Integer.Big.Operations (bigOperationRuntimeParts, bigOperationRuntimeDependencies) where

import Data.Text (Text)

-- One part per function, so a program holds only what it calls.
bigOperationRuntimeParts :: [(Text, [Text])]
bigOperationRuntimeParts =
  [ ("big_add",
      [ "static inline pudu_big *pudu_big_add(const pudu_big *a, const pudu_big *b, int kind, const pudu_site *site) {"
      , "  (void)kind; (void)site;"
      , "  return pudu_bigint_add(a, b);"
      , "}"
      ])
  , ("big_sub",
      [ "static inline pudu_big *pudu_big_sub(const pudu_big *a, const pudu_big *b, int kind, const pudu_site *site) {"
      , "  (void)kind; (void)site;"
      , "  return pudu_bigint_sub(a, b);"
      , "}"
      ])
  , ("big_mul",
      [ "static inline pudu_big *pudu_big_mul(const pudu_big *a, const pudu_big *b, int kind, const pudu_site *site) {"
      , "  (void)kind; (void)site;"
      , "  return pudu_bigint_mul(a, b);"
      , "}"
      ])
  , ("big_wrap_add",
      [ "/* A BigInt has no interval to wrap into or clamp to: these are exact. */"
      , "static inline pudu_big *pudu_big_wrap_add(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_bigint_add(a, b); }"
      ])
  , ("big_wrap_sub",
      [ "static inline pudu_big *pudu_big_wrap_sub(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_bigint_sub(a, b); }"
      ])
  , ("big_wrap_mul",
      [ "static inline pudu_big *pudu_big_wrap_mul(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_bigint_mul(a, b); }"
      ])
  , ("big_sat_add",
      [ "static inline pudu_big *pudu_big_sat_add(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_bigint_add(a, b); }"
      ])
  , ("big_sat_sub",
      [ "static inline pudu_big *pudu_big_sat_sub(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_bigint_sub(a, b); }"
      ])
  , ("big_sat_mul",
      [ "static inline pudu_big *pudu_big_sat_mul(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_bigint_mul(a, b); }"
      ])
  , ("big_neg",
      [ "static inline pudu_big *pudu_big_neg(const pudu_big *a, int kind, const pudu_site *site) {"
      , "  (void)kind; (void)site;"
      , "  return pudu_bigint_neg(a);"
      , "}"
      ])
  , ("big_div",
      [ "static inline pudu_big *pudu_big_div(const pudu_big *a, const pudu_big *b, int kind, const pudu_site *zero, const pudu_site *overflow) {"
      , "  pudu_big *quotient, *remainder;"
      , "  (void)kind; (void)overflow;"
      , "  if (b == NULL) pudu_fail(zero);"
      , "  pudu_big_divide(a, b, &quotient, &remainder);"
      , "  pudu_big_release(remainder);"
      , "  return quotient;"
      , "}"
      ])
  , ("big_rem",
      [ "static inline pudu_big *pudu_big_rem(const pudu_big *a, const pudu_big *b, const pudu_site *zero) {"
      , "  pudu_big *quotient, *remainder;"
      , "  if (b == NULL) pudu_fail(zero);"
      , "  pudu_big_divide(a, b, &quotient, &remainder);"
      , "  pudu_big_release(quotient);"
      , "  return remainder;"
      , "}"
      ])
  , ("big_bit_and",
      [ "static inline pudu_big *pudu_big_bit_and(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_big_bits(a, b, 0); }"
      ])
  , ("big_bit_or",
      [ "static inline pudu_big *pudu_big_bit_or(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_big_bits(a, b, 1); }"
      ])
  , ("big_bit_xor",
      [ "static inline pudu_big *pudu_big_bit_xor(const pudu_big *a, const pudu_big *b, int kind) { (void)kind; return pudu_big_bits(a, b, 2); }"
      ])
  , ("big_bit_not",
      [ "static inline pudu_big *pudu_big_bit_not(const pudu_big *a, int kind) { (void)kind; return pudu_bigint_not(a); }"
      ])
  , ("big_shift_left",
      [ "static inline pudu_big *pudu_big_shift_left(const pudu_big *a, pudu_int count, int kind, const pudu_site *negative, const pudu_site *wide) {"
      , "  (void)kind; (void)wide;"
      , "  count = pudu_normal(count);"
      , "  if (count.negative) pudu_fail(negative);"
      , "  return pudu_bigint_shift_left(a, pudu_magnitude(count));"
      , "}"
      ])
  , ("big_shift_right",
      [ "static inline pudu_big *pudu_big_shift_right(const pudu_big *a, pudu_int count, int kind, const pudu_site *negative, const pudu_site *wide) {"
      , "  (void)kind; (void)wide;"
      , "  count = pudu_normal(count);"
      , "  if (count.negative) pudu_fail(negative);"
      , "  return pudu_bigint_shift_right(a, pudu_magnitude(count));"
      , "}"
      ])
  , ("big_status",
      [ "/* The exit status of an entry answering a BigInt, as for any integer. */"
      , "static inline int pudu_big_status(const pudu_big *value) {"
      , "  if (value == NULL) return 0;"
      , "  if (value->negative) return 1;"
      , "  if (value->length > 1 || value->limbs[0] > 255) return 255;"
      , "  return (int)value->limbs[0];"
      , "}"
      ])
  , ("text_display_big",
      [ "static inline pudu_text pudu_text_display_big(const pudu_big *value) {"
      , "  size_t length;"
      , "  char *digits = pudu_big_decimal(value, &length);"
      , "  pudu_text text = pudu_text_copy(digits, length);"
      , "  free(digits);"
      , "  return text;"
      , "}"
      ])
  , ("int_to_big",
      [ "static inline pudu_big *pudu_int_to_big(pudu_int value) {"
      , "  value = pudu_normal(value);"
      , "  return pudu_big_from_magnitude(value.negative, pudu_magnitude(value));"
      , "}"
      ])
  , ("wide_to_big",
      [ "static inline pudu_big *pudu_wide_to_big(pudu_wide_int value) {"
      , "  pudu_word128 magnitude;"
      , "  uint32_t limbs[4];"
      , "  value = pudu_wide_normal(value);"
      , "  magnitude = pudu_wide_magnitude(value);"
      , "  limbs[0] = (uint32_t)magnitude.low; limbs[1] = (uint32_t)(magnitude.low >> 32);"
      , "  limbs[2] = (uint32_t)magnitude.high; limbs[3] = (uint32_t)(magnitude.high >> 32);"
      , "  return pudu_big_from_limbs(value.negative, 4, limbs);"
      , "}"
      ])
  , ("big_limb_pair",
      [ "/* The low 128 bits of a magnitude, which hold all of it when it fits. */"
      , "static inline uint64_t pudu_big_limb_pair(const pudu_big *value, size_t at) {"
      , "  uint64_t low = value != NULL && at < value->length ? value->limbs[at] : 0;"
      , "  uint64_t high = value != NULL && at + 1 < value->length ? value->limbs[at + 1] : 0;"
      , "  return (high << 32) | low;"
      , "}"
      ])
  , ("big_fits_int",
      [ "static inline int pudu_big_fits_int(const pudu_big *value, pudu_int_kind kind) {"
      , "  if (value == NULL) return 1;"
      , "  if (value->length > 2) return 0;"
      , "  return pudu_big_limb_pair(value, 0) <= (value->negative ? kind.negative_max : kind.positive_max);"
      , "}"
      ])
  , ("big_fits_wide",
      [ "static inline int pudu_big_fits_wide(const pudu_big *value, pudu_wide_kind kind) {"
      , "  uint64_t high;"
      , "  if (value == NULL) return 1;"
      , "  if (value->length > 4) return 0;"
      , "  high = pudu_big_limb_pair(value, 2);"
      , "  if (!kind.is_signed) return !value->negative;"
      , "  if (value->negative) return high < (UINT64_C(1) << 63) || (high == (UINT64_C(1) << 63) && pudu_big_limb_pair(value, 0) == 0);"
      , "  return high < (UINT64_C(1) << 63);"
      , "}"
      ])
  , ("big_to_int",
      [ "static inline pudu_int pudu_big_to_int(const pudu_big *value) {"
      , "  return pudu_make(pudu_big_limb_pair(value, 0), value != NULL && value->negative);"
      , "}"
      ])
  , ("big_to_wide",
      [ "static inline pudu_wide_int pudu_big_to_wide(const pudu_big *value) {"
      , "  return pudu_wide_make((pudu_word128){pudu_big_limb_pair(value, 0), pudu_big_limb_pair(value, 2)}, value != NULL && value->negative);"
      , "}"
      ])
  , ("big_normal",
      [ "static inline pudu_big *pudu_big_normal(pudu_big *value) { return pudu_big_retain(value); }"
      ])
  ]

bigOperationRuntimeDependencies :: Text -> [Text]
bigOperationRuntimeDependencies name = maybe [] id (lookup name
  [ ("big_add", ["big_value", "bigint_add", "site"])
  , ("big_sub", ["big_value", "bigint_sub", "site"])
  , ("big_mul", ["big_value", "bigint_mul", "site"])
  , ("big_wrap_add", ["big_value", "bigint_add"])
  , ("big_wrap_sub", ["big_value", "bigint_sub"])
  , ("big_wrap_mul", ["big_value", "bigint_mul"])
  , ("big_sat_add", ["big_value", "bigint_add"])
  , ("big_sat_sub", ["big_value", "bigint_sub"])
  , ("big_sat_mul", ["big_value", "bigint_mul"])
  , ("big_neg", ["big_value", "bigint_neg", "site"])
  , ("big_div", ["big_value", "big_divide", "big_release", "fail", "site"])
  , ("big_rem", ["big_value", "big_divide", "big_release", "fail", "site"])
  , ("big_bit_and", ["big_value", "big_bits"])
  , ("big_bit_or", ["big_value", "big_bits"])
  , ("big_bit_xor", ["big_value", "big_bits"])
  , ("big_bit_not", ["big_value", "bigint_not"])
  , ("big_shift_left", ["big_value", "bigint_shift_left", "fail", "magnitude", "normal", "integer_value", "site"])
  , ("big_shift_right", ["big_value", "bigint_shift_right", "fail", "magnitude", "normal", "integer_value", "site"])
  , ("big_status", ["big_value"])
  , ("text_display_big", ["big_value", "big_decimal", "text_copy", "text"])
  , ("int_to_big", ["big_value", "big_from_magnitude", "magnitude", "normal", "integer_value"])
  , ("wide_to_big", ["big_value", "big_from_limbs", "wide_magnitude", "wide_normal", "wide_value"])
  , ("big_limb_pair", ["big_value"])
  , ("big_fits_int", ["big_value", "big_limb_pair", "integer_value"])
  , ("big_fits_wide", ["big_value", "big_limb_pair", "wide_value"])
  , ("big_to_int", ["big_value", "big_limb_pair", "make", "integer_value"])
  , ("big_to_wide", ["big_value", "big_limb_pair", "wide_make", "wide_value"])
  , ("big_normal", ["big_value", "big_retain"])
  ])
