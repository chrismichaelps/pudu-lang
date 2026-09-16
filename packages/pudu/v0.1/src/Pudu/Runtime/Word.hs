{-| Pure native-word reductions over existing containers, without word-array staging. -}
module Pudu.Runtime.Word
  ( WordPredicate (..)
  , compareMaps
  , WordOperation (..)
  , combineMaps
  , combineMapsWith
  , countWords
  , unpackWords
  ) where

import Data.Bits (popCount, countTrailingZeros, complement, xor, (.&.), (.|.))
import qualified Data.Map.Strict as Map
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
combineMaps operation = combineMapsWith operation id id
{-# INLINE combineMaps #-}

{-| Project only words needed by the merge and encode directly into the result tree.
    Representation validation, when required, belongs to the caller before this pure kernel. -}
combineMapsWith :: Ord k => WordOperation -> (a -> Word64) -> (Word64 -> a)
  -> Map.Map k a -> Map.Map k a -> Map.Map k a
combineMapsWith operation project encode = Map.mergeWithKey matched leftOnly rightOnly
 where
  nonzero word = if word == 0 then Nothing else Just (encode word)
  keep = Map.mapMaybe (nonzero . project)
  matched _ left right =
    let a = project left
        b = project right
     in nonzero $ case operation of
          WordUnion -> a .|. b
          WordIntersection -> a .&. b
          WordDifference -> a .&. complement b
          WordSymmetricDifference -> a `xor` b
  leftOnly = case operation of
    WordIntersection -> const Map.empty
    _ -> keep
  rightOnly = case operation of
    WordUnion -> keep
    WordSymmetricDifference -> keep
    _ -> const Map.empty
{-# INLINE combineMapsWith #-}

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

{-| Unpack set bit positions in ascending order, prepending onto an existing list. -}
unpackWords :: Word64 -> Word64 -> [Word64] -> [Word64]
unpackWords _ 0 rest = rest
unpackWords base w rest =
  let tz = countTrailingZeros w
      idVal = base .|. fromIntegral tz
   in idVal : unpackWords base (w .&. (w - 1)) rest
{-# INLINE unpackWords #-}
