{-| @Pudu.Backend.Emit.Array — the helpers one array type needs, written in
    terms of its element. Each answers with a new reference; a helper that
    changes the items does it in place only when the array's box has one
    owner, and copies it otherwise, so no one holding the array sees it
    change. The edge cases are `Eval.Array`'s: `insert` and `slice` clamp,
    `pop` of nothing and `remove` out of range answer the array unchanged. -}
module Pudu.Backend.Emit.Array (arrayHelpers) where

import Data.Text (Text)
import Pudu.Backend.Emit.Cell
  ( aggregateHelper, aggregateNeed, cType, cellName, isAggregate, memberCompare, memberComparable
  , memberEqual, memberRender, ownedType, released, retained )
import Pudu.Core (CoreType (..))

arrayHelpers :: CoreType -> CoreType -> [(Text, ([Text], [Text]))]
arrayHelpers kind element =
  [ helper "drop" (["array"] <> [aggregateNeed "drop" element | isAggregate element])
      ([ "static void " <> name "drop" <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  {"
      , "    pudu_items *items = box->fields[0].items;" ]
      <> [ "    for (size_t i = 0; i < items->length; ++i) " <> released element (cell "items" "i") | ownedType element ]
      <> [ "    free(items);", "  }", "  free(box);", "}" ])
  , helper "copy" ("array" : retainNeeds)
      [ "/* A fresh array of the same items with room for extra more. */"
      , "static pudu_box *" <> name "copy" <> "(pudu_box *box, size_t extra) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  pudu_box *copy;"
      , "  pudu_items *copied;"
      , "  if (items->length > SIZE_MAX - extra) pudu_memory_failure();"
      , "  copy = pudu_array_new(items->length + extra);"
      , "  copied = copy->fields[0].items;"
      , "  for (size_t i = 0; i < items->length; ++i) " <> cell "copied" "i" <> " = " <> retain (cell "items" "i") <> ";"
      , "  copied->length = items->length;"
      , "  return copy;"
      , "}" ]
  , helper "make" ("array" : retainNeeds)
      [ "static pudu_box *" <> name "make" <> "(size_t count, const pudu_cell *cells) {"
      , "  pudu_box *box = pudu_array_new(count);"
      , "  pudu_items *items = box->fields[0].items;"
      , "  for (size_t i = 0; i < count; ++i) " <> cell "items" "i" <> " = " <> retain ("cells[i]." <> member) <> ";"
      , "  items->length = count;"
      , "  return box;"
      , "}" ]
  , helper "push" (["array", "array_reserve", aggregateNeed "copy" kind] <> retainNeeds)
      [ "static pudu_box *" <> name "push" <> "(pudu_box *box, " <> cType element <> " value) {"
      , "  pudu_box *result = " <> owned "1" <> ";"
      , "  pudu_items *items = result->fields[0].items;"
      , "  " <> cell "items" "items->length" <> " = " <> retain "value" <> ";"
      , "  items->length += 1;"
      , "  return result;"
      , "}" ]
  , helper "pop" ["array", "array_reserve", aggregateNeed "copy" kind]
      ([ "static pudu_box *" <> name "pop" <> "(pudu_box *box) {"
      , "  pudu_box *result;"
      , "  pudu_items *items;"
      , "  if (pudu_array_length(box) == 0) return pudu_box_retain(box);"
      , "  result = " <> owned "0" <> ";"
      , "  items = result->fields[0].items;"
      , "  items->length -= 1;" ]
      <> [ "  " <> released element (cell "items" "items->length") | ownedType element ]
      <> [ "  return result;", "}" ])
  , helper "insert" (["array", "array_reserve", "array_clamp", aggregateNeed "copy" kind] <> retainNeeds)
      [ "static pudu_box *" <> name "insert" <> "(pudu_box *box, pudu_int index, " <> cType element <> " value) {"
      , "  size_t at = pudu_array_clamp(index, pudu_array_length(box));"
      , "  pudu_box *result = " <> owned "1" <> ";"
      , "  pudu_items *items = result->fields[0].items;"
      , "  memmove(&items->cells[at + 1], &items->cells[at], (items->length - at) * sizeof(pudu_cell));"
      , "  " <> cell "items" "at" <> " = " <> retain "value" <> ";"
      , "  items->length += 1;"
      , "  return result;"
      , "}" ]
  , helper "remove" ["array", "array_reserve", "array_offset", aggregateNeed "copy" kind]
      ([ "static pudu_box *" <> name "remove" <> "(pudu_box *box, pudu_int index) {"
      , "  size_t at = pudu_array_offset(index, pudu_array_length(box));"
      , "  pudu_box *result;"
      , "  pudu_items *items;"
      , "  if (at == pudu_array_length(box)) return pudu_box_retain(box);"
      , "  result = " <> owned "0" <> ";"
      , "  items = result->fields[0].items;" ]
      <> [ "  " <> released element (cell "items" "at") | ownedType element ]
      <> [ "  memmove(&items->cells[at], &items->cells[at + 1], (items->length - at - 1) * sizeof(pudu_cell));"
         , "  items->length -= 1;"
         , "  return result;", "}" ])
  , helper "slice" ("array" : "array_clamp" : "int_order" : retainNeeds)
      [ "static pudu_box *" <> name "slice" <> "(pudu_box *box, pudu_int start, pudu_int end) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  size_t from, to;"
      , "  pudu_box *result;"
      , "  pudu_items *taken;"
      , "  if (pudu_int_order(start, end) >= 0) return pudu_array_new(0);"
      , "  from = pudu_array_clamp(start, items->length);"
      , "  to = pudu_array_clamp(end, items->length);"
      , "  if (to < from) to = from;"
      , "  result = pudu_array_new(to - from);"
      , "  taken = result->fields[0].items;"
      , "  for (size_t i = from; i < to; ++i) " <> cell "taken" "i - from" <> " = " <> retain (cell "items" "i") <> ";"
      , "  taken->length = to - from;"
      , "  return result;"
      , "}" ]
  , helper "concat" (["array", "array_reserve", aggregateNeed "copy" kind] <> retainNeeds)
      [ "static pudu_box *" <> name "concat" <> "(pudu_box *box, pudu_box *other) {"
      , "  pudu_items *added = other->fields[0].items;"
      , "  size_t count = added->length;"
      , "  pudu_box *result = " <> owned "count" <> ";"
      , "  pudu_items *items = result->fields[0].items;"
      , "  for (size_t i = 0; i < count; ++i) " <> cell "items" "items->length + i" <> " = " <> retain (cell "added" "i") <> ";"
      , "  items->length += count;"
      , "  return result;"
      , "}" ]
  , helper "reverse" ("array" : retainNeeds)
      [ "static pudu_box *" <> name "reverse" <> "(pudu_box *box) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  pudu_box *result = pudu_array_new(items->length);"
      , "  pudu_items *turned = result->fields[0].items;"
      , "  for (size_t i = 0; i < items->length; ++i) " <> cell "turned" "i" <> " = " <> retain (cell "items" "items->length - 1 - i") <> ";"
      , "  turned->length = items->length;"
      , "  return result;"
      , "}" ]
  , helper "get" ("array" : "array_offset" : "site" : "colored" : "fail" : retainNeeds)
      [ "static " <> cType element <> " " <> name "get" <> "(pudu_box *box, pudu_int index, const pudu_site *site) {"
      , "  size_t at = pudu_array_offset(index, pudu_array_length(box));"
      , "  if (at == pudu_array_length(box)) pudu_fail(site);"
      , "  return " <> retain (cell "box->fields[0].items" "at") <> ";"
      , "}" ]
  , helper "index_of" ("array" : "make" : equalNeeds)
      [ "static pudu_int " <> name "index_of" <> "(pudu_box *box, " <> cType element <> " value) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  for (size_t i = 0; i < items->length; ++i) if (" <> equal (cell "items" "i") "value" <> ") return pudu_make((uint64_t)i, 0);"
      , "  return pudu_make(1, 1);"
      , "}" ]
  , helper "contains" ("array" : equalNeeds)
      [ "static int " <> name "contains" <> "(pudu_box *box, " <> cType element <> " value) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  for (size_t i = 0; i < items->length; ++i) if (" <> equal (cell "items" "i") "value" <> ") return 1;"
      , "  return 0;"
      , "}" ]
  , helper "show" ("array" : "text_join" : "memory_failure" : renderNeeds)
      [ "static pudu_text " <> name "show" <> "(pudu_box *box) {"
      , "  pudu_items *items = box->fields[0].items;"
      , "  pudu_text *parts;"
      , "  pudu_text shown;"
      , "  if (items->length == 0) return pudu_text_join(\"[\", NULL, NULL, 0, \"]\");"
      , "  if (items->length > SIZE_MAX / sizeof(pudu_text)) pudu_memory_failure();"
      , "  parts = malloc(items->length * sizeof(pudu_text));"
      , "  if (parts == NULL) pudu_memory_failure();"
      , "  for (size_t i = 0; i < items->length; ++i) parts[i] = " <> fst (memberRender element (cell "items" "i")) <> ";"
      , "  shown = pudu_text_join(\"[\", NULL, parts, items->length, \"]\");"
      , "  free(parts);"
      , "  return shown;"
      , "}" ]
  , helper "equal" ("array" : equalNeeds)
      [ "static int " <> name "equal" <> "(pudu_box *a, pudu_box *b) {"
      , "  pudu_items *left = a->fields[0].items, *right = b->fields[0].items;"
      , "  if (left->length != right->length) return 0;"
      , "  for (size_t i = 0; i < left->length; ++i) if (!(" <> equal (cell "left" "i") (cell "right" "i") <> ")) return 0;"
      , "  return 1;"
      , "}" ]
  , helper "compare" ("array" : snd (memberCompare element "" ""))
      [ "/* compareLists: the first item that differs decides, then the length. */"
      , "static int " <> name "compare" <> "(pudu_box *a, pudu_box *b) {"
      , "  pudu_items *left = a->fields[0].items, *right = b->fields[0].items;"
      , "  size_t shorter = left->length < right->length ? left->length : right->length;"
      , "  for (size_t i = 0; i < shorter; ++i) {"
      , "    int order = " <> fst (memberCompare element (cell "left" "i") (cell "right" "i")) <> ";"
      , "    if (order != 0) return order;"
      , "  }"
      , "  return (left->length > right->length) - (left->length < right->length);"
      , "}" ]
  , helper "comparable" ("array" : snd (memberComparable element ""))
      (if isAggregate element
        then [ "static int " <> name "comparable" <> "(pudu_box *box) {"
             , "  pudu_items *items = box->fields[0].items;"
             , "  for (size_t i = 0; i < items->length; ++i) if (!" <> fst (memberComparable element (cell "items" "i")) <> ") return 0;"
             , "  return 1;", "}" ]
        else [ "static int " <> name "comparable" <> "(pudu_box *box) {", "  (void)box;", "  return 1;", "}" ])
  ]
 where
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  name operation = aggregateHelper operation kind
  member = cellName element
  cell items index = items <> "->cells[" <> index <> "]." <> member
  retain expression = fst (retained element expression)
  retainNeeds = snd (retained element "")
  equal a b = fst (memberEqual element a b)
  equalNeeds = snd (memberEqual element "" "")
  renderNeeds = snd (memberRender element "")
  -- The box itself when it has one owner, made big enough; a copy otherwise.
  owned extra = "(box->count == 1 ? (pudu_array_reserve(box, pudu_array_length(box) + " <> extra
    <> "), pudu_box_retain(box)) : " <> name "copy" <> "(box, " <> extra <> "))"
