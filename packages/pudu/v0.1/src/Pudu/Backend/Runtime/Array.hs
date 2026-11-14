{-| @Pudu.Backend.Runtime.Array — the item buffer behind every array.

    An array is a box whose one field points at its items. The box is what
    slots hold and count; the items grow in place only while the box has one
    owner, so nobody else can see a buffer change under it. -}
module Pudu.Backend.Runtime.Array (arrayRuntimeParts, arrayRuntimeDependencies) where

import Data.Text (Text)

arrayRuntimeParts :: [(Text, [Text])]
arrayRuntimeParts =
  [ ("array",
      [ "struct pudu_items { size_t length; size_t capacity; pudu_cell cells[]; };"
      , "static pudu_box *pudu_array_new(size_t capacity) {"
      , "  pudu_box *box = pudu_box_new(1);"
      , "  pudu_items *items;"
      , "  if (capacity > (SIZE_MAX - sizeof(pudu_items)) / sizeof(pudu_cell)) pudu_memory_failure();"
      , "  items = malloc(sizeof(pudu_items) + capacity * sizeof(pudu_cell));"
      , "  if (items == NULL) pudu_memory_failure();"
      , "  items->length = 0;"
      , "  items->capacity = capacity;"
      , "  box->fields[0].items = items;"
      , "  return box;"
      , "}"
      , "#define pudu_array_length(box) ((box)->fields[0].items->length)"
      ])
  , ("array_reserve",
      [ "/* Room for needed items; only for a box with one owner. Doubling keeps"
      , "   a run of pushes linear. */"
      , "static void pudu_array_reserve(pudu_box *box, size_t needed) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  size_t capacity;"
      , "  if (needed <= items->capacity) return;"
      , "  capacity = items->capacity < 4 ? 4 : items->capacity;"
      , "  while (capacity < needed) capacity = capacity > SIZE_MAX / 2 ? needed : capacity * 2;"
      , "  if (capacity > (SIZE_MAX - sizeof(pudu_items)) / sizeof(pudu_cell)) pudu_memory_failure();"
      , "  items = realloc(items, sizeof(pudu_items) + capacity * sizeof(pudu_cell));"
      , "  if (items == NULL) pudu_memory_failure();"
      , "  items->capacity = capacity;"
      , "  box->fields[0].items = items;"
      , "}"
      ])
  , ("array_offset",
      [ "/* The offset an index names, or length when it names none. */"
      , "static inline size_t pudu_array_offset(pudu_int index, size_t length) {"
      , "  uint64_t magnitude = pudu_magnitude(index);"
      , "  if (index.negative || magnitude >= (uint64_t)length) return length;"
      , "  return (size_t)magnitude;"
      , "}"
      ])
  , ("array_clamp",
      [ "/* An index pulled into 0..length, as insert and slice read theirs. */"
      , "static inline size_t pudu_array_clamp(pudu_int index, size_t length) {"
      , "  uint64_t magnitude = pudu_magnitude(index);"
      , "  if (index.negative) return 0;"
      , "  return magnitude > (uint64_t)length ? length : (size_t)magnitude;"
      , "}"
      ])
  , ("array_size",
      [ "static inline pudu_int pudu_array_size(pudu_box *box) {"
      , "  return pudu_make((uint64_t)pudu_array_length(box), 0);"
      , "}"
      ])
  , ("int_order",
      [ "/* -1, 0 or 1 as a is below, at or above b. */"
      , "static int pudu_int_order(pudu_int a, pudu_int b) {"
      , "  uint64_t am = pudu_magnitude(a), bm = pudu_magnitude(b);"
      , "  if (a.negative != b.negative) return (am == 0 && bm == 0) ? 0 : (a.negative ? -1 : 1);"
      , "  if (am == bm) return 0;"
      , "  return ((am < bm) != (a.negative != 0)) ? -1 : 1;"
      , "}"
      ])
  , ("array_join",
      [ "/* The texts with the separator between each pair. */"
      , "static pudu_text pudu_array_join(pudu_box *box, pudu_text separator) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  size_t length = 0;"
      , "  unsigned char *bytes;"
      , "  pudu_text joined;"
      , "  for (size_t i = 0; i < items->length; ++i) {"
      , "    size_t extra = items->cells[i].text.length + (i == 0 ? 0 : separator.length);"
      , "    if (length > SIZE_MAX - extra) pudu_memory_failure();"
      , "    length += extra;"
      , "  }"
      , "  joined = pudu_text_allocate(length, &bytes);"
      , "  for (size_t i = 0; i < items->length; ++i) {"
      , "    if (i != 0 && separator.length != 0) { memcpy(bytes, separator.bytes, separator.length); bytes += separator.length; }"
      , "    if (items->cells[i].text.length != 0) memcpy(bytes, items->cells[i].text.bytes, items->cells[i].text.length);"
      , "    bytes += items->cells[i].text.length;"
      , "  }"
      , "  return joined;"
      , "}"
      ])
  ]

arrayRuntimeDependencies :: Text -> [Text]
arrayRuntimeDependencies name = maybe [] id (lookup name
  [ ("array", ["memory_failure"])
  , ("array_reserve", ["array", "memory_failure"])
  , ("array_offset", ["array", "magnitude"])
  , ("array_clamp", ["array", "magnitude"])
  , ("array_size", ["array", "make"])
  , ("int_order", ["magnitude"])
  , ("array_join", ["array", "text_allocate"]) ])
