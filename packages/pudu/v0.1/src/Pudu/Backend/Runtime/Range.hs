{-| @Pudu.Backend.Runtime.Range — ranges retain the exact mathematical value
    of each endpoint. The presence flags distinguish an absent end from zero. -}
module Pudu.Backend.Runtime.Range (rangeRuntimeParts, rangeRuntimeDependencies) where

import Data.Text (Text)

rangeRuntimeParts :: [(Text, [Text])]
rangeRuntimeParts =
  [ ("range",
      [ "static pudu_box *pudu_range_make(int has_low, pudu_big *low, int inclusive, int has_high, pudu_big *high) {"
      , "  pudu_box *box = pudu_box_new(5);"
      , "  box->fields[0].scalar = has_low;"
      , "  box->fields[1].big = pudu_big_retain(low);"
      , "  box->fields[2].scalar = inclusive;"
      , "  box->fields[3].scalar = has_high;"
      , "  box->fields[4].big = pudu_big_retain(high);"
      , "  return box;"
      , "}"
      ])
  , ("range_bounded",
      [ "static inline int pudu_range_bounded(pudu_box *box) { return box->fields[0].scalar && box->fields[3].scalar; }"
      ])
  , ("range_int_kind",
      [ "static const pudu_int_kind pudu_range_int_kind = { INT64_MAX, UINT64_C(1) << 63, 64, 1 };" ])
  , ("range_count",
      [ "static pudu_big *pudu_range_count(pudu_box *box) {"
      , "  pudu_big *low = box->fields[1].big, *high = box->fields[4].big;"
      , "  pudu_big *count, *one, *inclusive;"
      , "  if (pudu_big_compare(low, high) > 0) return NULL;"
      , "  count = pudu_bigint_sub(high, low);"
      , "  if (!box->fields[2].scalar) return count;"
      , "  one = pudu_big_from_magnitude(0, 1);"
      , "  inclusive = pudu_bigint_add(count, one);"
      , "  pudu_big_release(count);"
      , "  pudu_big_release(one);"
      , "  return inclusive;"
      , "}"
      ])
  , ("range_length",
      [ "static pudu_int pudu_range_length(pudu_box *box, const pudu_site *unbounded, const pudu_site *too_long) {"
      , "  pudu_big *count;"
      , "  pudu_int value;"
      , "  int fits;"
      , "  if (!pudu_range_bounded(box)) pudu_fail(unbounded);"
      , "  count = pudu_range_count(box);"
      , "  fits = pudu_big_fits_int(count, pudu_range_int_kind);"
      , "  value = pudu_big_to_int(count);"
      , "  pudu_big_release(count);"
      , "  if (!fits) pudu_fail(too_long);"
      , "  return value;"
      , "}"
      ])
  , ("range_is_empty",
      [ "static int pudu_range_is_empty(pudu_box *box) {"
      , "  if (!pudu_range_bounded(box)) return 0;"
      , "  int order = pudu_big_compare(box->fields[1].big, box->fields[4].big);"
      , "  return order > 0 || (order == 0 && !box->fields[2].scalar);"
      , "}"
      ])
  , ("range_contains",
      [ "static int pudu_range_contains(pudu_box *box, const pudu_big *probe) {"
      , "  if (box->fields[0].scalar && pudu_big_compare(probe, box->fields[1].big) < 0) return 0;"
      , "  if (!box->fields[3].scalar) return 1;"
      , "  int compared = pudu_big_compare(probe, box->fields[4].big);"
      , "  return box->fields[2].scalar ? compared <= 0 : compared < 0;"
      , "}"
      ])
  , ("range_members_fit",
      [ "static int pudu_range_members_fit(pudu_box *box) {"
      , "  if (!pudu_range_bounded(box) || pudu_range_is_empty(box)) return 1;"
      , "  if (!pudu_big_fits_int(box->fields[1].big, pudu_range_int_kind)) return 0;"
      , "  if (pudu_big_fits_int(box->fields[4].big, pudu_range_int_kind)) return 1;"
      , "  if (box->fields[2].scalar) return 0;"
      , "  const pudu_big *high = box->fields[4].big;"
      , "  return high != NULL && !high->negative && high->length == 2"
      , "    && pudu_big_limb_pair(high, 0) == (UINT64_C(1) << 63);"
      , "}"
      ])
  , ("range_collect",
      [ "static pudu_box *pudu_range_collect(pudu_box *box, const pudu_big *stride, int exact, const pudu_site *unbounded) {"
      , "  pudu_big *count, *one = NULL;"
      , "  pudu_box *array;"
      , "  pudu_items *items;"
      , "  uint64_t length, step = stride == NULL ? 1 : pudu_big_limb_pair(stride, 0);"
      , "  int fits;"
      , "  if (!pudu_range_bounded(box)) pudu_fail(unbounded);"
      , "  count = pudu_range_count(box);"
      , "  if (count != NULL && stride != NULL && (stride->length != 1 || stride->limbs[0] != 1)) {"
      , "    pudu_big *distance, *quotient, *remainder;"
      , "    one = pudu_big_from_magnitude(0, 1);"
      , "    distance = pudu_bigint_sub(count, one);"
      , "    pudu_big_divide_magnitude(distance, stride, &quotient, &remainder);"
      , "    pudu_big_release(distance);"
      , "    pudu_big_release(remainder);"
      , "    pudu_big_release(count);"
      , "    count = pudu_bigint_add(quotient, one);"
      , "    pudu_big_release(quotient);"
      , "    pudu_big_release(one);"
      , "    one = NULL;"
      , "  }"
      , "  fits = count == NULL || count->length <= 2;"
      , "  length = pudu_big_limb_pair(count, 0);"
      , "  pudu_big_release(count);"
      , "  if (!fits || length > SIZE_MAX) pudu_memory_failure();"
      , "  array = pudu_array_new((size_t)length);"
      , "  items = array->fields[0].items;"
      , "  if (length != 0 && exact) {"
      , "    pudu_big *next = pudu_big_retain(box->fields[1].big);"
      , "    const pudu_big *increment = stride;"
      , "    if (increment == NULL && length > 1) {"
      , "      one = pudu_big_from_magnitude(0, 1);"
      , "      increment = one;"
      , "    }"
      , "    for (uint64_t i = 0; i < length; ++i) {"
      , "      items->cells[i].big = next;"
      , "      if (i + 1 < length) next = pudu_bigint_add(next, increment);"
      , "    }"
      , "  } else if (length != 0) {"
      , "    uint64_t start = pudu_big_to_int(box->fields[1].big).bits;"
      , "    for (uint64_t i = 0; i < length; ++i) {"
      , "      uint64_t bits = start + i * step;"
      , "      items->cells[i].integer = (pudu_int){bits, (bits >> 63) != 0};"
      , "    }"
      , "  }"
      , "  pudu_big_release(one);"
      , "  items->length = (size_t)length;"
      , "  return array;"
      , "}"
      ])
  , ("range_elements",
      [ "static pudu_box *pudu_range_elements(pudu_box *box, int exact, const pudu_site *unbounded) {"
      , "  return pudu_range_collect(box, NULL, exact, unbounded);"
      , "}"
      ])
  , ("range_reversed",
      [ "static pudu_box *pudu_range_reversed(pudu_box *box, int exact, const pudu_site *unbounded) {"
      , "  pudu_box *array = pudu_range_elements(box, exact, unbounded);"
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
      [ "static pudu_box *pudu_range_step(pudu_box *box, const pudu_big *stride, int exact, const pudu_site *not_positive, const pudu_site *unbounded) {"
      , "  if (pudu_big_sign(stride) <= 0) pudu_fail(not_positive);"
      , "  return pudu_range_collect(box, stride, exact, unbounded);"
      , "}"
      ])
  , ("range_sum",
      [ "/* The number of terms times twice their average is always even. */"
      , "static pudu_int pudu_range_sum(pudu_box *box, const pudu_site *unbounded, const pudu_site *too_large) {"
      , "  pudu_big *count, *ends, *product, *sum;"
      , "  pudu_int value;"
      , "  int fits;"
      , "  if (!pudu_range_bounded(box)) pudu_fail(unbounded);"
      , "  count = pudu_range_count(box);"
      , "  if (count == NULL) return pudu_make(0, 0);"
      , "  ends = pudu_bigint_add(box->fields[1].big, box->fields[4].big);"
      , "  if (!box->fields[2].scalar) {"
      , "    pudu_big *one = pudu_big_from_magnitude(0, 1);"
      , "    pudu_big *exclusive = pudu_bigint_sub(ends, one);"
      , "    pudu_big_release(ends);"
      , "    pudu_big_release(one);"
      , "    ends = exclusive;"
      , "  }"
      , "  product = pudu_bigint_mul(count, ends);"
      , "  sum = pudu_bigint_shift_right(product, 1);"
      , "  fits = pudu_big_fits_int(sum, pudu_range_int_kind);"
      , "  value = pudu_big_to_int(sum);"
      , "  pudu_big_release(count);"
      , "  pudu_big_release(ends);"
      , "  pudu_big_release(product);"
      , "  pudu_big_release(sum);"
      , "  if (!fits) pudu_fail(too_large);"
      , "  return value;"
      , "}"
      ])
  , ("range_show",
      [ "static pudu_text pudu_range_show(pudu_box *box) {"
      , "  pudu_text low = box->fields[0].scalar ? pudu_text_display_big(box->fields[1].big) : pudu_text_literal(\"\", 0);"
      , "  pudu_text high = box->fields[3].scalar ? pudu_text_display_big(box->fields[4].big) : pudu_text_literal(\"\", 0);"
      , "  pudu_text dots = box->fields[2].scalar ? pudu_text_literal(\"..=\", 3) : pudu_text_literal(\"..\", 2);"
      , "  pudu_text front = pudu_text_concat(low, dots);"
      , "  pudu_text whole = pudu_text_concat(front, high);"
      , "  pudu_text_release(low);"
      , "  pudu_text_release(high);"
      , "  pudu_text_release(front);"
      , "  return whole;"
      , "}"
      ])
  , ("range_compare",
      [ "static int pudu_range_compare(pudu_box *a, pudu_box *b) {"
      , "  int compared;"
      , "  if (a->fields[0].scalar != b->fields[0].scalar) return a->fields[0].scalar ? 1 : -1;"
      , "  compared = pudu_big_compare(a->fields[1].big, b->fields[1].big);"
      , "  if (compared != 0) return compared;"
      , "  if (a->fields[3].scalar != b->fields[3].scalar) return a->fields[3].scalar ? 1 : -1;"
      , "  compared = pudu_big_compare(a->fields[4].big, b->fields[4].big);"
      , "  if (compared != 0) return compared;"
      , "  return (a->fields[2].scalar > b->fields[2].scalar) - (a->fields[2].scalar < b->fields[2].scalar);"
      , "}"
      ])
  , ("range_equal",
      [ "static int pudu_range_equal(pudu_box *a, pudu_box *b) { return pudu_range_compare(a, b) == 0; }" ])
  ]

rangeRuntimeDependencies :: Text -> [Text]
rangeRuntimeDependencies name = maybe [] id (lookup name
  [ ("range", ["big_retain"])
  , ("range_int_kind", ["integer_value"])
  , ("range_count", ["big_compare", "bigint_sub", "big_from_magnitude", "bigint_add", "big_release"])
  , ("range_length", ["range_bounded", "range_count", "range_int_kind", "big_fits_int", "big_to_int", "site", "fail"])
  , ("range_is_empty", ["range_bounded", "big_compare"])
  , ("range_contains", ["big_compare"])
  , ("range_members_fit", ["range_is_empty", "range_int_kind", "big_fits_int"])
  , ("range_collect", ["range_bounded", "range_count", "big_to_int", "big_divide_magnitude", "array", "site", "fail", "memory_failure"])
  , ("range_elements", ["range_collect"])
  , ("range_reversed", ["range_elements"])
  , ("range_step", ["range_collect", "big_sign", "site", "fail"])
  , ("range_sum", ["range_bounded", "range_count", "range_int_kind", "bigint_mul", "bigint_shift_right", "big_fits_int", "big_to_int", "site", "fail"])
  , ("range_show", ["text_display_big", "text_literal", "text_concat"])
  , ("range_compare", ["big_compare"])
  , ("range_equal", ["range_compare"])
  ])
