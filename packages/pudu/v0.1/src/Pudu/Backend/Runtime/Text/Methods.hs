{-| @Pudu.Backend.Runtime.Text.Methods — the built-in Str methods, by scalar. -}
module Pudu.Backend.Runtime.Text.Methods (textMethodRuntimeParts, textMethodRuntimeDependencies) where

import Data.Text (Text)

textMethodRuntimeParts :: [(Text, [Text])]
textMethodRuntimeParts =
  [ ("text_width",
      [ "/* Text is valid UTF-8, so a leader byte gives the scalar's width. */"
      , "static inline size_t pudu_text_width(unsigned char leader) {"
      , "  return leader < 0x80 ? 1 : leader < 0xE0 ? 2 : leader < 0xF0 ? 3 : 4;"
      , "}"
      ])
  , ("text_scalars",
      [ "static size_t pudu_text_scalars(const unsigned char *bytes, size_t length) {"
      , "  size_t count = 0;"
      , "  for (size_t i = 0; i < length; ++i) count += (bytes[i] & 0xC0) != 0x80;"
      , "  return count;"
      , "}"
      ])
  , ("text_advance",
      [ "/* The byte offset after count scalars, or the end when the text is shorter. */"
      , "static size_t pudu_text_advance(pudu_text text, uint64_t count) {"
      , "  size_t offset = 0;"
      , "  while (count != 0 && offset < text.length) {"
      , "    offset += pudu_text_width(text.bytes[offset]);"
      , "    count -= 1;"
      , "  }"
      , "  return offset < text.length ? offset : text.length;"
      , "}"
      ])
  , ("text_decode",
      [ "static uint32_t pudu_text_decode(const unsigned char *bytes, size_t *offset) {"
      , "  unsigned char leader = bytes[*offset];"
      , "  size_t width = pudu_text_width(leader);"
      , "  uint32_t scalar = width == 1 ? leader : width == 2 ? (uint32_t)(leader & 0x1F)"
      , "    : width == 3 ? (uint32_t)(leader & 0x0F) : (uint32_t)(leader & 0x07);"
      , "  for (size_t i = 1; i < width; ++i) scalar = (scalar << 6) | (uint32_t)(bytes[*offset + i] & 0x3F);"
      , "  *offset += width;"
      , "  return scalar;"
      , "}"
      ])
  , ("text_view",
      [ "static inline pudu_text pudu_text_view(pudu_text text, size_t start, size_t end) {"
      , "  pudu_text view = {text.bytes + start, end - start, text.owner};"
      , "  return pudu_text_retain(view);"
      , "}"
      ])
  , ("text_length",
      [ "static inline pudu_int pudu_text_length(pudu_text text) {"
      , "  return pudu_make((uint64_t)pudu_text_scalars(text.bytes, text.length), 0);"
      , "}"
      ])
  , ("text_is_empty",
      [ "static inline int pudu_text_is_empty(pudu_text text) { return text.length == 0; }" ])
  , ("text_find",
      [ "/* First byte offset of needle, or SIZE_MAX; an empty needle is found at 0. */"
      , "static size_t pudu_text_find(pudu_text text, pudu_text needle, size_t from) {"
      , "  if (needle.length == 0) return from;"
      , "  if (needle.length > text.length) return SIZE_MAX;"
      , "  for (size_t i = from; i + needle.length <= text.length; ++i) {"
      , "    if (text.bytes[i] == needle.bytes[0] && memcmp(text.bytes + i, needle.bytes, needle.length) == 0) return i;"
      , "  }"
      , "  return SIZE_MAX;"
      , "}"
      ])
  , ("text_contains",
      [ "static inline int pudu_text_contains(pudu_text text, pudu_text needle) {"
      , "  return pudu_text_find(text, needle, 0) != SIZE_MAX;"
      , "}"
      ])
  , ("text_starts_with",
      [ "static inline int pudu_text_starts_with(pudu_text text, pudu_text prefix) {"
      , "  return prefix.length == 0 || (prefix.length <= text.length && memcmp(text.bytes, prefix.bytes, prefix.length) == 0);"
      , "}"
      ])
  , ("text_ends_with",
      [ "static inline int pudu_text_ends_with(pudu_text text, pudu_text suffix) {"
      , "  return suffix.length == 0 || (suffix.length <= text.length"
      , "    && memcmp(text.bytes + text.length - suffix.length, suffix.bytes, suffix.length) == 0);"
      , "}"
      ])
  , ("text_index_of",
      [ "static pudu_int pudu_text_index_of(pudu_text text, pudu_text needle) {"
      , "  size_t found = pudu_text_find(text, needle, 0);"
      , "  if (found == SIZE_MAX) return pudu_make(1, 1);"
      , "  return pudu_make((uint64_t)pudu_text_scalars(text.bytes, found), 0);"
      , "}"
      ])
  , ("text_drop",
      [ "static pudu_text pudu_text_drop(pudu_text text, pudu_int count, const pudu_site *negative) {"
      , "  if (count.negative) pudu_fail(negative);"
      , "  return pudu_text_view(text, pudu_text_advance(text, pudu_magnitude(count)), text.length);"
      , "}"
      ])
  , ("text_take",
      [ "static pudu_text pudu_text_take(pudu_text text, pudu_int count, const pudu_site *negative) {"
      , "  if (count.negative) pudu_fail(negative);"
      , "  return pudu_text_view(text, 0, pudu_text_advance(text, pudu_magnitude(count)));"
      , "}"
      ])
  , ("text_slice",
      [ "/* Both bounds clamp into the text, and an end before the start is empty. */"
      , "static pudu_text pudu_text_slice(pudu_text text, pudu_int from, pudu_int to) {"
      , "  uint64_t size = (uint64_t)pudu_text_scalars(text.bytes, text.length);"
      , "  uint64_t start = from.negative ? 0 : pudu_magnitude(from) < size ? pudu_magnitude(from) : size;"
      , "  uint64_t end = to.negative ? start : pudu_magnitude(to) < size ? pudu_magnitude(to) : size;"
      , "  size_t first, last;"
      , "  if (end < start) end = start;"
      , "  first = pudu_text_advance(text, start);"
      , "  last = pudu_text_advance(text, end);"
      , "  return pudu_text_view(text, first, last);"
      , "}"
      ])
  , ("text_repeat",
      [ "static pudu_text pudu_text_repeat(pudu_text text, pudu_int count, const pudu_site *negative, const pudu_site *limit) {"
      , "  unsigned char *bytes;"
      , "  pudu_text repeated;"
      , "  uint64_t times;"
      , "  if (count.negative) pudu_fail(negative);"
      , "  times = pudu_magnitude(count);"
      , "  if (times == 0 || text.length == 0) return pudu_text_literal(\"\", 0);"
      , "  /* The evaluator's limit is maxBound :: Int bytes. */"
      , "  if (times > (uint64_t)INT64_MAX / text.length) pudu_fail(limit);"
      , "  if (times > SIZE_MAX / text.length) pudu_memory_failure();"
      , "  repeated = pudu_text_allocate((size_t)times * text.length, &bytes);"
      , "  for (uint64_t i = 0; i < times; ++i) memcpy(bytes + i * text.length, text.bytes, text.length);"
      , "  return repeated;"
      , "}"
      ])
  , ("text_reverse",
      [ "static pudu_text pudu_text_reverse(pudu_text text) {"
      , "  unsigned char *bytes;"
      , "  pudu_text reversed;"
      , "  size_t offset = 0;"
      , "  if (text.length == 0) return pudu_text_retain(text);"
      , "  reversed = pudu_text_allocate(text.length, &bytes);"
      , "  while (offset < text.length) {"
      , "    size_t width = pudu_text_width(text.bytes[offset]);"
      , "    memcpy(bytes + text.length - offset - width, text.bytes + offset, width);"
      , "    offset += width;"
      , "  }"
      , "  return reversed;"
      , "}"
      ])
  , ("text_escape_html",
      [ "static pudu_text pudu_text_escape_html(pudu_text text) {"
      , "  static const char *const entities[] = {\"&amp;\", \"&lt;\", \"&gt;\", \"&quot;\", \"&#39;\"};"
      , "  static const char marks[] = {'&', '<', '>', '\"', '\\''};"
      , "  size_t size = text.length;"
      , "  unsigned char *bytes;"
      , "  pudu_text escaped;"
      , "  for (size_t i = 0; i < text.length; ++i) {"
      , "    for (size_t k = 0; k < sizeof marks; ++k) {"
      , "      if (text.bytes[i] == (unsigned char)marks[k]) {"
      , "        size_t grow = strlen(entities[k]) - 1;"
      , "        if (size > SIZE_MAX - grow) pudu_memory_failure();"
      , "        size += grow;"
      , "      }"
      , "    }"
      , "  }"
      , "  if (size == text.length) return pudu_text_retain(text);"
      , "  escaped = pudu_text_allocate(size, &bytes);"
      , "  for (size_t i = 0; i < text.length; ++i) {"
      , "    size_t k = 0;"
      , "    while (k < sizeof marks && text.bytes[i] != (unsigned char)marks[k]) ++k;"
      , "    if (k == sizeof marks) { *bytes++ = text.bytes[i]; continue; }"
      , "    memcpy(bytes, entities[k], strlen(entities[k]));"
      , "    bytes += strlen(entities[k]);"
      , "  }"
      , "  return escaped;"
      , "}"
      ])
  , ("text_replace",
      [ "/* Non-overlapping matches, left to right, as Data.Text.replace finds them. */"
      , "static pudu_text pudu_text_replace(pudu_text text, pudu_text needle, pudu_text replacement) {"
      , "  size_t matches = 0, from = 0, found, size, cursor = 0;"
      , "  unsigned char *bytes;"
      , "  pudu_text replaced;"
      , "  if (needle.length == 0) return pudu_text_retain(text);"
      , "  while ((found = pudu_text_find(text, needle, from)) != SIZE_MAX) { matches += 1; from = found + needle.length; }"
      , "  if (matches == 0) return pudu_text_retain(text);"
      , "  size = text.length - matches * needle.length;"
      , "  if (replacement.length != 0 && matches > (SIZE_MAX - size) / replacement.length) pudu_memory_failure();"
      , "  size += matches * replacement.length;"
      , "  replaced = pudu_text_allocate(size, &bytes);"
      , "  from = 0;"
      , "  while ((found = pudu_text_find(text, needle, from)) != SIZE_MAX) {"
      , "    memcpy(bytes + cursor, text.bytes + from, found - from);"
      , "    cursor += found - from;"
      , "    if (replacement.length != 0) memcpy(bytes + cursor, replacement.bytes, replacement.length);"
      , "    cursor += replacement.length;"
      , "    from = found + needle.length;"
      , "  }"
      , "  if (text.length != from) memcpy(bytes + cursor, text.bytes + from, text.length - from);"
      , "  return replaced;"
      , "}"
      ])
  , ("text_span",
      [ "/* Leading scalars that are (accept) or are not (!accept) in the alphabet. */"
      , "static pudu_int pudu_text_span(pudu_text text, pudu_text alphabet, int accept) {"
      , "  size_t offset = 0;"
      , "  uint64_t count = 0;"
      , "  while (offset < text.length) {"
      , "    size_t next = offset, letter = 0;"
      , "    uint32_t scalar = pudu_text_decode(text.bytes, &next);"
      , "    int member = 0;"
      , "    while (letter < alphabet.length && !member) member = pudu_text_decode(alphabet.bytes, &letter) == scalar;"
      , "    if (member != accept) break;"
      , "    offset = next;"
      , "    count += 1;"
      , "  }"
      , "  return pudu_make(count, 0);"
      , "}"
      ])
  ]

