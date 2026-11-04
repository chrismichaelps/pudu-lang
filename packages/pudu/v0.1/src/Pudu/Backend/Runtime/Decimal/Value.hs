{-| @Pudu.Backend.Runtime.Decimal.Value — a Decimal as a reference-counted BigInt
    coefficient and a non-negative scale, NULL for zero at scale zero: exact
    arithmetic, exact or failing division, rounding by seven modes, digits,
    parsing and the nearest binary64. -}
module Pudu.Backend.Runtime.Decimal.Value (decimalValueRuntimeParts, decimalValueRuntimeDependencies) where

import Data.Text (Text)

-- One part per function, so a program holds only what it calls.
decimalValueRuntimeParts :: [(Text, [Text])]
decimalValueRuntimeParts =
  [ ("dec_value",
      [ "/* A Decimal: a reference count, a non-negative scale and a BigInt"
      , "   coefficient, the value being coefficient / 10^scale. NULL is 0 at scale"
      , "   0; any other zero keeps its scale, which rendering shows. */"
      , "typedef struct pudu_dec { size_t count; size_t scale; pudu_big *coefficient; } pudu_dec;"
      ])
  , ("dec_make",
      [ "/* Takes the coefficient's reference. */"
      , "static inline pudu_dec *pudu_dec_make(pudu_big *coefficient, size_t scale) {"
      , "  pudu_dec *value;"
      , "  if (coefficient == NULL && scale == 0) return NULL;"
      , "  value = malloc(sizeof(pudu_dec));"
      , "  if (value == NULL) pudu_memory_failure();"
      , "  value->count = 1;"
      , "  value->scale = scale;"
      , "  value->coefficient = coefficient;"
      , "  return value;"
      , "}"
      ])
  , ("dec_retain",
      [ "static inline pudu_dec *pudu_dec_retain(pudu_dec *value) {"
      , "  if (value != NULL) value->count += 1;"
      , "  return value;"
      , "}"
      ])
  , ("dec_release",
      [ "static inline void pudu_dec_release(pudu_dec *value) {"
      , "  if (value != NULL && --value->count == 0) {"
      , "    pudu_big_release(value->coefficient);"
      , "    free(value);"
      , "  }"
      , "}"
      ])
  , ("dec_coefficient",
      [ "static inline pudu_big *pudu_dec_coefficient(const pudu_dec *value) {"
      , "  return value == NULL ? NULL : value->coefficient;"
      , "}"
      ])
  , ("dec_scale_of",
      [ "static inline size_t pudu_dec_scale_of(const pudu_dec *value) {"
      , "  return value == NULL ? 0 : value->scale;"
      , "}"
      ])
  , ("big_times_small",
      [ "/* |a| * factor + carry, with a's sign. */"
      , "static inline pudu_big *pudu_big_times_small(const pudu_big *a, uint32_t factor) {"
      , "  pudu_big *product;"
      , "  uint64_t carry = 0;"
      , "  size_t index;"
      , "  if (a == NULL || factor == 0) return NULL;"
      , "  product = pudu_big_new(a->length + 1);"
      , "  for (index = 0; index < a->length; ++index) {"
      , "    uint64_t total = (uint64_t)a->limbs[index] * factor + carry;"
      , "    product->limbs[index] = (uint32_t)total;"
      , "    carry = total >> 32;"
      , "  }"
      , "  product->limbs[a->length] = (uint32_t)carry;"
      , "  product->negative = a->negative;"
      , "  return pudu_big_trim(product);"
      , "}"
      ])
  , ("big_times_ten_to",
      [ "/* a * 10^power, nine digits at a time. */"
      , "static inline pudu_big *pudu_big_times_ten_to(const pudu_big *a, size_t power) {"
      , "  pudu_big *result = pudu_big_retain((pudu_big *)a);"
      , "  while (power > 0 && result != NULL) {"
      , "    unsigned step = power >= 9 ? 9 : (unsigned)power;"
      , "    uint32_t factor = 1;"
      , "    unsigned index;"
      , "    pudu_big *next;"
      , "    for (index = 0; index < step; ++index) factor *= 10;"
      , "    next = pudu_big_times_small(result, factor);"
      , "    pudu_big_release(result);"
      , "    result = next;"
      , "    power -= step;"
      , "  }"
      , "  return result;"
      , "}"
      ])
  , ("big_ten_to",
      [ "static inline pudu_big *pudu_big_ten_to(size_t power) {"
      , "  pudu_big *one = pudu_big_from_magnitude(0, 1);"
      , "  pudu_big *result = pudu_big_times_ten_to(one, power);"
      , "  pudu_big_release(one);"
      , "  return result;"
      , "}"
      ])
  , ("dec_aligned",
      [ "/* Both coefficients at the larger scale. */"
      , "static inline size_t pudu_dec_aligned(const pudu_dec *a, const pudu_dec *b, pudu_big **left, pudu_big **right) {"
      , "  size_t ascale = pudu_dec_scale_of(a), bscale = pudu_dec_scale_of(b);"
      , "  size_t target = ascale > bscale ? ascale : bscale;"
      , "  *left = pudu_big_times_ten_to(pudu_dec_coefficient(a), target - ascale);"
      , "  *right = pudu_big_times_ten_to(pudu_dec_coefficient(b), target - bscale);"
      , "  return target;"
      , "}"
      ])
  , ("dec_add",
      [ "static inline pudu_dec *pudu_dec_add(const pudu_dec *a, const pudu_dec *b) {"
      , "  pudu_big *left, *right, *sum;"
      , "  size_t scale = pudu_dec_aligned(a, b, &left, &right);"
      , "  sum = pudu_bigint_add(left, right);"
      , "  pudu_big_release(left);"
      , "  pudu_big_release(right);"
      , "  return pudu_dec_make(sum, scale);"
      , "}"
      ])
  , ("dec_sub",
      [ "static inline pudu_dec *pudu_dec_sub(const pudu_dec *a, const pudu_dec *b) {"
      , "  pudu_big *left, *right, *difference;"
      , "  size_t scale = pudu_dec_aligned(a, b, &left, &right);"
      , "  difference = pudu_bigint_sub(left, right);"
      , "  pudu_big_release(left);"
      , "  pudu_big_release(right);"
      , "  return pudu_dec_make(difference, scale);"
      , "}"
      ])
  , ("dec_mul",
      [ "/* The product's scale is the sum of the operands': nothing rounds. */"
      , "static inline pudu_dec *pudu_dec_mul(const pudu_dec *a, const pudu_dec *b) {"
      , "  size_t ascale = pudu_dec_scale_of(a), bscale = pudu_dec_scale_of(b);"
      , "  if (ascale > SIZE_MAX - bscale) pudu_memory_failure();"
      , "  return pudu_dec_make(pudu_bigint_mul(pudu_dec_coefficient(a), pudu_dec_coefficient(b)), ascale + bscale);"
      , "}"
      ])
  , ("dec_neg",
      [ "static inline pudu_dec *pudu_dec_neg(const pudu_dec *a) {"
      , "  return pudu_dec_make(pudu_bigint_neg(pudu_dec_coefficient(a)), pudu_dec_scale_of(a));"
      , "}"
      ])
  , ("dec_compare",
      [ "static inline int pudu_dec_compare(const pudu_dec *a, const pudu_dec *b) {"
      , "  pudu_big *left, *right;"
      , "  int order;"
      , "  (void)pudu_dec_aligned(a, b, &left, &right);"
      , "  order = pudu_big_compare(left, right);"
      , "  pudu_big_release(left);"
      , "  pudu_big_release(right);"
      , "  return order;"
      , "}"
      ])
  , ("big_strip",
      [ "/* Divide out every factor `factor` (2 or 5) from a non-zero magnitude,"
      , "   counting them. */"
      , "static inline pudu_big *pudu_big_strip(pudu_big *value, uint32_t factor, size_t *count) {"
      , "  pudu_big *divisor = pudu_big_from_magnitude(0, factor);"
      , "  *count = 0;"
      , "  for (;;) {"
      , "    pudu_big *quotient, *remainder;"
      , "    pudu_big_divide(value, divisor, &quotient, &remainder);"
      , "    if (remainder != NULL) {"
      , "      pudu_big_release(quotient);"
      , "      pudu_big_release(remainder);"
      , "      break;"
      , "    }"
      , "    pudu_big_release(value);"
      , "    value = quotient;"
      , "    *count += 1;"
      , "  }"
      , "  pudu_big_release(divisor);"
      , "  return value;"
      , "}"
      ])
  , ("big_gcd",
      [ "/* The greatest common divisor of two magnitudes, by Euclid. */"
      , "static inline pudu_big *pudu_big_gcd(const pudu_big *a, const pudu_big *b) {"
      , "  pudu_big *x = a == NULL ? NULL : pudu_big_from_limbs(0, a->length, a->limbs);"
      , "  pudu_big *y = b == NULL ? NULL : pudu_big_from_limbs(0, b->length, b->limbs);"
      , "  while (y != NULL) {"
      , "    pudu_big *quotient, *remainder;"
      , "    pudu_big_divide(x, y, &quotient, &remainder);"
      , "    pudu_big_release(quotient);"
      , "    pudu_big_release(x);"
      , "    x = y;"
      , "    y = remainder;"
      , "  }"
      , "  return x;"
      , "}"
      ])
  , ("dec_rescaled",
      [ "/* coefficient / 10^shift as a value whose scale is never negative. */"
      , "static inline pudu_dec *pudu_dec_rescaled(pudu_big *coefficient, long long shift) {"
      , "  if (shift >= 0) return pudu_dec_make(coefficient, (size_t)shift);"
      , "  {"
      , "    pudu_big *scaled = pudu_big_times_ten_to(coefficient, (size_t)(-shift));"
      , "    pudu_big_release(coefficient);"
      , "    return pudu_dec_make(scaled, 0);"
      , "  }"
      , "}"
      ])
  , ("dec_divide_exact",
      [ "/* 0 with the quotient, 1 for a zero divisor, 2 for a quotient with no"
      , "   terminating base-ten expansion: its denominator in lowest terms has a"
      , "   prime factor other than two and five. */"
      , "static inline int pudu_dec_divide_exact(const pudu_dec *a, const pudu_dec *b, pudu_dec **result) {"
      , "  pudu_big *left = pudu_dec_coefficient(a), *right = pudu_dec_coefficient(b);"
      , "  pudu_big *divisor, *numerator, *denominator, *quotient, *remainder, *rest, *power, *multiplier;"
      , "  size_t twos, fives, digits;"
      , "  int negative;"
      , "  if (right == NULL) return 1;"
      , "  if (left == NULL) { *result = NULL; return 0; }"
      , "  divisor = pudu_big_gcd(left, right);"
      , "  pudu_big_divide(left, divisor, &numerator, &remainder);"
      , "  pudu_big_release(remainder);"
      , "  pudu_big_divide(right, divisor, &denominator, &remainder);"
      , "  pudu_big_release(remainder);"
      , "  pudu_big_release(divisor);"
      , "  negative = denominator->negative;"
      , "  denominator->negative = 0;"
      , "  if (negative) numerator->negative = !numerator->negative;"
      , "  rest = pudu_big_strip(pudu_big_retain(denominator), 2, &twos);"
      , "  rest = pudu_big_strip(rest, 5, &fives);"
      , "  if (rest->length != 1 || rest->limbs[0] != 1) {"
      , "    pudu_big_release(rest);"
      , "    pudu_big_release(numerator);"
      , "    pudu_big_release(denominator);"
      , "    return 2;"
      , "  }"
      , "  pudu_big_release(rest);"
      , "  digits = twos > fives ? twos : fives;"
      , "  power = pudu_big_ten_to(digits);"
      , "  pudu_big_divide(power, denominator, &multiplier, &remainder);"
      , "  pudu_big_release(remainder);"
      , "  pudu_big_release(power);"
      , "  pudu_big_release(denominator);"
      , "  quotient = pudu_bigint_mul(numerator, multiplier);"
      , "  pudu_big_release(numerator);"
      , "  pudu_big_release(multiplier);"
      , "  *result = pudu_dec_rescaled(quotient, (long long)digits + (long long)pudu_dec_scale_of(a) - (long long)pudu_dec_scale_of(b));"
      , "  return 0;"
      , "}"
      ])
  , ("big_rounded_quotient",
      [ "/* numerator / denominator with the last digit decided by the mode: 0 Up,"
      , "   1 Down, 2 Ceiling, 3 Floor, 4 HalfUp, 5 HalfDown, anything else HalfEven."
      , "   The denominator is not zero. */"
      , "static inline pudu_big *pudu_big_rounded_quotient(int mode, const pudu_big *numerator, const pudu_big *denominator) {"
      , "  pudu_big *quotient, *remainder, *doubled, *one, *rounded;"
      , "  int negative = (numerator != NULL && numerator->negative) != denominator->negative;"
      , "  int increment = 0, half;"
      , "  pudu_big_divide_magnitude(numerator, denominator, &quotient, &remainder);"
      , "  if (remainder == NULL) {"
      , "    if (quotient != NULL) quotient->negative = negative;"
      , "    return quotient;"
      , "  }"
      , "  doubled = pudu_bigint_add(remainder, remainder);"
      , "  half = pudu_big_compare_magnitude(doubled, denominator);"
      , "  pudu_big_release(doubled);"
      , "  pudu_big_release(remainder);"
      , "  switch (mode) {"
      , "    case 0: increment = 1; break;"
      , "    case 1: increment = 0; break;"
      , "    case 2: increment = !negative; break;"
      , "    case 3: increment = negative; break;"
      , "    case 4: increment = half >= 0; break;"
      , "    case 5: increment = half > 0; break;"
      , "    default: increment = half > 0 || (half == 0 && quotient != NULL && (quotient->limbs[0] & 1) != 0); break;"
      , "  }"
      , "  if (increment) {"
      , "    one = pudu_big_from_magnitude(0, 1);"
      , "    rounded = pudu_bigint_add(quotient, one);"
      , "    pudu_big_release(one);"
      , "    pudu_big_release(quotient);"
      , "    quotient = rounded;"
      , "  }"
      , "  if (quotient != NULL) quotient->negative = negative;"
      , "  return quotient;"
      , "}"
      ])
  , ("dec_divide_with",
      [ "/* To `digits` fractional digits, rounding by the mode; 1 for a zero"
      , "   divisor. */"
      , "static inline int pudu_dec_divide_with(const pudu_dec *a, const pudu_dec *b, long long digits, int mode, pudu_dec **result) {"
      , "  size_t target = digits < 0 ? 0 : (size_t)digits;"
      , "  long long shift = (long long)pudu_dec_scale_of(b) - (long long)pudu_dec_scale_of(a) + (long long)target;"
      , "  pudu_big *numerator, *denominator;"
      , "  if (pudu_dec_coefficient(b) == NULL) return 1;"
      , "  if (shift >= 0) {"
      , "    numerator = pudu_big_times_ten_to(pudu_dec_coefficient(a), (size_t)shift);"
      , "    denominator = pudu_big_retain(pudu_dec_coefficient(b));"
      , "  } else {"
      , "    numerator = pudu_big_retain(pudu_dec_coefficient(a));"
      , "    denominator = pudu_big_times_ten_to(pudu_dec_coefficient(b), (size_t)(-shift));"
      , "  }"
      , "  *result = pudu_dec_make(pudu_big_rounded_quotient(mode, numerator, denominator), target);"
      , "  pudu_big_release(numerator);"
      , "  pudu_big_release(denominator);"
      , "  return 0;"
      , "}"
      ])
  , ("dec_round",
      [ "/* To `digits` fractional digits: more than the value carries rescales,"
      , "   fewer rounds by the mode. */"
      , "static inline pudu_dec *pudu_dec_round(const pudu_dec *a, long long digits, int mode) {"
      , "  size_t target = digits < 0 ? 0 : (size_t)digits, scale = pudu_dec_scale_of(a);"
      , "  pudu_big *power, *rounded;"
      , "  if (target >= scale) return pudu_dec_make(pudu_big_times_ten_to(pudu_dec_coefficient(a), target - scale), target);"
      , "  power = pudu_big_ten_to(scale - target);"
      , "  rounded = pudu_big_rounded_quotient(mode, pudu_dec_coefficient(a), power);"
      , "  pudu_big_release(power);"
      , "  return pudu_dec_make(rounded, target);"
      , "}"
      ])
  , ("dec_digits",
      [ "/* Exactly the fractional digits the scale claims, the caller freeing them. */"
      , "static inline char *pudu_dec_digits(const pudu_dec *value, size_t *length) {"
      , "  size_t scale = pudu_dec_scale_of(value), count, used = 0, index;"
      , "  pudu_big *coefficient = pudu_dec_coefficient(value);"
      , "  int negative = coefficient != NULL && coefficient->negative;"
      , "  char *digits, *text;"
      , "  digits = pudu_big_decimal(coefficient, &count);"
      , "  if (scale == 0) { *length = count; return digits; }"
      , "  {"
      , "    char *start = negative ? digits + 1 : digits;"
      , "    size_t width = negative ? count - 1 : count;"
      , "    size_t padded = width > scale ? width : scale + 1;"
      , "    if (padded > SIZE_MAX - 3) pudu_memory_failure();"
      , "    text = malloc(padded + 3);"
      , "    if (text == NULL) pudu_memory_failure();"
      , "    if (negative) text[used++] = '-';"
      , "    for (index = 0; index < padded - scale; ++index) {"
      , "      size_t at = index + width;"
      , "      text[used++] = at >= padded ? start[at - padded] : '0';"
      , "    }"
      , "    text[used++] = '.';"
      , "    for (index = padded - scale; index < padded; ++index) {"
      , "      size_t at = index + width;"
      , "      text[used++] = at >= padded ? start[at - padded] : '0';"
      , "    }"
      , "    text[used] = 0;"
      , "  }"
      , "  free(digits);"
      , "  *length = used;"
      , "  return text;"
      , "}"
      ])
  ]

