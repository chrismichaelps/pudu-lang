{-| @Pudu.Backend.Emit.MultiMap — the add helper of a MultiMap record. A
    record held once keeps its box, and a map it holds once inserts into its
    own tree, so the tree runtime reuses every exclusive node and the key's
    array grows in place.

    A map box held once inside a shared record is still reachable from the
    record's other holders, so a map is exclusive only when the record is. -}
module Pudu.Backend.Emit.MultiMap (multiMapHelpers) where

import Data.Text (Text)
import Pudu.Backend.Emit.Cell
import Pudu.Core (CoreType (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))

{-| The helpers for a record laid out as `groups: Map[K, Array[V]]` and
    `occurrences: Map[(K, V), Int]`; none for any other record. -}
multiMapHelpers :: CoreType -> [(Text, CoreType)] -> [(Text, ([Text], [Text]))]
multiMapHelpers record fields = case fields of
  [("groups", groups@(CoreMapType key group@(CoreArrayType value))), ("occurrences", counts@(CoreMapType pair@(CoreTupleType [key', value']) (CoreIntegerType PlatformSigned)))]
    | key == key', value == value' ->
        [ (aggregateNeed "multimap_take" groups, (["tree", aggregateNeed "ops" groups, "array"], taking groups key))
        , (aggregateNeed "multimap_add" record, (needs groups group pair counts, add groups group pair counts key value)) ]
  _ -> []
 where
  -- The key's array, moved out of its node when the map and every node on
  -- the search path are held once, and retained otherwise.
  taking groups key =
    [ "static pudu_box *" <> aggregateHelper "multimap_take" groups <> "(pudu_box *map, " <> cType key <> " key, int exclusive) {"
    , "  const pudu_tree_ops *ops = " <> aggregateHelper "ops" groups <> "();"
    , "  pudu_tree_node *node = map->fields[0].tree;"
    , "  pudu_cell probe;"
    , "  probe." <> cellName key <> " = key;"
    , "  while (node != NULL) {"
    , "    int order;"
    , "    if (node->count != 1) exclusive = 0;"
    , "    order = ops->order(probe, node->key);"
    , "    if (order == 0) {"
    , "      pudu_box *held = node->value.box;"
    , "      if (exclusive) node->value.box = NULL;"
    , "      else pudu_box_retain(held);"
    , "      return held;"
    , "    }"
    , "    node = order < 0 ? node->left : node->right;"
    , "  }"
    , "  return pudu_array_new(0);"
    , "}" ]
  needs groups group pair counts =
    [ "tree_insert", "fail", aggregateNeed "multimap_take" groups
    , aggregateNeed "push" group, aggregateNeed "drop" group
    , aggregateNeed "make" pair, aggregateNeed "drop" pair
    , aggregateNeed "ops" groups, aggregateNeed "keyretain" groups, aggregateNeed "put" groups, aggregateNeed "drop" groups
    , aggregateNeed "ops" counts, aggregateNeed "keyretain" counts, aggregateNeed "put" counts, aggregateNeed "drop" counts
    , aggregateNeed "lookup_default" counts, aggregateNeed "make" record ]
  add groups group pair counts key value =
    [ "/* A value added under a key, after any already there. A full occurrence"
    , "   count refuses at the call before anything changes. */"
    , "static pudu_box *" <> aggregateHelper "multimap_add" record <> "(pudu_box *record, " <> cType key <> " key, " <> cType value <> " value, const pudu_site *site) {"
    , "  int exclusive = record->count == 1;"
    , "  pudu_box *groups = record->fields[0].box, *counts = record->fields[1].box;"
    , "  int own_groups = exclusive && groups->count == 1, own_counts = exclusive && counts->count == 1;"
    , "  pudu_box *pair = " <> aggregateHelper "make" pair <> "(key, value);"
    , "  pudu_int count = " <> aggregateHelper "lookup_default" counts <> "(counts, pair);"
    , "  if (!count.negative && count.bits >= (uint64_t)INT64_MAX) {"
    , "    " <> aggregateHelper "drop" pair <> "(pair);"
    , "    pudu_fail(site);"
    , "  }"
    , "  pudu_box *group = " <> aggregateHelper "multimap_take" groups <> "(groups, key, own_groups);"
    , "  pudu_box *grown = " <> aggregateHelper "push" group <> "(group, value);"
    , "  pudu_box *next_groups, *next_counts;"
    , "  pudu_cell held, stored;"
    , "  " <> aggregateHelper "drop" group <> "(group);"
    , "  count.bits += 1;"
    , "  held." <> cellName key <> " = key;"
    , "  stored.box = grown;"
    , "  if (own_groups) {"
    , "    groups->fields[0].tree = pudu_tree_insert(groups->fields[0].tree, " <> aggregateHelper "keyretain" groups <> "(held), stored, 0, " <> aggregateHelper "ops" groups <> "());"
    , "    next_groups = pudu_box_retain(groups);"
    , "  } else {"
    , "    next_groups = " <> aggregateHelper "put" groups <> "(groups, key, grown);"
    , "    " <> aggregateHelper "drop" group <> "(grown);"
    , "  }"
    , "  held.box = pair;"
    , "  stored.integer = count;"
    , "  if (own_counts) {"
    , "    counts->fields[0].tree = pudu_tree_insert(counts->fields[0].tree, " <> aggregateHelper "keyretain" counts <> "(held), stored, 0, " <> aggregateHelper "ops" counts <> "());"
    , "    next_counts = pudu_box_retain(counts);"
    , "  } else next_counts = " <> aggregateHelper "put" counts <> "(counts, pair, count);"
    , "  " <> aggregateHelper "drop" pair <> "(pair);"
    , "  if (exclusive) {"
    , "    " <> aggregateHelper "drop" groups <> "(record->fields[0].box);"
    , "    record->fields[0].box = next_groups;"
    , "    " <> aggregateHelper "drop" counts <> "(record->fields[1].box);"
    , "    record->fields[1].box = next_counts;"
    , "    return pudu_box_retain(record);"
    , "  }"
    , "  {"
    , "    pudu_box *made = " <> aggregateHelper "make" record <> "(next_groups, next_counts);"
    , "    " <> aggregateHelper "drop" groups <> "(next_groups);"
    , "    " <> aggregateHelper "drop" counts <> "(next_counts);"
    , "    return made;"
    , "  }"
    , "}" ]
