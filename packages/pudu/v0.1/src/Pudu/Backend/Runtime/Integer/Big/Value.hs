{-| @Pudu.Backend.Runtime.Integer.Big.Value — a BigInt as a reference-counted sign and magnitude
    of 32-bit limbs, least significant first, NULL for zero: exact
    arithmetic, truncating division, two's-complement bits, shifts and
    decimal digits. -}
module Pudu.Backend.Runtime.Integer.Big.Value (bigValueRuntimeParts, bigValueRuntimeDependencies) where

import Data.Text (Text)

-- One part per function, so a program holds only what it calls.
bigValueRuntimeParts :: [(Text, [Text])]
bigValueRuntimeParts =
  [ ("big_value",
      [ "/* A BigInt: a reference count, a sign and a magnitude of 32-bit limbs,"
      , "   least significant first, with no high zero limb. NULL is zero. */"
      , "typedef struct pudu_big { size_t count; size_t length; int negative; uint32_t limbs[]; } pudu_big;"
      ])
  , ("big_new",
      [ "static inline pudu_big *pudu_big_new(size_t length) {"
      , "  pudu_big *value;"
      , "  if (length > (SIZE_MAX - sizeof(pudu_big)) / sizeof(uint32_t)) pudu_memory_failure();"
      , "  value = malloc(sizeof(pudu_big) + length * sizeof(uint32_t));"
      , "  if (value == NULL) pudu_memory_failure();"
      , "  value->count = 1;"
      , "  value->length = length;"
      , "  value->negative = 0;"
      , "  return value;"
      , "}"
      ])
  , ("big_retain",
      [ "static inline pudu_big *pudu_big_retain(pudu_big *value) {"
      , "  if (value != NULL) value->count += 1;"
      , "  return value;"
      , "}"
      ])
  , ("big_release",
      [ "static inline void pudu_big_release(pudu_big *value) {"
      , "  if (value != NULL && --value->count == 0) free(value);"
      , "}"
      ])
  , ("big_trim",
      [ "/* Drop high zero limbs; an empty magnitude is zero, which is NULL. */"
      , "static inline pudu_big *pudu_big_trim(pudu_big *value) {"
      , "  while (value->length > 0 && value->limbs[value->length - 1] == 0) value->length -= 1;"
      , "  if (value->length == 0) { free(value); return NULL; }"
      , "  return value;"
      , "}"
      ])
  , ("big_from_limbs",
      [ "static inline pudu_big *pudu_big_from_limbs(int negative, size_t length, const uint32_t *limbs) {"
      , "  pudu_big *value;"
      , "  if (length == 0) return NULL;"
      , "  value = pudu_big_new(length);"
      , "  memcpy(value->limbs, limbs, length * sizeof(uint32_t));"
      , "  value->negative = negative != 0;"
      , "  return pudu_big_trim(value);"
      , "}"
      ])
  , ("big_from_magnitude",
      [ "static inline pudu_big *pudu_big_from_magnitude(int negative, uint64_t magnitude) {"
      , "  uint32_t limbs[2] = { (uint32_t)magnitude, (uint32_t)(magnitude >> 32) };"
      , "  return pudu_big_from_limbs(negative, magnitude == 0 ? 0 : (magnitude >> 32) != 0 ? 2 : 1, limbs);"
      , "}"
      ])
  , ("big_compare_magnitude",
      [ "/* -1, 0 or 1 for the magnitudes alone. */"
      , "static inline int pudu_big_compare_magnitude(const pudu_big *a, const pudu_big *b) {"
      , "  size_t alength = a == NULL ? 0 : a->length;"
      , "  size_t blength = b == NULL ? 0 : b->length;"
      , "  size_t index;"
      , "  if (alength != blength) return alength < blength ? -1 : 1;"
      , "  for (index = alength; index > 0; --index) {"
      , "    if (a->limbs[index - 1] != b->limbs[index - 1]) return a->limbs[index - 1] < b->limbs[index - 1] ? -1 : 1;"
      , "  }"
      , "  return 0;"
      , "}"
      ])
  , ("big_sign",
      [ "static inline int pudu_big_sign(const pudu_big *value) {"
      , "  return value == NULL ? 0 : value->negative ? -1 : 1;"
      , "}"
      ])
  , ("big_compare",
      [ "static inline int pudu_big_compare(const pudu_big *a, const pudu_big *b) {"
      , "  int asign = pudu_big_sign(a), bsign = pudu_big_sign(b);"
      , "  if (asign != bsign) return asign < bsign ? -1 : 1;"
      , "  if (asign == 0) return 0;"
      , "  return asign * pudu_big_compare_magnitude(a, b);"
      , "}"
      ])
  , ("big_add_magnitude",
      [ "/* |a| + |b| with the given sign. */"
      , "static inline pudu_big *pudu_big_add_magnitude(const pudu_big *a, const pudu_big *b, int negative) {"
      , "  size_t alength = a == NULL ? 0 : a->length;"
      , "  size_t blength = b == NULL ? 0 : b->length;"
      , "  size_t length = (alength > blength ? alength : blength) + 1;"
      , "  pudu_big *sum = pudu_big_new(length);"
      , "  uint64_t carry = 0;"
      , "  size_t index;"
      , "  for (index = 0; index < length; ++index) {"
      , "    uint64_t total = carry;"
      , "    if (index < alength) total += a->limbs[index];"
      , "    if (index < blength) total += b->limbs[index];"
      , "    sum->limbs[index] = (uint32_t)total;"
      , "    carry = total >> 32;"
      , "  }"
      , "  sum->negative = negative;"
      , "  return pudu_big_trim(sum);"
      , "}"
      ])
  , ("big_subtract_magnitude",
      [ "/* |a| - |b| with the given sign, where |a| >= |b|. */"
      , "static inline pudu_big *pudu_big_subtract_magnitude(const pudu_big *a, const pudu_big *b, int negative) {"
      , "  size_t alength = a == NULL ? 0 : a->length;"
      , "  size_t blength = b == NULL ? 0 : b->length;"
      , "  pudu_big *difference;"
      , "  int64_t borrow = 0;"
      , "  size_t index;"
      , "  if (alength == 0) return NULL;"
      , "  difference = pudu_big_new(alength);"
      , "  for (index = 0; index < alength; ++index) {"
      , "    int64_t total = (int64_t)a->limbs[index] - borrow - (index < blength ? (int64_t)b->limbs[index] : 0);"
      , "    borrow = total < 0;"
      , "    difference->limbs[index] = (uint32_t)(total + (borrow ? (INT64_C(1) << 32) : 0));"
      , "  }"
      , "  difference->negative = negative;"
      , "  return pudu_big_trim(difference);"
      , "}"
      ])
  , ("big_signed_add",
      [ "/* a + b, with b's sign given separately so subtraction is addition. */"
      , "static inline pudu_big *pudu_big_signed_add(const pudu_big *a, const pudu_big *b, int bnegative) {"
      , "  int anegative = a != NULL && a->negative;"
      , "  if (b == NULL) return pudu_big_retain((pudu_big *)a);"
      , "  if (a == NULL) return pudu_big_from_limbs(bnegative, b->length, b->limbs);"
      , "  if (anegative == bnegative) return pudu_big_add_magnitude(a, b, anegative);"
      , "  if (pudu_big_compare_magnitude(a, b) >= 0) return pudu_big_subtract_magnitude(a, b, anegative);"
      , "  return pudu_big_subtract_magnitude(b, a, bnegative);"
      , "}"
      ])
  , ("bigint_add",
      [ "static inline pudu_big *pudu_bigint_add(const pudu_big *a, const pudu_big *b) {"
      , "  return pudu_big_signed_add(a, b, b != NULL && b->negative);"
      , "}"
      ])
  , ("bigint_sub",
      [ "static inline pudu_big *pudu_bigint_sub(const pudu_big *a, const pudu_big *b) {"
      , "  return pudu_big_signed_add(a, b, b != NULL && !b->negative);"
      , "}"
      ])
  , ("bigint_neg",
      [ "static inline pudu_big *pudu_bigint_neg(const pudu_big *a) {"
      , "  if (a == NULL) return NULL;"
      , "  return pudu_big_from_limbs(!a->negative, a->length, a->limbs);"
      , "}"
      ])
  , ("bigint_mul",
      [ "static inline pudu_big *pudu_bigint_mul(const pudu_big *a, const pudu_big *b) {"
      , "  pudu_big *product;"
      , "  size_t i, j;"
      , "  if (a == NULL || b == NULL) return NULL;"
      , "  if (a->length > SIZE_MAX - b->length) pudu_memory_failure();"
      , "  product = pudu_big_new(a->length + b->length);"
      , "  memset(product->limbs, 0, product->length * sizeof(uint32_t));"
      , "  for (i = 0; i < a->length; ++i) {"
      , "    uint64_t carry = 0;"
      , "    for (j = 0; j < b->length; ++j) {"
      , "      uint64_t total = (uint64_t)a->limbs[i] * b->limbs[j] + product->limbs[i + j] + carry;"
      , "      product->limbs[i + j] = (uint32_t)total;"
      , "      carry = total >> 32;"
      , "    }"
      , "    product->limbs[i + b->length] = (uint32_t)carry;"
      , "  }"
      , "  product->negative = a->negative != b->negative;"
      , "  return pudu_big_trim(product);"
      , "}"
      ])
  , ("big_divide_magnitude",
      [ "/* Truncating division of magnitudes (Knuth, algorithm D): the quotient and"
      , "   remainder carry no sign yet. The divisor is not zero. */"
      , "static inline void pudu_big_divide_magnitude(const pudu_big *a, const pudu_big *b, pudu_big **quotient, pudu_big **remainder) {"
      , "  size_t n = b->length, m, i, j;"
      , "  int shift = 0;"
      , "  uint32_t top;"
      , "  uint32_t *u, *v;"
      , "  pudu_big *q;"
      , "  if (a == NULL || pudu_big_compare_magnitude(a, b) < 0) {"
      , "    *quotient = NULL;"
      , "    *remainder = a == NULL ? NULL : pudu_big_from_limbs(0, a->length, a->limbs);"
      , "    return;"
      , "  }"
      , "  m = a->length - n;"
      , "  if (n == 1) {"
      , "    uint64_t rest = 0;"
      , "    q = pudu_big_new(a->length);"
      , "    for (i = a->length; i > 0; --i) {"
      , "      uint64_t current = (rest << 32) | a->limbs[i - 1];"
      , "      q->limbs[i - 1] = (uint32_t)(current / b->limbs[0]);"
      , "      rest = current % b->limbs[0];"
      , "    }"
      , "    *quotient = pudu_big_trim(q);"
      , "    *remainder = pudu_big_from_magnitude(0, rest);"
      , "    return;"
      , "  }"
      , "  top = b->limbs[n - 1];"
      , "  while ((top & UINT32_C(0x80000000)) == 0) { top <<= 1; shift += 1; }"
      , "  u = calloc(a->length + 1, sizeof(uint32_t));"
      , "  v = calloc(n, sizeof(uint32_t));"
      , "  if (u == NULL || v == NULL) pudu_memory_failure();"
      , "  for (i = n; i > 0; --i) {"
      , "    v[i - 1] = (b->limbs[i - 1] << shift) | (shift != 0 && i > 1 ? b->limbs[i - 2] >> (32 - shift) : 0);"
      , "  }"
      , "  u[a->length] = shift != 0 ? a->limbs[a->length - 1] >> (32 - shift) : 0;"
      , "  for (i = a->length; i > 0; --i) {"
      , "    u[i - 1] = (a->limbs[i - 1] << shift) | (shift != 0 && i > 1 ? a->limbs[i - 2] >> (32 - shift) : 0);"
      , "  }"
      , "  q = pudu_big_new(m + 1);"
      , "  for (j = m + 1; j > 0; --j) {"
      , "    size_t at = j - 1;"
      , "    uint64_t numerator = ((uint64_t)u[at + n] << 32) | u[at + n - 1];"
      , "    uint64_t estimate = numerator / v[n - 1];"
      , "    uint64_t rest = numerator % v[n - 1];"
      , "    int64_t borrow = 0;"
      , "    uint64_t carry = 0;"
      , "    while (estimate > UINT32_MAX || estimate * v[n - 2] > ((rest << 32) | u[at + n - 2])) {"
      , "      estimate -= 1;"
      , "      rest += v[n - 1];"
      , "      if (rest > UINT32_MAX) break;"
      , "    }"
      , "    for (i = 0; i < n; ++i) {"
      , "      uint64_t product = estimate * v[i] + carry;"
      , "      int64_t total;"
      , "      carry = product >> 32;"
      , "      total = (int64_t)u[at + i] - borrow - (int64_t)(uint32_t)product;"
      , "      borrow = total < 0;"
      , "      u[at + i] = (uint32_t)(total + (borrow ? (INT64_C(1) << 32) : 0));"
      , "    }"
      , "    {"
      , "      int64_t total = (int64_t)u[at + n] - borrow - (int64_t)carry;"
      , "      borrow = total < 0;"
      , "      u[at + n] = (uint32_t)(total + (borrow ? (INT64_C(1) << 32) : 0));"
      , "    }"
      , "    if (borrow) {"
      , "      uint64_t add = 0;"
      , "      estimate -= 1;"
      , "      for (i = 0; i < n; ++i) {"
      , "        uint64_t total = (uint64_t)u[at + i] + v[i] + add;"
      , "        u[at + i] = (uint32_t)total;"
      , "        add = total >> 32;"
      , "      }"
      , "      u[at + n] = (uint32_t)((uint64_t)u[at + n] + add);"
      , "    }"
      , "    q->limbs[at] = (uint32_t)estimate;"
      , "  }"
      , "  {"
      , "    pudu_big *r = pudu_big_new(n);"
      , "    for (i = 0; i < n; ++i) {"
      , "      r->limbs[i] = (u[i] >> shift) | (shift != 0 ? u[i + 1] << (32 - shift) : 0);"
      , "    }"
      , "    *remainder = pudu_big_trim(r);"
      , "  }"
      , "  free(u);"
      , "  free(v);"
      , "  *quotient = pudu_big_trim(q);"
      , "}"
      ])
  , ("big_divide",
      [ "/* `quot` and `rem`: the quotient rounds toward zero and the remainder takes"
      , "   the dividend's sign. The divisor is not zero. */"
      , "static inline void pudu_big_divide(const pudu_big *a, const pudu_big *b, pudu_big **quotient, pudu_big **remainder) {"
      , "  pudu_big_divide_magnitude(a, b, quotient, remainder);"
      , "  if (*quotient != NULL) (*quotient)->negative = a->negative != b->negative;"
      , "  if (*remainder != NULL) (*remainder)->negative = a->negative;"
      , "}"
      ])
  , ("big_twos",
      [ "/* The two's-complement limbs of a value over `length` limbs, which must"
      , "   hold its magnitude and a sign limb. */"
      , "static inline void pudu_big_twos(const pudu_big *value, uint32_t *bits, size_t length) {"
      , "  size_t index;"
      , "  uint64_t carry = 1;"
      , "  int negative = value != NULL && value->negative;"
      , "  for (index = 0; index < length; ++index) {"
      , "    uint32_t limb = value != NULL && index < value->length ? value->limbs[index] : 0;"
      , "    if (negative) {"
      , "      uint64_t total = (uint64_t)(uint32_t)~limb + carry;"
      , "      bits[index] = (uint32_t)total;"
      , "      carry = total >> 32;"
      , "    } else {"
      , "      bits[index] = limb;"
      , "    }"
      , "  }"
      , "}"
      ])
  , ("big_from_twos",
      [ "/* A value back from two's-complement limbs, whose top bit is the sign. */"
      , "static inline pudu_big *pudu_big_from_twos(uint32_t *bits, size_t length) {"
      , "  int negative = length > 0 && (bits[length - 1] >> 31) != 0;"
      , "  size_t index;"
      , "  if (negative) {"
      , "    uint64_t carry = 1;"
      , "    for (index = 0; index < length; ++index) {"
      , "      uint64_t total = (uint64_t)(uint32_t)~bits[index] + carry;"
      , "      bits[index] = (uint32_t)total;"
      , "      carry = total >> 32;"
      , "    }"
      , "  }"
      , "  return pudu_big_from_limbs(negative, length, bits);"
      , "}"
      ])
  , ("big_bits",
      [ "/* `&`, `|` and `^` on the infinite two's-complement patterns. */"
      , "static inline pudu_big *pudu_big_bits(const pudu_big *a, const pudu_big *b, int operation) {"
      , "  size_t alength = a == NULL ? 0 : a->length;"
      , "  size_t blength = b == NULL ? 0 : b->length;"
      , "  size_t length = (alength > blength ? alength : blength) + 1;"
      , "  uint32_t *left = malloc(length * sizeof(uint32_t));"
      , "  uint32_t *right = malloc(length * sizeof(uint32_t));"
      , "  pudu_big *result;"
      , "  size_t index;"
      , "  if (left == NULL || right == NULL) pudu_memory_failure();"
      , "  pudu_big_twos(a, left, length);"
      , "  pudu_big_twos(b, right, length);"
      , "  for (index = 0; index < length; ++index) {"
      , "    left[index] = operation == 0 ? (left[index] & right[index])"
      , "      : operation == 1 ? (left[index] | right[index]) : (left[index] ^ right[index]);"
      , "  }"
      , "  result = pudu_big_from_twos(left, length);"
      , "  free(left);"
      , "  free(right);"
      , "  return result;"
      , "}"
      ])
  , ("bigint_not",
      [ "/* `~x` is `-x - 1`. */"
      , "static inline pudu_big *pudu_bigint_not(const pudu_big *a) {"
      , "  pudu_big *one = pudu_big_from_magnitude(0, 1);"
      , "  pudu_big *negated = pudu_bigint_neg(a);"
      , "  pudu_big *result = pudu_bigint_sub(negated, one);"
      , "  pudu_big_release(one);"
      , "  pudu_big_release(negated);"
      , "  return result;"
      , "}"
      ])
  , ("bigint_shift_left",
      [ "/* `a << places`: exact. */"
      , "static inline pudu_big *pudu_bigint_shift_left(const pudu_big *a, uint64_t places) {"
      , "  size_t words = (size_t)(places / 32), index;"
      , "  unsigned bits = (unsigned)(places % 32);"
      , "  pudu_big *result;"
      , "  if (a == NULL) return NULL;"
      , "  if (places / 32 > SIZE_MAX - a->length - 1) pudu_memory_failure();"
      , "  result = pudu_big_new(a->length + words + 1);"
      , "  memset(result->limbs, 0, result->length * sizeof(uint32_t));"
      , "  for (index = 0; index < a->length; ++index) {"
      , "    uint64_t moved = (uint64_t)a->limbs[index] << bits;"
      , "    result->limbs[index + words] |= (uint32_t)moved;"
      , "    result->limbs[index + words + 1] |= (uint32_t)(moved >> 32);"
      , "  }"
      , "  result->negative = a->negative;"
      , "  return pudu_big_trim(result);"
      , "}"
      ])
  , ("bigint_shift_right",
      [ "/* `a >> places`: arithmetic, so a negative value rounds toward negative"
      , "   infinity, as shifting its infinite two's-complement pattern does. */"
      , "static inline pudu_big *pudu_bigint_shift_right(const pudu_big *a, uint64_t places) {"
      , "  size_t words, index, length;"
      , "  unsigned bits;"
      , "  int dropped = 0;"
      , "  pudu_big *result;"
      , "  if (a == NULL) return NULL;"
      , "  if (places / 32 >= a->length) return a->negative ? pudu_big_from_magnitude(1, 1) : NULL;"
      , "  words = (size_t)(places / 32);"
      , "  bits = (unsigned)(places % 32);"
      , "  length = a->length - words;"
      , "  result = pudu_big_new(length);"
      , "  for (index = 0; index < words; ++index) dropped |= a->limbs[index] != 0;"
      , "  if (bits != 0) dropped |= (a->limbs[words] & ((UINT32_C(1) << bits) - 1)) != 0;"
      , "  for (index = 0; index < length; ++index) {"
      , "    uint64_t high = index + words + 1 < a->length ? a->limbs[index + words + 1] : 0;"
      , "    result->limbs[index] = (uint32_t)((((uint64_t)high << 32) | a->limbs[index + words]) >> bits);"
      , "  }"
      , "  result->negative = a->negative;"
      , "  result = pudu_big_trim(result);"
      , "  if (a->negative && dropped) {"
      , "    pudu_big *one = pudu_big_from_magnitude(1, 1);"
      , "    pudu_big *rounded = pudu_bigint_add(result, one);"
      , "    pudu_big_release(one);"
      , "    pudu_big_release(result);"
      , "    result = rounded;"
      , "  }"
      , "  return result;"
      , "}"
      ])
  , ("big_decimal",
      [ "/* Decimal digits, most significant first, with a leading '-' for a"
      , "   negative value. The buffer is the caller's to free. */"
      , "static inline char *pudu_big_decimal(const pudu_big *value, size_t *length) {"
      , "  size_t limbs = value == NULL ? 0 : value->length, capacity, used = 0, index;"
      , "  uint32_t *work;"
      , "  char *digits;"
      , "  if (limbs == 0) {"
      , "    digits = malloc(2);"
      , "    if (digits == NULL) pudu_memory_failure();"
      , "    digits[0] = '0'; digits[1] = 0;"
      , "    *length = 1;"
      , "    return digits;"
      , "  }"
      , "  if (limbs > (SIZE_MAX - 2) / 10) pudu_memory_failure();"
      , "  capacity = limbs * 10 + 2;"
      , "  work = malloc(limbs * sizeof(uint32_t));"
      , "  digits = malloc(capacity);"
      , "  if (work == NULL || digits == NULL) pudu_memory_failure();"
      , "  memcpy(work, value->limbs, limbs * sizeof(uint32_t));"
      , "  while (limbs > 0) {"
      , "    uint64_t rest = 0;"
      , "    int chunk;"
      , "    for (index = limbs; index > 0; --index) {"
      , "      uint64_t current = (rest << 32) | work[index - 1];"
      , "      work[index - 1] = (uint32_t)(current / 1000000000u);"
      , "      rest = current % 1000000000u;"
      , "    }"
      , "    while (limbs > 0 && work[limbs - 1] == 0) limbs -= 1;"
      , "    for (chunk = 0; chunk < 9 && (limbs > 0 || rest != 0); ++chunk) {"
      , "      digits[used++] = (char)('0' + rest % 10);"
      , "      rest /= 10;"
      , "    }"
      , "  }"
      , "  if (value->negative) digits[used++] = '-';"
      , "  for (index = 0; index < used / 2; ++index) {"
      , "    char held = digits[index];"
      , "    digits[index] = digits[used - 1 - index];"
      , "    digits[used - 1 - index] = held;"
      , "  }"
      , "  digits[used] = 0;"
      , "  free(work);"
      , "  *length = used;"
      , "  return digits;"
      , "}"
      ])
  ]

