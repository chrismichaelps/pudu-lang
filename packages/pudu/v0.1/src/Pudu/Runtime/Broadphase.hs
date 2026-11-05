{-# LANGUAGE BangPatterns #-}

{-| @Runtime.Broadphase — overlapping pairs of axis-aligned boxes by sort and sweep

    Boxes arrive as six lanes of bounds. Sorting by minimum x and sweeping each
    box against the following boxes whose x intervals still overlap tests y and
    z only for candidates, so work grows with boxes plus overlaps rather than
    with every pair. Pairs are answered smaller index first, in ascending order. -}
module Pudu.Runtime.Broadphase
  ( overlapPairs
  ) where

import Data.List (sort, sortOn)

import Pudu.Runtime.Lanes (Lanes, laneCount, laneToList)

data Box = Box !Int !Double !Double !Double !Double !Double !Double

{-| Flattened overlapping pairs, or Nothing when the lanes differ in count or a
    box has a NaN bound or a minimum above its maximum. Touching boxes overlap. -}
overlapPairs :: [Lanes] -> Maybe [Int]
overlapPairs lanes = case lanes of
  [minX, maxX, minY, maxY, minZ, maxZ]
    | any ((/= laneCount minX) . laneCount) [maxX, minY, maxY, minZ, maxZ] -> Nothing
    | otherwise ->
        let boxes = zipWith7 Box [0 ..] (laneToList minX) (laneToList maxX) (laneToList minY)
              (laneToList maxY) (laneToList minZ) (laneToList maxZ)
         in if all valid boxes
              then Just (concatMap (\(i, j) -> [i, j]) (sort (sweep (sortOn lowX boxes))))
              else Nothing
  _ -> Nothing
  where
    lowX (Box index x0 _ _ _ _ _) = (x0, index)
    valid (Box _ x0 x1 y0 y1 z0 z1) = ordered x0 x1 && ordered y0 y1 && ordered z0 z1
    ordered low high = not (isNaN low || isNaN high) && low <= high

sweep :: [Box] -> [(Int, Int)]
sweep sorted = case sorted of
  [] -> []
  current : rest -> candidates current rest (sweep rest)
  where
    candidates box@(Box i _ x1 y0 y1 z0 z1) others found = case others of
      Box j ox0 _ oy0 oy1 oz0 oz1 : remaining
        | ox0 > x1 -> found
        | oy0 <= y1 && y0 <= oy1 && oz0 <= z1 && z0 <= oz1 ->
            candidates box remaining (pair i j : found)
        | otherwise -> candidates box remaining found
      [] -> found
    pair !i !j = if i < j then (i, j) else (j, i)

zipWith7 :: (a -> b -> c -> d -> e -> f -> g -> h) -> [a] -> [b] -> [c] -> [d] -> [e] -> [f] -> [g] -> [h]
zipWith7 f (a : as) (b : bs) (c : cs) (d : ds) (e : es) (g : gs) (h : hs) =
  f a b c d e g h : zipWith7 f as bs cs ds es gs hs
zipWith7 _ _ _ _ _ _ _ _ = []
