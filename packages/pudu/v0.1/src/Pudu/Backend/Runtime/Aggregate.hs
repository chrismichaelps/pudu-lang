{-| @Pudu.Backend.Runtime.Aggregate — text building shared by aggregate rendering. -}
module Pudu.Backend.Runtime.Aggregate (aggregateRuntimeParts, aggregateRuntimeDependencies) where

import Data.Text (Text)

aggregateRuntimeParts :: [(Text, [Text])]
aggregateRuntimeParts =
  [ ("text_join",
      [ "/* open, the parts separated by \", \", then close. Takes the parts' references. */"
      , "static pudu_text pudu_text_join(const char *open, pudu_text *parts, size_t count, const char *close) {"
      , "  size_t opening = strlen(open), closing = strlen(close), length = opening + closing;"
      , "  unsigned char *bytes;"
      , "  pudu_text joined;"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    size_t extra = parts[i].length + (i == 0 ? 0 : 2);"
      , "    if (length > SIZE_MAX - extra) pudu_memory_failure();"
      , "    length += extra;"
      , "  }"
      , "  joined = pudu_text_allocate(length, &bytes);"
      , "  memcpy(bytes, open, opening);"
      , "  bytes += opening;"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    if (i != 0) { *bytes++ = ','; *bytes++ = ' '; }"
      , "    if (parts[i].length != 0) memcpy(bytes, parts[i].bytes, parts[i].length);"
      , "    bytes += parts[i].length;"
      , "    pudu_text_release(parts[i]);"
      , "  }"
      , "  memcpy(bytes, close, closing);"
      , "  return joined;"
      , "}"
      ])
  , ("float_order",
      [ "/* compareFloat: NaN equals NaN and sorts after every number. */"
      , "static int pudu_float_order(uint64_t a, uint64_t b) {"
      , "  int left = (a & UINT64_C(0x7FFFFFFFFFFFFFFF)) > UINT64_C(0x7FF0000000000000);"
      , "  int right = (b & UINT64_C(0x7FFFFFFFFFFFFFFF)) > UINT64_C(0x7FF0000000000000);"
      , "  if (left || right) return left - right;"
      , "  return pudu_float_lt(a, b) ? -1 : pudu_float_eq(a, b) ? 0 : 1;"
      , "}"
      ])
  ]

aggregateRuntimeDependencies :: Text -> [Text]
aggregateRuntimeDependencies name = maybe [] id (lookup name
  [ ("text_join", ["text_allocate"])
  , ("float_order", ["float_lt", "float_eq"]) ])
