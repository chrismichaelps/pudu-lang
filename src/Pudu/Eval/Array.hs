{-| @Eval.Array.Module — array runtime semantics -}
module Pudu.Eval.Array
  ( arrayFromList
  , arrayToList
  , arrayLength
  , arrayIndex
  , arrayPush
  , arrayPop
  , arrayInsert
  , arrayRemove
  , arraySlice
  , arrayReverse
  , arrayIndexOf
  , arrayContains
  ) where

import Data.Foldable (toList)
import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Pudu.Eval.Value (Value (..))

{-| Build an array value from a Haskell list of evaluated values. -}
arrayFromList :: [Value] -> Value
arrayFromList = ArrayValue . Seq.fromList

{-| Flatten an array value to a Haskell list for iteration. -}
arrayToList :: Value -> Maybe [Value]
arrayToList (ArrayValue members) = Just (toList members)
arrayToList _ = Nothing

{-| O(1) element count. -}
arrayLength :: Value -> Maybe Int
arrayLength (ArrayValue members) = Just (Seq.length members)
arrayLength _ = Nothing

{-| O(log n) indexed read. Returns Nothing for out-of-bounds. -}
arrayIndex :: Value -> Int -> Maybe Value
arrayIndex (ArrayValue members) index
  | index >= 0 && index < Seq.length members = Seq.lookup index members
  | otherwise = Nothing
arrayIndex _ _ = Nothing

{-| O(1) append. Returns a new array; the old one is unchanged. -}
arrayPush :: Value -> Value -> Value
arrayPush (ArrayValue members) value = ArrayValue (members Seq.|> value)
arrayPush _ _ = NullValue

{-| O(1) drop last. Returns a new array; no-op on empty. -}
arrayPop :: Value -> Value
arrayPop (ArrayValue members)
  | Seq.null members = ArrayValue members
  | otherwise = ArrayValue (Seq.take (Seq.length members - 1) members)
arrayPop _ = NullValue

{-| O(log n) insert at index. Clamps to the end. -}
arrayInsert :: Value -> Int -> Value -> Value
arrayInsert (ArrayValue members) index value
  | index <= 0 = ArrayValue (value Seq.<| members)
  | index >= Seq.length members = ArrayValue (members Seq.|> value)
  | otherwise = let (before, after) = Seq.splitAt index members
                 in ArrayValue (before Seq.>< (value Seq.<| after))
arrayInsert _ _ _ = NullValue

{-| O(log n) remove at index. No-op if out of bounds. -}
arrayRemove :: Value -> Int -> Value
arrayRemove (ArrayValue members) index
  | index >= 0 && index < Seq.length members =
      let (before, after) = Seq.splitAt index members
       in ArrayValue (before Seq.>< Seq.drop 1 after)
  | otherwise = ArrayValue members
arrayRemove _ _ = NullValue

{-| O(log n) subsequence [start, end). -}
arraySlice :: Value -> Int -> Int -> Value
arraySlice (ArrayValue members) start end'
  | start >= end' = ArrayValue Seq.empty
  | otherwise =
      let len = Seq.length members
          i = max 0 (min start len)
          j = max i (min end' len)
       in ArrayValue (Seq.take (j - i) (Seq.drop i members))
arraySlice _ _ _ = NullValue

{-| O(n) reversed array. -}
arrayReverse :: Value -> Value
arrayReverse (ArrayValue members) = ArrayValue (Seq.reverse members)
arrayReverse _ = NullValue

{-| O(n) linear search. Returns the first index of a matching value, or -1. -}
arrayIndexOf :: Value -> Value -> Int
arrayIndexOf (ArrayValue members) target = go 0 (toList members)
 where
  go i elements = case elements of
    [] -> -1
    head' : rest | head' == target -> i
                 | otherwise -> go (i + 1) rest
arrayIndexOf _ _ = -1

{-| O(n) membership test using structural equality. -}
arrayContains :: Value -> Value -> Bool
arrayContains array target = arrayIndexOf array target >= 0
