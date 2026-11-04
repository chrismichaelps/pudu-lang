{-| @Pudu.Backend.Runtime.Decimal.Operations — Decimal division with its failures, display,
    and the primitives behind `Std.Decimal` and `Str.toDecimal`. -}
module Pudu.Backend.Runtime.Decimal.Operations (decimalOperationRuntimeParts, decimalOperationRuntimeDependencies) where

import Data.Text (Text)

-- One part per function, so a program holds only what it calls.
decimalOperationRuntimeParts :: [(Text, [Text])]
decimalOperationRuntimeParts =
  [ ("dec_parse",
      [ "/* `parseDecimalText` on text whose surrounding white space is already"
      , "   gone: underscores dropped, an optional exponent of at most 6144 in size,"
      , "   a sign, and digits with at most one point. 1 with the value, else 0. */"
      , "static inline int pudu_dec_parse(const char *source, size_t length, pudu_dec **result) {"
      , "  char *cleaned = malloc(length + 1);"
      , "  size_t used = 0, index, split, point = (size_t)-1, fraction = 0;"
      , "  long long exponent = 0;"
      , "  int negative = 0, exponent_negative = 0, whole_seen = 0, fraction_seen = 0;"
      , "  pudu_big *coefficient = NULL, *ten = NULL;"
      , "  const char *mantissa;"
      , "  size_t mantissa_length;"
      , "  if (cleaned == NULL) pudu_memory_failure();"
      , "  for (index = 0; index < length; ++index) if (source[index] != '_') cleaned[used++] = source[index];"
      , "  for (split = 0; split < used && cleaned[split] != 'e' && cleaned[split] != 'E'; ++split) {}"
      , "  if (split < used) {"
      , "    size_t at = split + 1;"
      , "    int any = 0;"
      , "    if (at < used && (cleaned[at] == '-' || cleaned[at] == '+')) { exponent_negative = cleaned[at] == '-'; at += 1; }"
      , "    else if (at >= used) { free(cleaned); return 0; }"
      , "    for (; at < used; ++at) {"
      , "      if (cleaned[at] < '0' || cleaned[at] > '9') { free(cleaned); return 0; }"
      , "      any = 1;"
      , "      if (exponent <= 6144) exponent = exponent * 10 + (cleaned[at] - '0');"
      , "    }"
      , "    if (!any || exponent > 6144) { free(cleaned); return 0; }"
      , "    if (exponent_negative) exponent = -exponent;"
      , "  }"
      , "  mantissa = cleaned;"
      , "  mantissa_length = split;"
      , "  if (mantissa_length == 0) { free(cleaned); return 0; }"
      , "  if (mantissa[0] == '-' || mantissa[0] == '+') { negative = mantissa[0] == '-'; mantissa += 1; mantissa_length -= 1; }"
      , "  ten = pudu_big_from_magnitude(0, 10);"
      , "  for (index = 0; index < mantissa_length; ++index) {"
      , "    char scalar = mantissa[index];"
      , "    if (scalar == '.' && point == (size_t)-1) { point = index; continue; }"
      , "    if (scalar < '0' || scalar > '9') { pudu_big_release(coefficient); pudu_big_release(ten); free(cleaned); return 0; }"
      , "    {"
      , "      pudu_big *digit = pudu_big_from_magnitude(0, (uint64_t)(scalar - '0'));"
      , "      pudu_big *scaled = pudu_bigint_mul(coefficient, ten);"
      , "      pudu_big *next = pudu_bigint_add(scaled, digit);"
      , "      pudu_big_release(digit);"
      , "      pudu_big_release(scaled);"
      , "      pudu_big_release(coefficient);"
      , "      coefficient = next;"
      , "    }"
      , "    if (point == (size_t)-1) whole_seen = 1; else { fraction_seen = 1; fraction += 1; }"
      , "  }"
      , "  pudu_big_release(ten);"
      , "  free(cleaned);"
      , "  if (point == (size_t)-1 ? !whole_seen : (!whole_seen && !fraction_seen)) { pudu_big_release(coefficient); return 0; }"
      , "  if (negative && coefficient != NULL) coefficient->negative = 1;"
      , "  *result = pudu_dec_rescaled(coefficient, (long long)fraction - exponent);"
      , "  return 1;"
      , "}"
      ])
  , ("big_bit_length",
      [ "static inline long long pudu_big_bit_length(const pudu_big *value) {"
      , "  uint32_t top;"
      , "  long long bits;"
      , "  if (value == NULL) return 0;"
      , "  top = value->limbs[value->length - 1];"
      , "  bits = (long long)(value->length - 1) * 32;"
      , "  while (top != 0) { bits += 1; top >>= 1; }"
      , "  return bits;"
      , "}"
      ])
  , ("dec_to_bits",
      [ "/* The binary64 bits nearest coefficient / 10^scale, ties to even, as"
      , "   `fromRational` gives it: subnormal near zero, infinite past the largest"
      , "   finite value. With k = 64 - (bits of N - bits of D) the quotient"
      , "   floor(N 2^k / D) lies in [2^63, 2^65); one halving makes it 64 bits. */"
      , "static inline uint64_t pudu_dec_to_bits(const pudu_dec *value) {"
      , "  pudu_big *coefficient = pudu_dec_coefficient(value), *magnitude, *denominator, *top, *bottom, *quotient, *remainder;"
      , "  long long shift, binary;"
      , "  int sticky, keep;"
      , "  uint64_t sign, mantissa, kept, rest, halfway;"
      , "  if (coefficient == NULL) return 0;"
      , "  sign = coefficient->negative ? UINT64_C(1) << 63 : 0;"
      , "  magnitude = pudu_big_from_limbs(0, coefficient->length, coefficient->limbs);"
      , "  denominator = pudu_big_ten_to(pudu_dec_scale_of(value));"
      , "  shift = 64 - (pudu_big_bit_length(magnitude) - pudu_big_bit_length(denominator));"
      , "  top = shift >= 0 ? pudu_bigint_shift_left(magnitude, (uint64_t)shift) : pudu_big_retain(magnitude);"
      , "  bottom = shift >= 0 ? pudu_big_retain(denominator) : pudu_bigint_shift_left(denominator, (uint64_t)(-shift));"
      , "  pudu_big_divide_magnitude(top, bottom, &quotient, &remainder);"
      , "  pudu_big_release(top);"
      , "  pudu_big_release(bottom);"
      , "  pudu_big_release(magnitude);"
      , "  pudu_big_release(denominator);"
      , "  sticky = remainder != NULL;"
      , "  pudu_big_release(remainder);"
      , "  if (quotient->length == 3) {"
      , "    sticky |= (quotient->limbs[0] & 1) != 0;"
      , "    mantissa = ((uint64_t)quotient->limbs[2] << 63) | ((uint64_t)quotient->limbs[1] << 31) | (quotient->limbs[0] >> 1);"
      , "    shift -= 1;"
      , "  } else {"
      , "    mantissa = ((uint64_t)quotient->limbs[1] << 32) | quotient->limbs[0];"
      , "  }"
      , "  pudu_big_release(quotient);"
      , "  /* The value is mantissa 2^-shift, mantissa in [2^63, 2^64), so its"
      , "     leading bit is 2^binary. */"
      , "  binary = 63 - shift;"
      , "  if (binary > 1023) return sign | UINT64_C(0x7FF0000000000000);"
      , "  keep = binary >= -1022 ? 53 : 53 - (int)(-1022 - binary);"
      , "  if (keep <= 0) {"
      , "    /* Only the 2^-1074 place can be reached: round to it or to zero. */"
      , "    return sign | (keep == 0 && (mantissa > (UINT64_C(1) << 63) || sticky) ? 1 : 0);"
      , "  }"
      , "  kept = mantissa >> (64 - keep);"
      , "  rest = mantissa & ((UINT64_C(1) << (64 - keep)) - 1);"
      , "  halfway = UINT64_C(1) << (63 - keep);"
      , "  if (rest > halfway || (rest == halfway && (sticky || (kept & 1) != 0))) kept += 1;"
      , "  if (keep < 53) {"
      , "    /* Subnormal: the exponent field is zero, unless rounding reached the"
      , "       smallest normal, whose bits then follow on. */"
      , "    return sign | kept;"
      , "  }"
      , "  if (kept == (UINT64_C(1) << 53)) { kept >>= 1; binary += 1; }"
      , "  if (binary > 1023) return sign | UINT64_C(0x7FF0000000000000);"
      , "  return sign | ((uint64_t)(binary + 1023) << 52) | (kept & ((UINT64_C(1) << 52) - 1));"
      , "}"
      ])
  , ("dec_divide",
      [ "/* `/`: exact, or a failure at the zero-divisor or non-terminating site. */"
      , "static inline pudu_dec *pudu_dec_divide(const pudu_dec *a, const pudu_dec *b, const pudu_site *zero, const pudu_site *endless) {"
      , "  pudu_dec *result = NULL;"
      , "  int outcome = pudu_dec_divide_exact(a, b, &result);"
      , "  if (outcome == 1) pudu_fail(zero);"
      , "  if (outcome == 2) pudu_fail(endless);"
      , "  return result;"
      , "}"
      ])
  , ("text_display_dec",
      [ "static inline pudu_text pudu_text_display_dec(const pudu_dec *value) {"
      , "  size_t length;"
      , "  char *digits = pudu_dec_digits(value, &length);"
      , "  pudu_text text = pudu_text_copy(digits, length);"
      , "  free(digits);"
      , "  return text;"
      , "}"
      ])
  , ("dec_parsed",
      [ "/* `parseDecimalText`: surrounding white space as Data.Text strips it. */"
      , "static inline int pudu_dec_parsed(pudu_text text, pudu_dec **result) {"
      , "  pudu_text trimmed = pudu_text_trim(text);"
      , "  int parsed = pudu_dec_parse((const char *)trimmed.bytes, trimmed.length, result);"
      , "  pudu_text_release(trimmed);"
      , "  return parsed;"
      , "}"
      ])
  , ("dec_parses",
      [ "static inline int pudu_dec_parses(pudu_text text) {"
      , "  pudu_dec *result = NULL;"
      , "  int parsed = pudu_dec_parsed(text, &result);"
      , "  pudu_dec_release(result);"
      , "  return parsed;"
      , "}"
      ])
  , ("dec_parse_text",
      [ "/* The value of text `dec_parses` accepted. */"
      , "static inline pudu_dec *pudu_dec_parse_text(pudu_text text) {"
      , "  pudu_dec *result = NULL;"
      , "  (void)pudu_dec_parsed(text, &result);"
      , "  return result;"
      , "}"
      ])
  , ("dec_text_parses",
      [ "/* `Str.toDecimal` also refuses separators and spaces anywhere. */"
      , "static inline int pudu_dec_text_parses(pudu_text text) {"
      , "  size_t index;"
      , "  for (index = 0; index < text.length; ++index) {"
      , "    unsigned char scalar = text.bytes[index];"
      , "    if (scalar == '_' || scalar == ' ' || scalar == '\\t' || scalar == '\\n' || scalar == '\\r') return 0;"
      , "  }"
      , "  return pudu_dec_parses(text);"
      , "}"
      ])
  , ("dec_from_int",
      [ "static inline pudu_dec *pudu_dec_from_int(pudu_int value) {"
      , "  value = pudu_normal(value);"
      , "  return pudu_dec_make(pudu_big_from_magnitude(value.negative, pudu_magnitude(value)), 0);"
      , "}"
      ])
  , ("dec_scale",
      [ "static inline pudu_int pudu_dec_scale(const pudu_dec *value) {"
      , "  return pudu_make((uint64_t)pudu_dec_scale_of(value), 0);"
      , "}"
      ])
  , ("dec_names_int",
      [ "/* Whether the value is a whole number an Int can hold. */"
      , "static inline int pudu_dec_names_int(const pudu_dec *value) {"
      , "  pudu_big *power = pudu_big_ten_to(pudu_dec_scale_of(value)), *quotient, *remainder;"
      , "  int fits;"
      , "  pudu_big_divide(pudu_dec_coefficient(value), power, &quotient, &remainder);"
      , "  fits = remainder == NULL && (quotient == NULL || (quotient->length <= 2"
      , "    && pudu_big_limb_pair(quotient, 0) <= (quotient->negative ? UINT64_C(1) << 63 : (UINT64_C(1) << 63) - 1)));"
      , "  pudu_big_release(power);"
      , "  pudu_big_release(quotient);"
      , "  pudu_big_release(remainder);"
      , "  return fits;"
      , "}"
      ])
  , ("dec_to_int",
      [ "/* The whole number of a value `dec_names_int` accepted. */"
      , "static inline pudu_int pudu_dec_to_int(const pudu_dec *value) {"
      , "  pudu_big *power = pudu_big_ten_to(pudu_dec_scale_of(value)), *quotient, *remainder;"
      , "  pudu_int answer;"
      , "  uint64_t low;"
      , "  pudu_big_divide(pudu_dec_coefficient(value), power, &quotient, &remainder);"
      , "  low = quotient == NULL ? 0 : quotient->limbs[0] | (quotient->length > 1 ? (uint64_t)quotient->limbs[1] << 32 : 0);"
      , "  answer = pudu_make(low, quotient != NULL && quotient->negative);"
      , "  pudu_big_release(power);"
      , "  pudu_big_release(quotient);"
      , "  pudu_big_release(remainder);"
      , "  return answer;"
      , "}"
      ])
  , ("dec_to_float",
      [ "static inline uint64_t pudu_dec_to_float(const pudu_dec *value) {"
      , "  return pudu_dec_to_bits(value);"
      , "}"
      ])
  , ("dec_digits_of",
      [ "/* A digit count from an Int: any negative count is none. */"
      , "static inline long long pudu_dec_digits_of(pudu_int digits) {"
      , "  digits = pudu_normal(digits);"
      , "  if (digits.negative) return -1;"
      , "  return digits.bits > (uint64_t)INT64_MAX ? INT64_MAX : (long long)digits.bits;"
      , "}"
      ])
  , ("dec_mode_of",
      [ "/* A rounding code from an Int: 0 to 5 name their modes, anything else is"
      , "   half-even. */"
      , "static inline int pudu_dec_mode_of(pudu_int mode) {"
      , "  mode = pudu_normal(mode);"
      , "  return !mode.negative && mode.bits <= 5 ? (int)mode.bits : 6;"
      , "}"
      ])
  , ("dec_divide_to",
      [ "/* `decimalDivide` of a non-zero divisor. */"
      , "static inline pudu_dec *pudu_dec_divide_to(const pudu_dec *a, const pudu_dec *b, pudu_int digits, pudu_int mode) {"
      , "  pudu_dec *result = NULL;"
      , "  (void)pudu_dec_divide_with(a, b, pudu_dec_digits_of(digits), pudu_dec_mode_of(mode), &result);"
      , "  return result;"
      , "}"
      ])
  , ("dec_round_to",
      [ "static inline pudu_dec *pudu_dec_round_to(const pudu_dec *a, pudu_int digits, pudu_int mode) {"
      , "  return pudu_dec_round(a, pudu_dec_digits_of(digits), pudu_dec_mode_of(mode));"
      , "}"
      ])
  , ("dec_is_zero",
      [ "static inline int pudu_dec_is_zero(const pudu_dec *value) {"
      , "  return pudu_dec_coefficient(value) == NULL;"
      , "}"
      ])
  , ("dec_literal",
      [ "/* A literal's value, a new reference each time it runs. */"
      , "static inline pudu_dec *pudu_dec_literal(int negative, size_t length, const uint32_t *limbs, size_t scale) {"
      , "  return pudu_dec_make(pudu_big_from_limbs(negative, length, limbs), scale);"
      , "}"
      ])
  ]

