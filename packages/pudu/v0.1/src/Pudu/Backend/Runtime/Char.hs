{-| @Pudu.Backend.Runtime.Char — Char scalars: text, quoting, printing and charAt. -}
module Pudu.Backend.Runtime.Char (charRuntimeParts, charRuntimeDependencies) where

import Data.Text (Text)

{-| A Char is a `uint32_t` scalar. The checker never lets a surrogate or a
    value past U+10FFFF become one, so nothing here re-validates it. -}
charRuntimeParts :: [(Text, [Text])]
charRuntimeParts =
  [ ("char_text",
      [ "static pudu_text pudu_char_text(uint32_t scalar) {"
      , "  unsigned char bytes[4];"
      , "  return pudu_text_copy((const char *)bytes, pudu_text_encode(scalar, bytes));"
      , "}"
      ])
  , ("char_show",
      [ "/* renderValue on a Char: the string escapes, plus a quote written as '\\''. */"
      , "static pudu_text pudu_char_show(uint32_t scalar) {"
      , "  unsigned char bytes[8];"
      , "  size_t count = 0;"
      , "  bytes[count++] = '\\'';"
      , "  switch (scalar) {"
      , "    case '\\'': case '\\\\': case '\"': bytes[count++] = '\\\\'; bytes[count++] = (unsigned char)scalar; break;"
      , "    case '\\t': bytes[count++] = '\\\\'; bytes[count++] = 't'; break;"
      , "    case '\\n': bytes[count++] = '\\\\'; bytes[count++] = 'n'; break;"
      , "    default: count += pudu_text_encode(scalar, bytes + count);"
      , "  }"
      , "  bytes[count++] = '\\'';"
      , "  return pudu_text_copy((const char *)bytes, count);"
      , "}"
      ])
  , ("print_char",
      [ "static inline void pudu_print_char(uint32_t scalar) {"
      , "  unsigned char bytes[5];"
      , "  size_t count = pudu_text_encode(scalar, bytes);"
      , "  bytes[count++] = '\\n';"
      , "  fwrite(bytes, 1, count, stdout);"
      , "  fflush(stdout);"
      , "}"
      ])
  , ("text_char_at",
      [ "/* charAtFast: a negative index or one at or past the scalar count fails. */"
      , "static uint32_t pudu_text_char_at(pudu_text text, pudu_int index, const pudu_site *range) {"
      , "  uint64_t remaining;"
      , "  size_t offset = 0;"
      , "  if (index.negative) pudu_fail(range);"
      , "  remaining = pudu_magnitude(index);"
      , "  while (remaining != 0 && offset < text.length) {"
      , "    offset += pudu_text_width(text.bytes[offset]);"
      , "    remaining -= 1;"
      , "  }"
      , "  if (offset >= text.length) pudu_fail(range);"
      , "  return pudu_text_decode(text.bytes, &offset);"
      , "}"
      ])
  ]

charRuntimeDependencies :: Text -> [Text]
charRuntimeDependencies name = maybe [] id (lookup name
  [ ("char_text", ["text_copy", "text_encode"])
  , ("char_show", ["text_copy", "text_encode"])
  , ("print_char", ["text_encode"])
  , ("text_char_at", ["text_width", "text_decode", "magnitude", "fail"])
  ])
