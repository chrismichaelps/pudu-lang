{-| @Pudu.Backend.Runtime.Range — range values, as `Eval.Range` answers them.
    A range is a box of five cells: has a start, the start, inclusive, has an
    end, the end. Every range is `Range[Int]`. These parts use boxes and
    arrays, so they are emitted after the frame types. -}
module Pudu.Backend.Runtime.Range (rangeRuntimeParts, rangeRuntimeDependencies) where

import Data.Text (Text)

rangeRuntimeParts :: [(Text, [Text])]
rangeRuntimeParts =
  [ ("range",
      [ "static pudu_box *pudu_range_make(int has_low, pudu_int low, int inclusive, int has_high, pudu_int high) {"
      , "  pudu_box *box = pudu_box_new(5);"
      , "  box->fields[0].scalar = has_low;"
      , "  box->fields[1].integer = has_low ? pudu_normal(low) : pudu_make(0, 0);"
      , "  box->fields[2].scalar = inclusive;"
      , "  box->fields[3].scalar = has_high;"
      , "  box->fields[4].integer = has_high ? pudu_normal(high) : pudu_make(0, 0);"
      , "  return box;"
      , "}"
      ])
  , ("range_ends",
      [ "static inline int64_t pudu_range_low(pudu_box *box) { return (int64_t)box->fields[1].integer.bits; }"
      , "static inline int64_t pudu_range_high(pudu_box *box) { return (int64_t)box->fields[4].integer.bits; }"
      ])
  , ("range_bounded",
      [ "static inline int pudu_range_bounded(pudu_box *box) { return box->fields[0].scalar && box->fields[3].scalar; }"
      ])
  , ("range_int",
      [ "static inline pudu_int pudu_range_int(int64_t value) {"
      , "  return value < 0 ? pudu_make(UINT64_C(0) - (uint64_t)value, 1) : pudu_make((uint64_t)value, 0);"
      , "}"
      ])
  , ("range_count",
      [ "/* How many values a bounded range covers, which may be 2^64. */"
      , "static inline uint64_t pudu_range_count(pudu_box *box, int *all) {"
      , "  int64_t low = pudu_range_low(box), high = pudu_range_high(box);"
      , "  uint64_t span;"
      , "  *all = 0;"
      , "  if (high < low) return 0;"
      , "  span = (uint64_t)high - (uint64_t)low;"
      , "  if (!box->fields[2].scalar) return span;"
      , "  if (span == UINT64_MAX) { *all = 1; return 0; }"
      , "  return span + 1;"
      , "}"
      ])
  , ("range_length",
      [ "static pudu_int pudu_range_length(pudu_box *box, const pudu_site *unbounded, const pudu_site *too_long) {"
      , "  int all;"
      , "  uint64_t count;"
      , "  if (!pudu_range_bounded(box)) pudu_fail(unbounded);"
      , "  count = pudu_range_count(box, &all);"
      , "  if (all || count > (uint64_t)INT64_MAX) pudu_fail(too_long);"
      , "  return pudu_make(count, 0);"
      , "}"
      ])
  , ("range_is_empty",
      [ "static int pudu_range_is_empty(pudu_box *box) {"
      , "  int all;"
      , "  return pudu_range_bounded(box) && pudu_range_count(box, &all) == 0 && !all;"
      , "}"
      ])
  , ("range_contains",
      [ "static int pudu_range_contains(pudu_box *box, pudu_int probe) {"
      , "  int64_t value = (int64_t)pudu_normal(probe).bits;"
      , "  if (box->fields[0].scalar && value < pudu_range_low(box)) return 0;"
      , "  if (box->fields[3].scalar && (box->fields[2].scalar ? value > pudu_range_high(box) : value >= pudu_range_high(box))) return 0;"
      , "  return 1;"
      , "}"
      ])
  , ("range_elements",
      [ "/* The values in order, or the failure at site when an end is missing. */"
      , "static pudu_box *pudu_range_elements(pudu_box *box, const pudu_site *unbounded) {"
      , "  int all;"
      , "  uint64_t count;"
      , "  pudu_box *array;"
      , "  pudu_items *items;"
      , "  int64_t low;"
      , "  if (!pudu_range_bounded(box)) pudu_fail(unbounded);"
      , "  count = pudu_range_count(box, &all);"
      , "  if (all || count > SIZE_MAX) pudu_memory_failure();"
      , "  array = pudu_array_new((size_t)count);"
      , "  items = array->fields[0].items;"
      , "  low = pudu_range_low(box);"
      , "  for (uint64_t i = 0; i < count; ++i) items->cells[i].integer = pudu_range_int((int64_t)((uint64_t)low + i));"
      , "  items->length = (size_t)count;"
      , "  return array;"
      , "}"
      ])
  , ("range_reversed",
      [ "static pudu_box *pudu_range_reversed(pudu_box *box, const pudu_site *unbounded) {"
      , "  pudu_box *array = pudu_range_elements(box, unbounded);"
      , "  pudu_items *items = array->fields[0].items;"
      , "  for (size_t i = 0, j = items->length; i + 1 < j; ++i, --j) {"
      , "    pudu_cell held = items->cells[i];"
      , "    items->cells[i] = items->cells[j - 1];"
      , "    items->cells[j - 1] = held;"
      , "  }"
      , "  return array;"
      , "}"
      ])
  , ("range_step",
      [ "/* Every stride-th value from the start; the stride is checked first. */"
      , "static pudu_box *pudu_range_step(pudu_box *box, pudu_int stride, const pudu_site *not_positive, const pudu_site *unbounded) {"
      , "  pudu_box *all, *taken;"
      , "  pudu_items *items, *kept;"
      , "  uint64_t every;"
      , "  stride = pudu_normal(stride);"
      , "  if (stride.negative || stride.bits == 0) pudu_fail(not_positive);"
      , "  every = stride.bits;"
      , "  all = pudu_range_elements(box, unbounded);"
      , "  items = all->fields[0].items;"
      , "  taken = pudu_array_new(items->length == 0 ? 0 : (size_t)((items->length - 1) / every + 1));"
      , "  kept = taken->fields[0].items;"
      , "  for (size_t i = 0; i < items->length;) {"
      , "    kept->cells[kept->length++] = items->cells[i];"
      , "    if (every >= (uint64_t)(items->length - i)) break;"
      , "    i += (size_t)every;"
      , "  }"
      , "  free(items);"
      , "  free(all);"
      , "  return taken;"
      , "}"
      ])
  , ("range_sum",
      [ "/* Exact: a 128-bit running total, and only the total has to fit. */"
      , "static pudu_int pudu_range_sum(pudu_box *box, const pudu_site *unbounded, const pudu_site *too_large) {"
      , "  int all;"
      , "  uint64_t count, low_word = 0, high_word = 0;"
      , "  int64_t start;"
      , "  if (!pudu_range_bounded(box)) pudu_fail(unbounded);"
      , "  count = pudu_range_count(box, &all);"
      , "  start = pudu_range_low(box);"
      , "  for (uint64_t i = 0; all || i < count; ++i) {"
      , "    int64_t value = (int64_t)((uint64_t)start + i);"
      , "    uint64_t word = (uint64_t)value;"
      , "    low_word += word;"
      , "    high_word += (value < 0 ? UINT64_MAX : 0) + (low_word < word);"
      , "    if (all && i == UINT64_MAX) break;"
      , "  }"
      , "  if (high_word != ((low_word >> 63) ? UINT64_MAX : 0)) pudu_fail(too_large);"
      , "  return pudu_range_int((int64_t)low_word);"
      , "}"
      ])
  , ("range_show",
      [ "/* renderRange: the ends as written, absent ones left out. */"
      , "static pudu_text pudu_range_show(pudu_box *box) {"
      , "  pudu_text low = box->fields[0].scalar ? pudu_text_display_int(box->fields[1].integer) : pudu_text_literal(\"\", 0);"
      , "  pudu_text high = box->fields[3].scalar ? pudu_text_display_int(box->fields[4].integer) : pudu_text_literal(\"\", 0);"
      , "  pudu_text dots = box->fields[2].scalar ? pudu_text_literal(\"..=\", 3) : pudu_text_literal(\"..\", 2);"
      , "  pudu_text front = pudu_text_concat(low, dots);"
      , "  pudu_text whole = pudu_text_concat(front, high);"
      , "  pudu_text_release(low);"
      , "  pudu_text_release(high);"
      , "  pudu_text_release(front);"
      , "  return whole;"
      , "}"
      ])
  , ("range_equal",
      [ "static int pudu_range_equal(pudu_box *a, pudu_box *b) {"
      , "  return a->fields[0].scalar == b->fields[0].scalar && pudu_range_low(a) == pudu_range_low(b)"
      , "    && a->fields[2].scalar == b->fields[2].scalar"
      , "    && a->fields[3].scalar == b->fields[3].scalar && pudu_range_high(a) == pudu_range_high(b);"
      , "}"
      ])
  , ("range_compare",
      [ "/* compareValues: start, then end, then inclusive; a missing end first. */"
      , "static int pudu_range_compare(pudu_box *a, pudu_box *b) {"
      , "  if (a->fields[0].scalar != b->fields[0].scalar) return a->fields[0].scalar ? 1 : -1;"
      , "  if (pudu_range_low(a) != pudu_range_low(b)) return pudu_range_low(a) < pudu_range_low(b) ? -1 : 1;"
      , "  if (a->fields[3].scalar != b->fields[3].scalar) return a->fields[3].scalar ? 1 : -1;"
      , "  if (pudu_range_high(a) != pudu_range_high(b)) return pudu_range_high(a) < pudu_range_high(b) ? -1 : 1;"
      , "  return (a->fields[2].scalar > b->fields[2].scalar) - (a->fields[2].scalar < b->fields[2].scalar);"
      , "}"
      ])
  ]

rangeRuntimeDependencies :: Text -> [Text]
rangeRuntimeDependencies name = maybe [] id (lookup name
  [ ("range", ["make", "normal"])
  , ("range_ends", ["range"])
  , ("range_bounded", ["range"])
  , ("range_int", ["make"])
  , ("range_count", ["range_ends"])
  , ("range_length", ["range_bounded", "range_count", "make", "site", "fail"])
  , ("range_is_empty", ["range_bounded", "range_count"])
  , ("range_contains", ["range_ends", "normal"])
  , ("range_elements", ["range_bounded", "range_count", "range_int", "array", "site", "fail", "memory_failure"])
  , ("range_reversed", ["range_elements"])
  , ("range_step", ["range_elements", "normal", "site", "fail"])
  , ("range_sum", ["range_bounded", "range_count", "range_int", "site", "fail"])
  , ("range_show", ["range", "text_display_int", "text_literal", "text_concat"])
  , ("range_equal", ["range_ends"])
  , ("range_compare", ["range_ends"])
  ])
