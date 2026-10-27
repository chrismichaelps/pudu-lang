{-| @Pudu.Backend.Emit.Keyed — the helpers one map or set type needs, over the
    shared tree runtime. A map or set is a box whose first cell holds the
    tree's root. Helpers read their arguments and answer with a new reference,
    as the array helpers do. -}
module Pudu.Backend.Emit.Keyed (mapHelpers, setHelpers) where

import Data.Text (Text)
import Pudu.Backend.Emit.Cell
  ( aggregateHelper, aggregateNeed, cType, cellName, isAggregate, memberCompare, memberComparable, memberEqual, memberRender
  , ownedType, released, retained )
import Pudu.Core (CoreType (..))

mapHelpers :: CoreType -> CoreType -> CoreType -> [(Text, ([Text], [Text]))]
mapHelpers kind key value =
  shared kind key (Just value) <>
  [ helper "make" (["array", "tree_insert", aggregateNeed "ops" kind, aggregateNeed "wrap" kind])
      [ "/* mapOf: inserted in order, so a repeated key keeps its first spelling"
      , "   and its last value. */"
      , "static pudu_box *" <> name "make" <> "(pudu_box *pairs) {"
      , "  pudu_items *items = pairs->fields[0].items;"
      , "  pudu_tree_node *root = NULL;"
      , "  for (size_t i = 0; i < items->length; ++i) {"
      , "    pudu_box *pair = items->cells[i].box;"
      , "    root = pudu_tree_insert(root, " <> name "keyretain" <> "(pair->fields[0]), " <> name "valueretain" <> "(pair->fields[1]), 1, " <> ops <> ");"
      , "  }"
      , "  return " <> name "wrap" <> "(root);"
      , "}" ]
  , helper "insert" ["tree_insert", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
      [ "static pudu_box *" <> name "insert" <> "(pudu_box *box, " <> cType key <> " key, " <> cType value <> " value) {"
      , "  pudu_cell held, stored;"
      , "  held." <> cellName key <> " = key;"
      , "  stored." <> cellName value <> " = value;"
      , "  return " <> name "wrap" <> "(pudu_tree_insert(pudu_tree_retain(box->fields[0].tree), "
          <> name "keyretain" <> "(held), " <> name "valueretain" <> "(stored), 1, " <> ops <> "));"
      , "}" ]
  , helper "lookup" ("tree_find" : aggregateNeed "ops" kind : snd (retained value ""))
      [ "/* get, once contains has said the key is there. */"
      , "static " <> cType value <> " " <> name "lookup" <> "(pudu_box *box, " <> cType key <> " key) {"
      , "  pudu_cell probe;"
      , "  probe." <> cellName key <> " = key;"
      , "  return " <> fst (retained value ("pudu_tree_find(box->fields[0].tree, probe, " <> ops <> ")->value." <> cellName value)) <> ";"
      , "}" ]
  , helper "values" ("array" : "tree_walk" : snd (retained value ""))
      (walkInto "values" value (\node -> fst (retained value (node <> "->value." <> cellName value))))
  , helper "entries" ["array", "tree_walk", aggregateNeed "make" pair]
      (walkInto "entries" pair (\node -> aggregateHelper "make" pair <> "(" <> node <> "->key." <> cellName key <> ", " <> node <> "->value." <> cellName value <> ")"))
  , helper "merge" ["tree_insert", "tree_walk", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
      [ "/* The right map's keys and values win, as Map.union right left has it. */"
      , "static pudu_box *" <> name "merge" <> "(pudu_box *box, pudu_box *other) {"
      , "  pudu_tree_node *root = pudu_tree_retain(box->fields[0].tree);"
      , "  pudu_tree_node **nodes = pudu_tree_nodes(other->fields[0].tree);"
      , "  size_t count = pudu_tree_size(other->fields[0].tree);"
      , "  for (size_t i = 0; i < count; ++i)"
      , "    root = pudu_tree_insert(root, " <> name "keyretain" <> "(nodes[i]->key), " <> name "valueretain" <> "(nodes[i]->value), 0, " <> ops <> ");"
      , "  free(nodes);"
      , "  return " <> name "wrap" <> "(root);"
      , "}" ]
  , helper "show" ("tree_walk" : "text_join" : "text_concat" : "memory_failure" : snd (memberRender key "") <> snd (memberRender value ""))
      [ "static pudu_text " <> name "show" <> "(pudu_box *box) {"
      , "  pudu_tree_node **nodes = pudu_tree_nodes(box->fields[0].tree);"
      , "  size_t count = pudu_tree_size(box->fields[0].tree);"
      , "  pudu_text *parts, shown;"
      , "  if (count > SIZE_MAX / sizeof *parts) pudu_memory_failure();"
      , "  parts = malloc((count == 0 ? 1 : count) * sizeof *parts);"
      , "  if (parts == NULL) pudu_memory_failure();"
      , "  for (size_t i = 0; i < count; ++i) {"
      , "    pudu_text label = " <> fst (memberRender key ("nodes[i]->key." <> cellName key)) <> ";"
      , "    pudu_text held = " <> fst (memberRender value ("nodes[i]->value." <> cellName value)) <> ";"
      , "    pudu_text keyed = pudu_text_join(\"\", NULL, &label, 1, \": \");"
      , "    parts[i] = pudu_text_concat(keyed, held);"
      , "    pudu_text_release(keyed);"
      , "    pudu_text_release(held);"
      , "  }"
      , "  shown = pudu_text_join(\"{\", NULL, parts, count, \"}\");"
      , "  free(parts);"
      , "  free(nodes);"
      , "  return shown;"
      , "}" ]
  ]
 where
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  name operation = aggregateHelper operation kind
  ops = name "ops" <> "()"
  pair = CoreTupleType [key, value]
  walkInto = walkHelper kind

setHelpers :: CoreType -> CoreType -> [(Text, ([Text], [Text]))]
setHelpers kind member =
  shared kind member Nothing <>
  [ helper "make" ["array", "tree_insert", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
      [ "/* setOf and #{...}: a member already held stays. */"
      , "static pudu_box *" <> name "make" <> "(pudu_box *members) {"
      , "  pudu_items *items = members->fields[0].items;"
      , "  pudu_tree_node *root = NULL;"
      , "  for (size_t i = 0; i < items->length; ++i)"
      , "    root = pudu_tree_insert(root, " <> name "keyretain" <> "(items->cells[i]), " <> unit <> ", 1, " <> ops <> ");"
      , "  return " <> name "wrap" <> "(root);"
      , "}" ]
  , helper "insert" ["tree_insert", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
      [ "static pudu_box *" <> name "insert" <> "(pudu_box *box, " <> cType member <> " member) {"
      , "  pudu_cell held;"
      , "  held." <> cellName member <> " = member;"
      , "  return " <> name "wrap" <> "(pudu_tree_insert(pudu_tree_retain(box->fields[0].tree), " <> name "keyretain" <> "(held), " <> unit <> ", 1, " <> ops <> "));"
      , "}" ]
  , helper "union" ["tree_insert", "tree_walk", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
      [ "/* Set.union left right keeps the left set's members. */"
      , "static pudu_box *" <> name "union" <> "(pudu_box *box, pudu_box *other) {"
      , "  pudu_tree_node *root = pudu_tree_retain(box->fields[0].tree);"
      , "  pudu_tree_node **nodes = pudu_tree_nodes(other->fields[0].tree);"
      , "  size_t count = pudu_tree_size(other->fields[0].tree);"
      , "  for (size_t i = 0; i < count; ++i)"
      , "    root = pudu_tree_insert(root, " <> name "keyretain" <> "(nodes[i]->key), " <> unit <> ", 1, " <> ops <> ");"
      , "  free(nodes);"
      , "  return " <> name "wrap" <> "(root);"
      , "}" ]
  , filtered "intersect" "!= NULL"
  , filtered "difference" "== NULL"
  , helper "show" ("tree_walk" : "text_join" : "memory_failure" : snd (memberRender member ""))
      [ "static pudu_text " <> name "show" <> "(pudu_box *box) {"
      , "  pudu_tree_node **nodes = pudu_tree_nodes(box->fields[0].tree);"
      , "  size_t count = pudu_tree_size(box->fields[0].tree);"
      , "  pudu_text *parts, shown;"
      , "  if (count > SIZE_MAX / sizeof *parts) pudu_memory_failure();"
      , "  parts = malloc((count == 0 ? 1 : count) * sizeof *parts);"
      , "  if (parts == NULL) pudu_memory_failure();"
      , "  for (size_t i = 0; i < count; ++i) parts[i] = " <> fst (memberRender member ("nodes[i]->key." <> cellName member)) <> ";"
      , "  shown = pudu_text_join(\"#{\", NULL, parts, count, \"}\");"
      , "  free(parts);"
      , "  free(nodes);"
      , "  return shown;"
      , "}" ]
  ]
 where
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  name operation = aggregateHelper operation kind
  ops = name "ops" <> "()"
  unit = "(pudu_cell){0}"
  -- intersect and difference rebuild from the left set's members.
  filtered operation test = helper operation ["tree_insert", "tree_find", "tree_walk", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
    [ "static pudu_box *" <> name operation <> "(pudu_box *box, pudu_box *other) {"
    , "  pudu_tree_node *root = NULL;"
    , "  pudu_tree_node **nodes = pudu_tree_nodes(box->fields[0].tree);"
    , "  size_t count = pudu_tree_size(box->fields[0].tree);"
    , "  for (size_t i = 0; i < count; ++i)"
    , "    if (pudu_tree_find(other->fields[0].tree, nodes[i]->key, " <> ops <> ") " <> test <> ")"
    , "      root = pudu_tree_insert(root, " <> name "keyretain" <> "(nodes[i]->key), " <> unit <> ", 1, " <> ops <> ");"
    , "  free(nodes);"
    , "  return " <> name "wrap" <> "(root);"
    , "}" ]

{-| What maps and sets share; a set's value is an unused cell. -}
shared :: CoreType -> CoreType -> Maybe CoreType -> [(Text, ([Text], [Text]))]
shared kind key value =
  [ helper "keyorder" (snd (memberCompare key "" ""))
      [ "static int " <> name "keyorder" <> "(pudu_cell a, pudu_cell b) {"
      , "  (void)a; (void)b;"
      , "  return " <> fst (memberCompare key ("a." <> cellName key) ("b." <> cellName key)) <> ";"
      , "}" ]
  , cellRetain "keyretain" key
  , cellRelease "keyrelease" key
  , maybe (cellRetain "valueretain" CoreUnitType) (cellRetain "valueretain") value
  , maybe (cellRelease "valuerelease" CoreUnitType) (cellRelease "valuerelease") value
  , helper "ops" ["tree", aggregateNeed "keyorder" kind, aggregateNeed "keyretain" kind, aggregateNeed "keyrelease" kind
                 , aggregateNeed "valueretain" kind, aggregateNeed "valuerelease" kind]
      [ "static const pudu_tree_ops *" <> name "ops" <> "(void) {"
      , "  static const pudu_tree_ops ops = {" <> name "keyorder" <> ", " <> name "keyretain" <> ", " <> name "keyrelease"
          <> ", " <> name "valueretain" <> ", " <> name "valuerelease" <> "};"
      , "  return &ops;"
      , "}" ]
  , helper "wrap" ["tree"]
      [ "static pudu_box *" <> name "wrap" <> "(pudu_tree_node *root) {"
      , "  pudu_box *box = pudu_box_new(1);"
      , "  box->fields[0].tree = root;"
      , "  return box;"
      , "}" ]
  , helper "drop" ["tree", aggregateNeed "ops" kind]
      [ "static void " <> name "drop" <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;"
      , "  pudu_tree_release(box->fields[0].tree, " <> ops <> ");"
      , "  free(box);"
      , "}" ]
  , helper "size" ["tree", "make"]
      [ "static pudu_int " <> name "size" <> "(pudu_box *box) {"
      , "  return pudu_make((uint64_t)pudu_tree_size(box->fields[0].tree), 0);"
      , "}" ]
  , helper "contains" ["tree_find", aggregateNeed "ops" kind]
      [ "static int " <> name "contains" <> "(pudu_box *box, " <> cType key <> " key) {"
      , "  pudu_cell probe;"
      , "  probe." <> cellName key <> " = key;"
      , "  return pudu_tree_find(box->fields[0].tree, probe, " <> ops <> ") != NULL;"
      , "}" ]
  , helper "remove" ["tree_remove", aggregateNeed "ops" kind, aggregateNeed "wrap" kind]
      [ "static pudu_box *" <> name "remove" <> "(pudu_box *box, " <> cType key <> " key) {"
      , "  pudu_cell probe;"
      , "  probe." <> cellName key <> " = key;"
      , "  return " <> name "wrap" <> "(pudu_tree_remove(pudu_tree_retain(box->fields[0].tree), probe, " <> ops <> "));"
      , "}" ]
  , helper "keys" ("array" : "tree_walk" : snd (retained key ""))
      (walkHelper kind "keys" key (\node -> fst (retained key (node <> "->key." <> cellName key))))
  , helper "equal" ("tree_walk" : snd (memberEqual key "" "") <> foldMap (\held -> snd (memberEqual held "" "")) value)
      [ "/* Same size, then entries pairwise by ==, in key order. */"
      , "static int " <> name "equal" <> "(pudu_box *a, pudu_box *b) {"
      , "  size_t count = pudu_tree_size(a->fields[0].tree);"
      , "  pudu_tree_node **left, **right;"
      , "  int same = 1;"
      , "  if (count != pudu_tree_size(b->fields[0].tree)) return 0;"
      , "  left = pudu_tree_nodes(a->fields[0].tree);"
      , "  right = pudu_tree_nodes(b->fields[0].tree);"
      , "  for (size_t i = 0; i < count && same; ++i)"
      , "    same = " <> fst (memberEqual key ("left[i]->key." <> cellName key) ("right[i]->key." <> cellName key))
          <> foldMap (\held -> " && " <> fst (memberEqual held ("left[i]->value." <> cellName held) ("right[i]->value." <> cellName held))) value <> ";"
      , "  free(left);"
      , "  free(right);"
      , "  return same;"
      , "}" ]
  , helper "compare" ("tree_walk" : snd (memberCompare key "" "") <> foldMap (\held -> snd (memberCompare held "" "")) value)
      ([ "/* compareEntries: key, then value, entry by entry; then the sizes. */"
      , "static int " <> name "compare" <> "(pudu_box *a, pudu_box *b) {"
      , "  size_t left_count = pudu_tree_size(a->fields[0].tree), right_count = pudu_tree_size(b->fields[0].tree);"
      , "  size_t shorter = left_count < right_count ? left_count : right_count;"
      , "  pudu_tree_node **left = pudu_tree_nodes(a->fields[0].tree), **right = pudu_tree_nodes(b->fields[0].tree);"
      , "  int order = 0;"
      , "  for (size_t i = 0; i < shorter && order == 0; ++i) {"
      , "    order = " <> fst (memberCompare key ("left[i]->key." <> cellName key) ("right[i]->key." <> cellName key)) <> ";" ]
      <> foldMap (\held -> [ "    if (order == 0) order = " <> fst (memberCompare held ("left[i]->value." <> cellName held) ("right[i]->value." <> cellName held)) <> ";" ]) value
      <> [ "  }"
         , "  free(left);"
         , "  free(right);"
         , "  if (order != 0) return order;"
         , "  return (left_count > right_count) - (left_count < right_count);"
         , "}" ])
  , helper "comparable" ("tree_walk" : snd (memberComparable key "") <> foldMap (\held -> snd (memberComparable held "")) value)
      [ "static int " <> name "comparable" <> "(pudu_box *box) {"
      , "  size_t count = pudu_tree_size(box->fields[0].tree);"
      , "  pudu_tree_node **nodes = pudu_tree_nodes(box->fields[0].tree);"
      , "  int comparable = 1;"
      , "  for (size_t i = 0; i < count && comparable; ++i)"
      , "    comparable = " <> fst (memberComparable key ("nodes[i]->key." <> cellName key))
          <> foldMap (\held -> " && " <> fst (memberComparable held ("nodes[i]->value." <> cellName held))) value <> ";"
      , "  free(nodes);"
      , "  return comparable;"
      , "}" ]
  ]
 where
  helper operation needs body = (aggregateNeed operation kind, (needs, body))
  name operation = aggregateHelper operation kind
  ops = name "ops" <> "()"
  cellRetain operation held = helper operation (snd (retained held ""))
    (if ownedType held
      then [ "static pudu_cell " <> name operation <> "(pudu_cell cell) {"
           , "  cell." <> cellName held <> " = " <> fst (retained held ("cell." <> cellName held)) <> ";"
           , "  return cell;", "}" ]
      else [ "static pudu_cell " <> name operation <> "(pudu_cell cell) {", "  return cell;", "}" ])
  cellRelease operation held = helper operation [aggregateNeed "drop" held | isAggregate held]
    (if ownedType held
      then [ "static void " <> name operation <> "(pudu_cell cell) {", "  " <> released held ("cell." <> cellName held), "}" ]
      else [ "static void " <> name operation <> "(pudu_cell cell) {", "  (void)cell;", "}" ])

{-| A new array of one thing per entry, in key order. -}
walkHelper :: CoreType -> Text -> CoreType -> (Text -> Text) -> [Text]
walkHelper kind operation element item =
  [ "static pudu_box *" <> aggregateHelper operation kind <> "(pudu_box *box) {"
  , "  size_t count = pudu_tree_size(box->fields[0].tree);"
  , "  pudu_tree_node **nodes = pudu_tree_nodes(box->fields[0].tree);"
  , "  pudu_box *array = pudu_array_new(count);"
  , "  pudu_items *items = array->fields[0].items;"
  , "  for (size_t i = 0; i < count; ++i) items->cells[i]." <> cellName element <> " = " <> item "nodes[i]" <> ";"
  , "  items->length = count;"
  , "  free(nodes);"
  , "  return array;"
  , "}" ]