textMethodRuntimeDependencies :: Text -> [Text]
textMethodRuntimeDependencies name = maybe [] id (lookup name
  [ ("text_width", ["text"])
  , ("text_scalars", ["text"])
  , ("text_advance", ["text_width"])
  , ("text_decode", ["text_width"])
  , ("text_view", ["text_retain"])
  , ("text_length", ["text_scalars", "make"])
  , ("text_is_empty", ["text"])
  , ("text_find", ["text"])
  , ("text_contains", ["text_find"])
  , ("text_starts_with", ["text"])
  , ("text_ends_with", ["text"])
  , ("text_index_of", ["text_find", "text_scalars", "make"])
  , ("text_drop", ["text_view", "text_advance", "magnitude", "fail"])
  , ("text_take", ["text_view", "text_advance", "magnitude", "fail"])
  , ("text_slice", ["text_view", "text_scalars", "text_advance", "magnitude"])
  , ("text_repeat", ["text_allocate", "text_literal", "magnitude", "fail"])
  , ("text_reverse", ["text_allocate", "text_width", "text_retain"])
  , ("text_escape_html", ["text_allocate", "text_retain"])
  , ("text_replace", ["text_allocate", "text_find", "text_retain"])
  , ("text_span", ["text_decode", "make"])
  ])
