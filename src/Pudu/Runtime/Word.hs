{-| Pure native-word reductions over existing containers, without word-array staging. -}
module Pudu.Runtime.Word
  ( countWords
  ) where

import Data.Bits (popCount)
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
