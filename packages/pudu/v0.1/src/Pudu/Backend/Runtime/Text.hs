{-| @Pudu.Backend.Runtime.Text — owned text views, rendering and printing. -}
module Pudu.Backend.Runtime.Text (textRuntimeParts, textRuntimeDependencies) where

import Data.Text (Text)

textRuntimeParts :: [(Text, [Text])]
textRuntimeParts =
  [ ("text",
      [ "/* A text is a view; owner is NULL for literal bytes. */"
      , "typedef struct { size_t count; unsigned char bytes[]; } pudu_text_owner;"
      , "typedef struct { const unsigned char *bytes; size_t length; pudu_text_owner *owner; } pudu_text;"
      , "static inline void pudu_text_release(pudu_text text) {"
      , "  if (text.owner != NULL && --text.owner->count == 0) free(text.owner);"
      , "}"
      ])
  , ("text_retain",
      [ "static inline pudu_text pudu_text_retain(pudu_text text) {"
      , "  if (text.owner != NULL) text.owner->count += 1;"
      , "  return text;"
      , "}"
      ])
  , ("text_literal",
      [ "static inline pudu_text pudu_text_literal(const char *bytes, size_t length) {"
      , "  pudu_text text = {(const unsigned char *)bytes, length, NULL};"
      , "  return text;"
      , "}"
      ])
  , ("text_allocate",
      [ "/* Room for length bytes, filled by the caller before the text is read. */"
      , "static pudu_text pudu_text_allocate(size_t length, unsigned char **bytes) {"
      , "  pudu_text_owner *owner;"
      , "  pudu_text text;"
      , "  if (length > SIZE_MAX - sizeof(pudu_text_owner) - 1) pudu_memory_failure();"
      , "  owner = malloc(sizeof(pudu_text_owner) + (length == 0 ? 1 : length));"
      , "  if (owner == NULL) pudu_memory_failure();"
      , "  owner->count = 1;"
      , "  *bytes = owner->bytes;"
      , "  text.bytes = owner->bytes;"
      , "  text.length = length;"
      , "  text.owner = owner;"
      , "  return text;"
      , "}"
      ])
  , ("text_concat",
      [ "static pudu_text pudu_text_concat(pudu_text left, pudu_text right) {"
      , "  unsigned char *bytes;"
      , "  pudu_text text;"
      , "  if (right.length == 0) return pudu_text_retain(left);"
      , "  if (left.length == 0) return pudu_text_retain(right);"
      , "  if (left.length > SIZE_MAX - right.length) pudu_memory_failure();"
      , "  text = pudu_text_allocate(left.length + right.length, &bytes);"
      , "  memcpy(bytes, left.bytes, left.length);"
      , "  memcpy(bytes + left.length, right.bytes, right.length);"
      , "  return text;"
      , "}"
      ])
  , ("text_compare",
      [ "/* Data.Text orders UTF-8 by bytes, which is scalar order. */"
      , "static inline int pudu_text_compare(pudu_text left, pudu_text right) {"
      , "  size_t shorter = left.length < right.length ? left.length : right.length;"
      , "  int order = shorter == 0 ? 0 : memcmp(left.bytes, right.bytes, shorter);"
      , "  if (order != 0) return order < 0 ? -1 : 1;"
      , "  return (left.length > right.length) - (left.length < right.length);"
      , "}"
      ])
  , ("text_show",
      [ "/* renderValue's quoting: only backslash, quote, tab and newline escape. */"
      , "static pudu_text pudu_text_show(pudu_text text) {"
      , "  size_t extra = 2, index;"
      , "  unsigned char *bytes;"
      , "  pudu_text shown;"
      , "  for (index = 0; index < text.length; ++index) {"
      , "    unsigned char byte = text.bytes[index];"
      , "    if (byte == '\\\\' || byte == '\"' || byte == '\\t' || byte == '\\n') {"
      , "      if (extra == SIZE_MAX) pudu_memory_failure();"
      , "      extra += 1;"
      , "    }"
      , "  }"
      , "  if (text.length > SIZE_MAX - extra) pudu_memory_failure();"
      , "  shown = pudu_text_allocate(text.length + extra, &bytes);"
      , "  *bytes++ = '\"';"
      , "  for (index = 0; index < text.length; ++index) {"
      , "    unsigned char byte = text.bytes[index];"
      , "    switch (byte) {"
      , "      case '\\\\': *bytes++ = '\\\\'; *bytes++ = '\\\\'; break;"
      , "      case '\"': *bytes++ = '\\\\'; *bytes++ = '\"'; break;"
      , "      case '\\t': *bytes++ = '\\\\'; *bytes++ = 't'; break;"
      , "      case '\\n': *bytes++ = '\\\\'; *bytes++ = 'n'; break;"
      , "      default: *bytes++ = byte;"
      , "    }"
      , "  }"
      , "  *bytes = '\"';"
      , "  return shown;"
      , "}"
      ])
  , ("text_copy",
      [ "static pudu_text pudu_text_copy(const char *source, size_t length) {"
      , "  unsigned char *bytes;"
      , "  pudu_text text = pudu_text_allocate(length, &bytes);"
      , "  memcpy(bytes, source, length);"
      , "  return text;"
      , "}"
      ])
  , ("text_display_int",
      [ "static pudu_text pudu_text_display_int(pudu_int value) {"
      , "  char buffer[24], *end = buffer + sizeof buffer, *cursor = end;"
      , "  uint64_t magnitude = pudu_magnitude(value);"
      , "  do { *--cursor = (char)('0' + magnitude % 10); magnitude /= 10; } while (magnitude != 0);"
      , "  if (value.negative) *--cursor = '-';"
      , "  return pudu_text_copy(cursor, (size_t)(end - cursor));"
      , "}"
      ])
  , ("text_display_wide",
      [ "static pudu_text pudu_text_display_wide(pudu_wide_int value) {"
      , "  char buffer[41], *end = buffer + sizeof buffer, *cursor = end;"
      , "  pudu_word128 magnitude;"
      , "  value = pudu_wide_normal(value);"
      , "  magnitude = pudu_wide_magnitude(value);"
      , "  do {"
      , "    pudu_word128_division digit = pudu_word128_divide(magnitude, (pudu_word128){10, 0});"
      , "    *--cursor = (char)('0' + digit.remainder.low);"
      , "    magnitude = digit.quotient;"
      , "  } while (!pudu_word128_zero(magnitude));"
      , "  if (value.negative) *--cursor = '-';"
      , "  return pudu_text_copy(cursor, (size_t)(end - cursor));"
      , "}"
      ])
  , ("text_display_float",
      [ "static pudu_text pudu_text_display_float(uint64_t bits) {"
      , "  char buffer[32];"
      , "  size_t count = pudu_format_float64(bits, buffer);"
      , "  return pudu_text_copy(buffer, count);"
      , "}"
      ])
  , ("print_text",
      [ "static inline void pudu_print_text(pudu_text text) {"
      , "  if (text.length != 0) (void)fwrite(text.bytes, 1, text.length, stdout);"
      , "  (void)fputc('\\n', stdout);"
      , "  (void)fflush(stdout);"
      , "}"
      ])
  ]

textRuntimeDependencies :: Text -> [Text]
textRuntimeDependencies name = maybe [] id (lookup name
  [ ("text_literal", ["text"])
  , ("text_retain", ["text"])
  , ("text_allocate", ["text", "memory_failure"])
  , ("text_concat", ["text_allocate", "text_retain"])
  , ("text_compare", ["text"])
  , ("text_show", ["text_allocate"])
  , ("text_copy", ["text_allocate"])
  , ("text_display_int", ["text_copy", "magnitude"])
  , ("text_display_wide", ["text_copy", "wide_normal", "wide_magnitude", "word128_divide", "word128_zero"])
  , ("text_display_float", ["text_copy", "float_format"])
  , ("print_text", ["text"])
  ])
