{-| Pure internal collection storage kernels, independent of evaluator values. -}
module Pudu.Runtime.Collection
  ( buildMap
  , buildSet
  , mapSequence
  , setSequence
  , intMapSequence
  ) where

import Data.List (foldl')
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Sequence as Seq

buildMap :: Ord k => [(k, v)] -> Map.Map k v
buildMap input =
  let (prefix, remaining) = ascendingPrefix fst keepKey input
   in foldl' insert (Map.fromDistinctAscList (reverse prefix)) remaining
 where
  keepKey (key, _) (_, value) = (key, value)
  insert table (key, value) = Map.insertWith const key value table
{-# INLINE buildMap #-}

buildSet :: Ord a => [a] -> Set.Set a
buildSet input =
  let (prefix, remaining) = ascendingPrefix id const input
   in foldl' insert (Set.fromDistinctAscList (reverse prefix)) remaining
 where
  insert members value
    | Set.member value members = members
    | otherwise = Set.insert value members
{-# INLINE buildSet #-}

{-| Only the canonical ascending prefix reaches the unchecked bulk constructor. -}
ascendingPrefix :: Ord k => (a -> k) -> (a -> a -> a) -> [a] -> ([a], [a])
ascendingPrefix key combine input = case input of
  [] -> ([], [])
  first : rest -> collect first [] rest
 where
  collect previous earlier [] = (previous : earlier, [])
  collect previous earlier pending@(next : rest) = case compare (key previous) (key next) of
    LT -> collect next (previous : earlier) rest
    EQ -> let merged = combine previous next
           in merged `seq` collect merged earlier rest
    GT -> (previous : earlier, pending)
{-# INLINE ascendingPrefix #-}

mapSequence :: (k -> v -> a) -> Map.Map k v -> Seq.Seq a
mapSequence project = Map.foldlWithKey' (\out key value -> out Seq.|> project key value) Seq.empty
{-# INLINE mapSequence #-}

setSequence :: (a -> b) -> Set.Set a -> Seq.Seq b
setSequence project = Set.foldl' (\out value -> out Seq.|> project value) Seq.empty
{-# INLINE setSequence #-}

intMapSequence :: (Int -> v -> a) -> IntMap.IntMap v -> Seq.Seq a
intMapSequence project = IntMap.foldlWithKey' (\out key value -> out Seq.|> project key value) Seq.empty
{-# INLINE intMapSequence #-}
