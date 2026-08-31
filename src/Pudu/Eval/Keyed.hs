{-| @Eval.Keyed.Module — map and set runtime semantics -}
module Pudu.Eval.Keyed
  ( mapContainsKey
  , mapEntries
  , mapFromEntries
  , mapGet
  , mapInsert
  , mapKeys
  , mapMerge
  , mapRemove
  , mapSize
  , setContains
  , setDifference
  , setFromMembers
  , setInsert
  , setIntersect
  , setMembers
  , setRemove
  , setIsEmpty
  , setSize
  , setUnion
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Eval.Order (OrdValue (..))
import Pudu.Eval.Value (Value (..))

{-| Entries are kept sorted by key and free of duplicates.

    That invariant is what makes two maps with the same entries equal however
    they were built, which is what a reader expects of a map and what the
    structural equality the language already has would otherwise get wrong. A
    balanced tree keyed by the runtime's order holds it by construction, so no
    operation here has to re-establish it. -}
mapFromEntries :: [(Value, Value)] -> Value
mapFromEntries = MapValue . foldl addEntry Map.empty
 where
  addEntry entries (key, held) = insertEntry key held entries

{-| A repeated key keeps the key it was first stored under and takes the new
    value, matching every other map a reader has used.

    `insertWith` rather than `insert`, which would replace the key as well. Two
    keys can be equal to the order and still be distinguishable values — `1` and
    `1.0` compare equal — and a map whose keys changed shape on an overwrite
    would render differently after a write that only replaced a value. -}
insertEntry :: Value -> Value -> Map.Map OrdValue Value -> Map.Map OrdValue Value
insertEntry key held = Map.insertWith const (OrdValue key) held

mapSize :: Value -> Int
mapSize (MapValue entries) = Map.size entries
mapSize _ = 0

mapGet :: Value -> Value -> Maybe Value
mapGet (MapValue entries) key = Map.lookup (OrdValue key) entries
mapGet _ _ = Nothing

mapContainsKey :: Value -> Value -> Bool
mapContainsKey (MapValue entries) key = Map.member (OrdValue key) entries
mapContainsKey _ _ = False

mapInsert :: Value -> Value -> Value -> Value
mapInsert (MapValue entries) key held = MapValue (insertEntry key held entries)
mapInsert other _ _ = other

mapRemove :: Value -> Value -> Value
mapRemove (MapValue entries) key = MapValue (Map.delete (OrdValue key) entries)
mapRemove other _ = other

mapKeys :: Value -> [Value]
mapKeys (MapValue entries) = map unOrdValue (Map.keys entries)
mapKeys _ = []

mapEntries :: Value -> [(Value, Value)]
mapEntries (MapValue entries) = [(unOrdValue key, held) | (key, held) <- Map.toAscList entries]
mapEntries _ = []

{-| The right map's entries win, because merging is how a caller applies an
    override on top of a default, and the override is what they wrote last.

    `union` is left-biased, so the right map is the one named first. -}
mapMerge :: Value -> Value -> Value
mapMerge (MapValue left) (MapValue right) = MapValue (Map.union right left)
mapMerge other _ = other

{-| A member equal to one already held leaves the held one in place.

    `Set.insert` and `Set.fromList` would replace it instead, which is invisible
    for members that are identical and wrong for members that are merely equal:
    `1` and `1.0` compare equal and do not print alike, so replacing would let a
    set change how it reads when it gained nothing. This is the same rule the
    maps follow for keys. -}
setFromMembers :: [Value] -> Value
setFromMembers = SetValue . foldl addMember Set.empty
 where
  addMember members value = insertMember (OrdValue value) members

insertMember :: OrdValue -> Set.Set OrdValue -> Set.Set OrdValue
insertMember value members
  | Set.member value members = members
  | otherwise = Set.insert value members

{-| Whether a set holds nothing.

    Asked directly rather than by counting to zero: a count is a question about
    how many when the first member already settles whether there are any, and
    this is what every yes/no question about two sets ends in. -}
setIsEmpty :: Value -> Bool
setIsEmpty (SetValue members) = Set.null members
setIsEmpty _ = True

setSize :: Value -> Int
setSize (SetValue members) = Set.size members
setSize _ = 0

setContains :: Value -> Value -> Bool
setContains (SetValue members) value = Set.member (OrdValue value) members
setContains _ _ = False

setInsert :: Value -> Value -> Value
setInsert (SetValue members) value = SetValue (insertMember (OrdValue value) members)
setInsert other _ = other

setRemove :: Value -> Value -> Value
setRemove (SetValue members) value = SetValue (Set.delete (OrdValue value) members)
setRemove other _ = other

setMembers :: Value -> [Value]
setMembers (SetValue members) = map unOrdValue (Set.toAscList members)
setMembers _ = []

{-| The three set operations still merge two ordered runs in one pass, which is
    what the ordering is for; they are the structure's own now rather than
    hand-written list merges. -}
setUnion :: Value -> Value -> Value
setUnion (SetValue left) (SetValue right) = SetValue (Set.union left right)
setUnion other _ = other

setIntersect :: Value -> Value -> Value
setIntersect (SetValue left) (SetValue right) = SetValue (Set.intersection left right)
setIntersect other _ = other

setDifference :: Value -> Value -> Value
setDifference (SetValue left) (SetValue right) = SetValue (Set.difference left right)
setDifference other _ = other