decimalOperationRuntimeDependencies :: Text -> [Text]
decimalOperationRuntimeDependencies name = maybe [] id (lookup name
  [ ("dec_parse", ["dec_value", "big_from_magnitude", "big_release", "bigint_add", "bigint_mul", "dec_rescaled", "memory_failure"])
  , ("big_bit_length", ["dec_value"])
  , ("dec_to_bits", ["dec_value", "big_bit_length", "big_divide_magnitude", "big_from_limbs", "big_release", "big_retain", "big_ten_to", "bigint_shift_left", "dec_coefficient", "dec_scale_of"])
  , ("dec_divide", ["dec_value", "dec_divide_exact", "fail", "site"])
  , ("text_display_dec", ["dec_value", "dec_digits", "text_copy", "text"])
  , ("dec_parsed", ["dec_value", "dec_parse", "text", "text_trim"])
  , ("dec_parses", ["dec_value", "dec_parsed", "dec_release", "text"])
  , ("dec_parse_text", ["dec_value", "dec_parsed", "text"])
  , ("dec_text_parses", ["dec_value", "dec_parses", "text"])
  , ("dec_from_int", ["dec_value", "big_from_magnitude", "dec_make", "magnitude", "normal", "integer_value"])
  , ("dec_scale", ["dec_value", "dec_scale_of", "make", "integer_value"])
  , ("dec_names_int", ["dec_value", "big_divide", "big_limb_pair", "big_release", "big_ten_to", "dec_coefficient", "dec_scale_of"])
  , ("dec_to_int", ["dec_value", "big_divide", "big_release", "big_ten_to", "dec_coefficient", "dec_scale_of", "make", "integer_value"])
  , ("dec_to_float", ["dec_value", "dec_to_bits"])
  , ("dec_digits_of", ["dec_value", "normal", "integer_value"])
  , ("dec_mode_of", ["dec_value", "normal", "integer_value"])
  , ("dec_divide_to", ["dec_value", "dec_digits_of", "dec_divide_with", "dec_mode_of", "integer_value"])
  , ("dec_round_to", ["dec_value", "dec_digits_of", "dec_mode_of", "dec_round", "integer_value"])
  , ("dec_is_zero", ["dec_value", "dec_coefficient"])
  , ("dec_literal", ["dec_value", "big_from_limbs", "dec_make"])
  ])
