{-| Pure native-word reductions over existing containers, without word-array staging. -}
module Pudu.Runtime.Word
  ( WordPredicate (..)
  , compareMaps
  , WordOperation (..)
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

{-| Predicates retain left-first visitation even when either input is smaller. -}
data WordPredicate = WordSubset | WordDisjoint

compareMaps :: Ord k => WordPredicate -> (a -> Either e Word64)
  -> Map.Map k a -> Map.Map k a -> Either e Bool
compareMaps predicate project left right = Map.foldrWithKey step (Right True) left
 where
  step key value remaining = do
    a <- project value
    b <- maybe (Right 0) project (Map.lookup key right)
    let holds = case predicate of
          WordSubset -> a .&. complement b == 0
          WordDisjoint -> a .&. b == 0
    if holds then remaining else Right False
{-# INLINE compareMaps #-}
