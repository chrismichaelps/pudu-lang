{-| @Pudu.Backend.Runtime.Text.Number — `toInt` and `toFloat`, read the way
    `Eval.Builtin.TextNumber` reads them. Each comes as a test and a read, and
    lowering wraps the read in `Some` only when the test passes. -}
module Pudu.Backend.Runtime.Text.Number (textNumberRuntimeParts, textNumberRuntimeDependencies) where

import Data.Text (Text)

textNumberRuntimeParts :: [(Text, [Text])]
textNumberRuntimeParts =
  [ ("text_int_read",
      [ "/* readWhole: a sign, then one or more ASCII digits, inside Int. */"
      , "static int pudu_text_int_read(pudu_text text, pudu_int *out) {"
      , "  size_t i = 0;"
      , "  int negative = 0;"
      , "  uint64_t magnitude = 0;"
      , "  if (text.length == 0) return 0;"
      , "  if (text.bytes[0] == '-' || text.bytes[0] == '+') { negative = text.bytes[0] == '-'; i = 1; }"
      , "  if (i == text.length) return 0;"
      , "  for (; i < text.length; ++i) {"
      , "    uint64_t digit;"
      , "    if (text.bytes[i] < '0' || text.bytes[i] > '9') return 0;"
      , "    digit = (uint64_t)(text.bytes[i] - '0');"
      , "    /* 2^63 is as far as a negative Int reaches. */"
      , "    if (magnitude > (UINT64_C(9223372036854775808) - digit) / 10) return 0;"
      , "    magnitude = magnitude * 10 + digit;"
      , "  }"
      , "  if (!negative && magnitude > UINT64_C(9223372036854775807)) return 0;"
      , "  *out = pudu_make(magnitude, negative && magnitude != 0);"
      , "  return 1;"
      , "}"
      , "static int pudu_text_parses_int(pudu_text text) {"
      , "  pudu_int ignored;"
      , "  return pudu_text_int_read(text, &ignored);"
      , "}"
      , "static pudu_int pudu_text_int_of(pudu_text text) {"
      , "  pudu_int value = pudu_make(0, 0);"
      , "  (void)pudu_text_int_read(text, &value);"
      , "  return value;"
      , "}"
      ])
  , ("text_float_read",
      [ "/* readFloat: check the shape, then hand strtod only the digits it allowed,"
      , "   so locale, hex floats, inf and nan never reach it. */"
      , "static int pudu_text_float_read(pudu_text text, uint64_t *out) {"
      , "  const unsigned char *bytes = text.bytes;"
      , "  size_t i = 0, whole, fraction = 0, point = SIZE_MAX, exponent = SIZE_MAX, digits = 0, at = 0;"
      , "  int negative = 0, exponent_negative = 0;"
      , "  char *normal;"
      , "  double value;"
      , "  uint64_t bits;"
      , "  if (text.length == 0) return 0;"
      , "  if (bytes[0] == '-' || bytes[0] == '+') { negative = bytes[0] == '-'; i = 1; }"
      , "  whole = i;"
      , "  while (i < text.length && bytes[i] >= '0' && bytes[i] <= '9') i += 1;"
      , "  whole = i - whole;"
      , "  if (i < text.length && bytes[i] == '.') {"
      , "    point = i;"
      , "    i += 1;"
      , "    while (i < text.length && bytes[i] >= '0' && bytes[i] <= '9') { i += 1; fraction += 1; }"
      , "  }"
      , "  if (whole == 0 && fraction == 0) return 0;"
      , "  if (i < text.length) {"
      , "    if (bytes[i] != 'e' && bytes[i] != 'E') return 0;"
      , "    i += 1;"
      , "    if (i < text.length && (bytes[i] == '-' || bytes[i] == '+')) { exponent_negative = bytes[i] == '-'; i += 1; }"
      , "    exponent = i;"
      , "    while (i < text.length && bytes[i] >= '0' && bytes[i] <= '9') { i += 1; digits += 1; }"
      , "    if (i != text.length || digits == 0 || digits > 6) return 0;"
      , "  }"
      , "  normal = malloc(text.length + 8);"
      , "  if (normal == NULL) pudu_memory_failure();"
      , "  {"
      , "    size_t start = (bytes[0] == '-' || bytes[0] == '+') ? 1 : 0;"
      , "    if (whole == 0) normal[at++] = '0';"
      , "    else { memcpy(normal + at, bytes + start, whole); at += whole; }"
      , "    normal[at++] = '.';"
      , "    if (fraction == 0) normal[at++] = '0';"
      , "    else { memcpy(normal + at, bytes + point + 1, fraction); at += fraction; }"
      , "    if (exponent != SIZE_MAX) {"
      , "      normal[at++] = 'e';"
      , "      if (exponent_negative) normal[at++] = '-';"
      , "      memcpy(normal + at, bytes + exponent, digits);"
      , "      at += digits;"
      , "    }"
      , "    normal[at] = '\\0';"
      , "  }"
      , "  value = strtod(normal, NULL);"
      , "  free(normal);"
      , "  memcpy(&bits, &value, sizeof bits);"
      , "  /* An all-ones exponent is an infinity; the digits can't spell a NaN. */"
      , "  if ((bits & UINT64_C(0x7ff0000000000000)) == UINT64_C(0x7ff0000000000000)) return 0;"
      , "  if (negative) bits ^= UINT64_C(0x8000000000000000);"
      , "  *out = bits;"
      , "  return 1;"
      , "}"
      , "static int pudu_text_parses_float(pudu_text text) {"
      , "  uint64_t ignored;"
      , "  return pudu_text_float_read(text, &ignored);"
      , "}"
      , "static uint64_t pudu_text_float_of(pudu_text text) {"
      , "  uint64_t bits = 0;"
      , "  (void)pudu_text_float_read(text, &bits);"
      , "  return bits;"
      , "}"
      ])
  ]

textNumberRuntimeDependencies :: Text -> [Text]
textNumberRuntimeDependencies name = maybe [] id (lookup name
  [ ("text_int_read", ["text", "make"])
  , ("text_float_read", ["text", "memory_failure"])
  -- The emitter asks for a function by its own name.
  , ("text_parses_int", ["text_int_read"])
  , ("text_int_of", ["text_int_read"])
  , ("text_parses_float", ["text_float_read"])
  , ("text_float_of", ["text_float_read"])
  ])
