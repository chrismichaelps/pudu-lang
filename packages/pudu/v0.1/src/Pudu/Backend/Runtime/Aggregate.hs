{-| @Pudu.Backend.Runtime.Aggregate — text building shared by aggregate rendering. -}
module Pudu.Backend.Runtime.Aggregate (aggregateRuntimeParts, aggregateRuntimeDependencies) where

import Data.Text (Text)

aggregateRuntimeParts :: [(Text, [Text])]
aggregateRuntimeParts =
  [ ("text_join",
      [ "/* open, the parts separated by \", \" and each after its label, then close."
      , "   labels may be NULL. Takes the parts' references. */"
      , "static pudu_text pudu_text_join(const char *open, const char *const *labels, pudu_text *parts, size_t count, const char *close) {"
      , "  size_t opening = strlen(open), closing = strlen(close), length = opening;"
      , "  unsigned char *bytes;"
      , "  pudu_text joined;"
      , "  if (closing > SIZE_MAX - length) pudu_memory_failure();"
      , "  length += closing;"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    size_t separator = i == 0 ? 0 : 2;"
      , "    size_t label = labels == NULL ? 0 : strlen(labels[i]);"
      , "    if (parts[i].length > SIZE_MAX - length) pudu_memory_failure();"
      , "    length += parts[i].length;"
      , "    if (separator > SIZE_MAX - length) pudu_memory_failure();"
      , "    length += separator;"
      , "    if (label > SIZE_MAX - length) pudu_memory_failure();"
      , "    length += label;"
      , "  }"
      , "  /* Preserve the delimiter bound across the variable-length loop. */"
      , "  if (length < opening || closing > length - opening) pudu_memory_failure();"
      , "  joined = pudu_text_allocate(length, &bytes);"
      , "  memcpy(bytes, open, opening);"
      , "  bytes += opening;"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    if (i != 0) { *bytes++ = ','; *bytes++ = ' '; }"
      , "    if (labels != NULL) { size_t label = strlen(labels[i]); memcpy(bytes, labels[i], label); bytes += label; }"
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