decimalValueRuntimeDependencies :: Text -> [Text]
decimalValueRuntimeDependencies name = maybe [] id (lookup name
  [ ("dec_value", ["memory_failure", "big_value"])
  , ("dec_make", ["dec_value", "memory_failure"])
  , ("dec_retain", ["dec_value"])
  , ("dec_release", ["dec_value", "big_release"])
  , ("dec_coefficient", ["dec_value"])
  , ("dec_scale_of", ["dec_value"])
  , ("big_times_small", ["dec_value", "big_new", "big_trim"])
  , ("big_times_ten_to", ["dec_value", "big_release", "big_retain", "big_times_small"])
  , ("big_ten_to", ["dec_value", "big_from_magnitude", "big_release", "big_times_ten_to"])
  , ("dec_aligned", ["dec_value", "big_times_ten_to", "dec_coefficient", "dec_scale_of"])
  , ("dec_add", ["dec_value", "big_release", "bigint_add", "dec_aligned", "dec_make"])
  , ("dec_sub", ["dec_value", "big_release", "bigint_sub", "dec_aligned", "dec_make"])
  , ("dec_mul", ["dec_value", "bigint_mul", "dec_coefficient", "dec_make", "dec_scale_of", "memory_failure"])
  , ("dec_neg", ["dec_value", "bigint_neg", "dec_coefficient", "dec_make", "dec_scale_of"])
  , ("dec_compare", ["dec_value", "big_compare", "big_release", "dec_aligned"])
  , ("big_strip", ["dec_value", "big_divide", "big_from_magnitude", "big_release"])
  , ("big_gcd", ["dec_value", "big_divide", "big_from_limbs", "big_release"])
  , ("dec_rescaled", ["dec_value", "big_release", "big_times_ten_to", "dec_make"])
  , ("dec_divide_exact", ["dec_value", "big_divide", "big_gcd", "big_release", "big_retain", "big_strip", "big_ten_to", "bigint_mul", "dec_coefficient", "dec_rescaled", "dec_scale_of"])
  , ("big_rounded_quotient", ["dec_value", "big_compare_magnitude", "big_divide_magnitude", "big_from_magnitude", "big_release", "bigint_add"])
  , ("dec_divide_with", ["dec_value", "big_release", "big_retain", "big_rounded_quotient", "big_times_ten_to", "dec_coefficient", "dec_make", "dec_scale_of"])
  , ("dec_round", ["dec_value", "big_release", "big_rounded_quotient", "big_ten_to", "big_times_ten_to", "dec_coefficient", "dec_make", "dec_scale_of"])
  , ("dec_digits", ["dec_value", "big_decimal", "dec_coefficient", "dec_scale_of", "memory_failure"])
  ])
