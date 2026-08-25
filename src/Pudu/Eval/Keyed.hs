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
  , setSize
  , setUnion
  ) where

import Pudu.Eval.Order (compareValues)
import Pudu.Eval.Value (Value (..))

{-| Entries are kept sorted by key and free of duplicates.

    That invariant is what makes two maps with the same entries equal however
    they were built, which is what a reader expects of a map and what the
    structural equality the language already has would otherwise get wrong. A
    later insertion of an existing key replaces its value, matching every other
    map a reader has used. -}
mapFromEntries :: [(Value, Value)] -> Value
mapFromEntries = MapValue . foldl insertEntry []

insertEntry :: [(Value, Value)] -> (Value, Value) -> [(Value, Value)]
insertEntry entries (key, held) = case entries of
  [] -> [(key, held)]
  current@(existing, previous) : rest -> case compareValues key existing of
    LT -> (key, held) : current : rest
    EQ -> (existing, held) : rest
    GT -> previous `seq` (current : insertEntry rest (key, held))

mapSize :: Value -> Int
mapSize (MapValue entries) = length entries
mapSize _ = 0

mapGet :: Value -> Value -> Maybe Value
mapGet (MapValue entries) key = lookupEntry entries
 where
  lookupEntry [] = Nothing
  lookupEntry ((existing, held) : rest) = case compareValues key existing of
    LT -> Nothing
    EQ -> Just held
    GT -> lookupEntry rest
mapGet _ _ = Nothing

mapContainsKey :: Value -> Value -> Bool
mapContainsKey value key = mapGet value key /= Nothing

mapInsert :: Value -> Value -> Value -> Value
mapInsert (MapValue entries) key held = MapValue (insertEntry entries (key, held))
mapInsert other _ _ = other

mapRemove :: Value -> Value -> Value
mapRemove (MapValue entries) key = MapValue (without entries)
 where
  without [] = []
  without (current@(existing, _) : rest) = case compareValues key existing of
    LT -> current : rest
    EQ -> rest
    GT -> current : without rest
mapRemove other _ = other

mapKeys :: Value -> [Value]
mapKeys (MapValue entries) = map fst entries
mapKeys _ = []

mapEntries :: Value -> [(Value, Value)]
mapEntries (MapValue entries) = entries
mapEntries _ = []

{-| The right map's entries win, because merging is how a caller applies an
    override on top of a default, and the override is what they wrote last. -}
mapMerge :: Value -> Value -> Value
mapMerge (MapValue left) (MapValue right) = MapValue (foldl insertEntry left right)
mapMerge other _ = other

setFromMembers :: [Value] -> Value
setFromMembers = SetValue . foldl insertMember []

insertMember :: [Value] -> Value -> [Value]
insertMember members value = case members of
  [] -> [value]
  current : rest -> case compareValues value current of
    LT -> value : current : rest
    EQ -> current : rest
    GT -> current : insertMember rest value

setSize :: Value -> Int
setSize (SetValue members) = length members
setSize _ = 0

setContains :: Value -> Value -> Bool
setContains (SetValue members) value = search members
 where
  search [] = False
  search (current : rest) = case compareValues value current of
    LT -> False
    EQ -> True
    GT -> search rest
setContains _ _ = False

setInsert :: Value -> Value -> Value
setInsert (SetValue members) value = SetValue (insertMember members value)
setInsert other _ = other

setRemove :: Value -> Value -> Value
setRemove (SetValue members) value = SetValue (without members)
 where
  without [] = []
  without (current : rest) = case compareValues value current of
    LT -> current : rest
    EQ -> rest
    GT -> current : without rest
setRemove other _ = other

setMembers :: Value -> [Value]
setMembers (SetValue members) = members
setMembers _ = []

{-| The three set operations merge two ordered runs in one pass, which is what
    the sorted invariant is for. -}
setUnion :: Value -> Value -> Value
setUnion (SetValue left) (SetValue right) = SetValue (mergeOrdered left right)
 where
  mergeOrdered [] rest = rest
  mergeOrdered rest [] = rest
  mergeOrdered (a : as) (b : bs) = case compareValues a b of
    LT -> a : mergeOrdered as (b : bs)
    EQ -> a : mergeOrdered as bs
    GT -> b : mergeOrdered (a : as) bs
setUnion other _ = other

setIntersect :: Value -> Value -> Value
setIntersect (SetValue left) (SetValue right) = SetValue (shared left right)
 where
  shared [] _ = []
  shared _ [] = []
  shared (a : as) (b : bs) = case compareValues a b of
    LT -> shared as (b : bs)
    EQ -> a : shared as bs
    GT -> shared (a : as) bs
setIntersect other _ = other

setDifference :: Value -> Value -> Value
setDifference (SetValue left) (SetValue right) = SetValue (missing left right)
 where
  missing rest [] = rest
  missing [] _ = []
  missing (a : as) (b : bs) = case compareValues a b of
    LT -> a : missing as (b : bs)
    EQ -> missing as bs
    GT -> missing (a : as) bs
setDifference other _ = other
