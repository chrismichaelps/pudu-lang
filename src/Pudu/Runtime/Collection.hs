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
  let (prefix, remaining) = orderedPrefix fst keepKey input
   in foldl' insert (Map.fromDistinctAscList prefix) remaining
 where
  keepKey (key, _) (_, value) = (key, value)
  insert table (key, value) = Map.insertWith const key value table
{-# INLINE buildMap #-}

buildSet :: Ord a => [a] -> Set.Set a
buildSet input =
  let (prefix, remaining) = orderedPrefix id const input
   in foldl' insert (Set.fromDistinctAscList prefix) remaining
 where
  insert members value
    | Set.member value members = members
    | otherwise = Set.insert value members
{-# INLINE buildSet #-}

{-| Detect either monotone direction and return an ascending canonical prefix.
    Equal representatives combine in input order, independently of direction. -}
orderedPrefix :: Ord k => (a -> k) -> (a -> a -> a) -> [a] -> ([a], [a])
orderedPrefix key combine input = case input of
  [] -> ([], [])
  first : rest -> collect Nothing first [] rest
 where
  finish direction previous earlier = case direction of
    Just GT -> previous : earlier
    _ -> reverse (previous : earlier)
  collect direction previous earlier [] = (finish direction previous earlier, [])
  collect direction previous earlier pending@(next : rest) =
    case compare (key previous) (key next) of
      EQ -> let merged = combine previous next
             in merged `seq` collect direction merged earlier rest
      order
        | maybe True (== order) direction -> collect (Just order) next (previous : earlier) rest
        | otherwise -> (finish direction previous earlier, pending)
{-# INLINE orderedPrefix #-}

mapSequence :: (k -> v -> a) -> Map.Map k v -> Seq.Seq a
mapSequence project = Map.foldlWithKey' (\out key value -> out Seq.|> project key value) Seq.empty
{-# INLINE mapSequence #-}

setSequence :: (a -> b) -> Set.Set a -> Seq.Seq b
setSequence project = Set.foldl' (\out value -> out Seq.|> project value) Seq.empty
{-# INLINE setSequence #-}

intMapSequence :: (Int -> v -> a) -> IntMap.IntMap v -> Seq.Seq a
intMapSequence project = IntMap.foldlWithKey' (\out key value -> out Seq.|> project key value) Seq.empty
{-# INLINE intMapSequence #-}
