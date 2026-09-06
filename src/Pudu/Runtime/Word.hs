{-| Pure native-word reductions over existing containers, without word-array staging. -}
module Pudu.Runtime.Word
  ( WordOperation (..)
  , combineMaps
  , countWords
  ) where

import Data.Bits (popCount, complement, xor, (.&.), (.|.))
import qualified Data.Map.Strict as Map
import Data.Foldable (foldl')
import Data.Word (Word64)

{-| Retain the first projection failure and force each successful accumulated count.
    The caller owns representation checks; the kernel only receives native words. -}
countWords :: Foldable f => (a -> Either e Word64) -> f a -> Either e Integer
countWords project = foldl' step (Right 0)
 where
  step failed@(Left _) _ = failed
  step (Right total) value = case project value of
    Left problem -> Left problem
    Right word ->
      let next = total + fromIntegral (popCount word)
       in next `seq` Right next
{-# INLINE countWords #-}

{-| Closed operations on sparse words; absent keys mean zero. -}
data WordOperation = WordUnion | WordIntersection | WordDifference | WordSymmetricDifference

combineMaps :: Ord k => WordOperation -> Map.Map k Word64 -> Map.Map k Word64 -> Map.Map k Word64
combineMaps operation = Map.mergeWithKey matched leftOnly rightOnly
 where
  nonzero word = if word == 0 then Nothing else Just word
  keep = Map.filter (/= 0)
  matched _ left right = nonzero $ case operation of
    WordUnion -> left .|. right
    WordIntersection -> left .&. right
    WordDifference -> left .&. complement right
    WordSymmetricDifference -> left `xor` right
  leftOnly = case operation of
    WordIntersection -> const Map.empty
    _ -> keep
  rightOnly = case operation of
    WordUnion -> keep
    WordSymmetricDifference -> keep
    _ -> const Map.empty
{-# INLINE combineMaps #-}
