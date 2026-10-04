{-| @Type.Frontier — selects recent pending facts without walking older state. -}
module Pudu.Type.Frontier (splitSince, splitBetween) where

{-| Creation identities decrease from head to tail. The older suffix is shared. -}
splitSince :: (a -> Int) -> Int -> [a] -> ([a], [a])
splitSince identity checkpoint = span ((>= checkpoint) . identity)

splitBetween :: (a -> Int) -> Int -> Int -> [a] -> ([a], [a])
splitBetween identity start end values
  | start >= end = ([], values)
  | otherwise =
      let (newer, pending) = splitSince identity end values
          (selected, older) = splitSince identity start pending
       in (selected, newer <> older)
