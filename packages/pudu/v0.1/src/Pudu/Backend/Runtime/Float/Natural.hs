{-| @Pudu.Backend.Runtime.Float.Natural — checked scratch for decimal conversion. -}
module Pudu.Backend.Runtime.Float.Natural
  ( floatNaturalRuntimeParts, floatNaturalRuntimeDependencies ) where

import Data.Text (Text)

floatNaturalRuntimeParts :: [(Text, [Text])]
floatNaturalRuntimeParts =
  [ ("float_nat_value",
      [ "#define PUDU_FLOAT_NAT_WORDS 40"
      , "typedef struct { size_t length; uint32_t words[PUDU_FLOAT_NAT_WORDS]; } pudu_float_nat;"
      ])
  , ("float_nat_from_shift",
      [ "static inline int pudu_float_nat_from_shift(pudu_float_nat *out, uint64_t value, uint32_t shift) {"
      , "  pudu_float_nat result = {0};"
      , "  if (value == 0) { *out = result; return 1; }"
      , "  if (shift >= PUDU_FLOAT_NAT_WORDS * 32) return 0;"
      , "  size_t first = shift / 32; unsigned offset = shift % 32;"
      , "  for (unsigned i = 0; i < 2; ++i) {"
      , "    uint64_t word = (uint64_t)(uint32_t)(value >> (i * 32)) << offset;"
      , "    if (word == 0) continue;"
      , "    size_t index = first + i;"
      , "    if (index >= PUDU_FLOAT_NAT_WORDS) return 0;"
      , "    result.words[index] |= (uint32_t)word;"
      , "    if ((word >> 32) != 0) {"
      , "      if (index + 1 >= PUDU_FLOAT_NAT_WORDS) return 0;"
      , "      result.words[index + 1] |= (uint32_t)(word >> 32);"
      , "    }"
      , "  }"
      , "  result.length = PUDU_FLOAT_NAT_WORDS;"
      , "  while (result.length != 0 && result.words[result.length - 1] == 0) --result.length;"
      , "  *out = result; return 1;"
      , "}"
      ])
  , ("float_nat_compare",
      [ "static inline int pudu_float_nat_compare(const pudu_float_nat *a, const pudu_float_nat *b) {"
      , "  if (a->length != b->length) return a->length < b->length ? -1 : 1;"
      , "  for (size_t i = a->length; i != 0;) {"
      , "    --i; if (a->words[i] != b->words[i]) return a->words[i] < b->words[i] ? -1 : 1;"
      , "  }"
      , "  return 0;"
      , "}"
      ])
  , ("float_nat_add",
      [ "static inline int pudu_float_nat_add(pudu_float_nat *out, const pudu_float_nat *a, const pudu_float_nat *b) {"
      , "  pudu_float_nat result = {0}; uint64_t carry = 0;"
      , "  size_t count = a->length > b->length ? a->length : b->length;"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    uint64_t sum = carry + (i < a->length ? (uint64_t)a->words[i] : 0) + (i < b->length ? (uint64_t)b->words[i] : 0);"
      , "    result.words[i] = (uint32_t)sum; carry = sum >> 32;"
      , "  }"
      , "  if (carry != 0) {"
      , "    if (count == PUDU_FLOAT_NAT_WORDS) return 0;"
      , "    result.words[count++] = (uint32_t)carry;"
      , "  }"
      , "  result.length = count; *out = result; return 1;"
      , "}"
      ])
  , ("float_nat_sub",
      [ "static inline int pudu_float_nat_sub(pudu_float_nat *out, const pudu_float_nat *a, const pudu_float_nat *b) {"
      , "  if (pudu_float_nat_compare(a, b) < 0) return 0;"
      , "  pudu_float_nat result = {0}; uint64_t borrow = 0;"
      , "  for (size_t i = 0; i < a->length; ++i) {"
      , "    uint64_t right = (i < b->length ? (uint64_t)b->words[i] : 0) + borrow;"
      , "    uint64_t left = a->words[i];"
      , "    result.words[i] = (uint32_t)(left - right); borrow = left < right;"
      , "  }"
      , "  result.length = a->length;"
      , "  while (result.length != 0 && result.words[result.length - 1] == 0) --result.length;"
      , "  *out = result; return 1;"
      , "}"
      ])
  , ("float_nat_multiply_small",
      [ "static inline int pudu_float_nat_multiply_small(pudu_float_nat *out, const pudu_float_nat *a, uint32_t factor) {"
      , "  pudu_float_nat result = {0}; uint64_t carry = 0; size_t count = a->length;"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    uint64_t product = (uint64_t)a->words[i] * factor + carry;"
      , "    result.words[i] = (uint32_t)product; carry = product >> 32;"
      , "  }"
      , "  if (carry != 0) {"
      , "    if (count == PUDU_FLOAT_NAT_WORDS) return 0;"
      , "    result.words[count++] = (uint32_t)carry;"
      , "  }"
      , "  result.length = count;"
      , "  while (result.length != 0 && result.words[result.length - 1] == 0) --result.length;"
      , "  *out = result; return 1;"
      , "}"
      ])
  , ("float_nat_scale10",
      [ "static inline int pudu_float_nat_scale10(pudu_float_nat *out, const pudu_float_nat *a, uint32_t exponent) {"
      , "  pudu_float_nat result = *a;"
      , "  if (result.length != 0) {"
      , "    for (uint32_t i = 0; i < exponent; ++i) {"
      , "      if (!pudu_float_nat_multiply_small(&result, &result, 10)) return 0;"
      , "    }"
      , "  }"
      , "  *out = result; return 1;"
      , "}"
      ])
  , ("float_nat_digit",
      [ "static inline int pudu_float_nat_digit(pudu_float_nat *out, unsigned *digit, const pudu_float_nat *a, const pudu_float_nat *b) {"
      , "  if (b->length == 0) return 0;"
      , "  pudu_float_nat remainder = *a; unsigned quotient = 0;"
      , "  while (pudu_float_nat_compare(&remainder, b) >= 0) {"
      , "    if (quotient == 9) return 0;"
      , "    if (!pudu_float_nat_sub(&remainder, &remainder, b)) return 0;"
      , "    ++quotient;"
      , "  }"
      , "  *out = remainder; *digit = quotient; return 1;"
      , "}"
      ])
  ]

floatNaturalRuntimeDependencies :: Text -> [Text]
floatNaturalRuntimeDependencies name = maybe [] id (lookup name
  [ ("float_nat_from_shift", ["float_nat_value"])
  , ("float_nat_compare", ["float_nat_value"])
  , ("float_nat_add", ["float_nat_value"])
  , ("float_nat_sub", ["float_nat_compare"])
  , ("float_nat_multiply_small", ["float_nat_value"])
  , ("float_nat_scale10", ["float_nat_multiply_small"])
  , ("float_nat_digit", ["float_nat_compare", "float_nat_sub"])
  ])