bigValueRuntimeDependencies :: Text -> [Text]
bigValueRuntimeDependencies name = maybe [] id (lookup name
  [ ("big_value", ["memory_failure"])
  , ("big_new", ["big_value", "memory_failure"])
  , ("big_retain", ["big_value"])
  , ("big_release", ["big_value"])
  , ("big_trim", ["big_value"])
  , ("big_from_limbs", ["big_value", "big_new", "big_trim"])
  , ("big_from_magnitude", ["big_value", "big_from_limbs"])
  , ("big_compare_magnitude", ["big_value"])
  , ("big_sign", ["big_value"])
  , ("big_compare", ["big_value", "big_compare_magnitude", "big_sign"])
  , ("big_add_magnitude", ["big_value", "big_new", "big_trim"])
  , ("big_subtract_magnitude", ["big_value", "big_new", "big_trim"])
  , ("big_signed_add", ["big_value", "big_add_magnitude", "big_compare_magnitude", "big_from_limbs", "big_retain", "big_subtract_magnitude"])
  , ("bigint_add", ["big_value", "big_signed_add"])
  , ("bigint_sub", ["big_value", "big_signed_add"])
  , ("bigint_neg", ["big_value", "big_from_limbs"])
  , ("bigint_mul", ["big_value", "big_new", "big_trim", "memory_failure"])
  , ("big_divide_magnitude", ["big_value", "big_compare_magnitude", "big_from_limbs", "big_from_magnitude", "big_new", "big_trim", "memory_failure"])
  , ("big_divide", ["big_value", "big_divide_magnitude"])
  , ("big_twos", ["big_value"])
  , ("big_from_twos", ["big_value", "big_from_limbs"])
  , ("big_bits", ["big_value", "big_from_twos", "big_twos", "memory_failure"])
  , ("bigint_not", ["big_value", "big_from_magnitude", "big_release", "bigint_neg", "bigint_sub"])
  , ("bigint_shift_left", ["big_value", "big_new", "big_trim", "memory_failure"])
  , ("bigint_shift_right", ["big_value", "big_from_magnitude", "big_new", "big_release", "big_trim", "bigint_add"])
  , ("big_decimal", ["big_value", "memory_failure"])
  ])
