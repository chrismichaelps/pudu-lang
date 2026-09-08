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
  , arrayConcat
  , arrayReverse
  , arrayIndexOf
  , arrayContains
  ) where

import Data.Foldable (toList)
import Data.Maybe (fromMaybe)
import qualified Data.Sequence as Seq
import Pudu.Eval.Value (Value (..))

{-| Build an array value from a list of evaluated values. -}
arrayFromList :: [Value] -> Value
arrayFromList = ArrayValue . Seq.fromList

{-| Flatten an array value to a list for iteration. -}
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
arrayPop (ArrayValue members) = case Seq.viewr members of
  Seq.EmptyR -> ArrayValue members
  remaining Seq.:> _ -> ArrayValue remaining
arrayPop _ = NullValue

{-| O(log n) insert at index. Clamps to the end. -}
arrayInsert :: Value -> Int -> Value -> Value
arrayInsert (ArrayValue members) index value
  | index <= 0 = ArrayValue (value Seq.<| members)
  | index >= Seq.length members = ArrayValue (members Seq.|> value)
  | otherwise = ArrayValue (Seq.insertAt index value members)
arrayInsert _ _ _ = NullValue

{-| O(log n) remove at index. No-op if out of bounds. -}
arrayRemove :: Value -> Int -> Value
arrayRemove (ArrayValue members) index
  | index >= 0 && index < Seq.length members =
      ArrayValue (Seq.deleteAt index members)
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

{-| O(log(min(n, m))) concatenation.

    This is why it belongs in the runtime rather than in a library loop: joining
    two fingertrees is logarithmic in the smaller one, while appending element by
    element is O(m log n). A library that reimplemented it would be slower than
    the structure it was built on. -}
arrayConcat :: Value -> Value -> Value
arrayConcat (ArrayValue left) (ArrayValue right) = ArrayValue (left Seq.>< right)
arrayConcat _ _ = NullValue

{-| O(n) reversed array. -}
arrayReverse :: Value -> Value
arrayReverse (ArrayValue members) = ArrayValue (Seq.reverse members)
arrayReverse _ = NullValue

{-| O(n) linear search. Returns the first index of a matching value, or -1. -}
arrayIndexOf :: Value -> Value -> Int
arrayIndexOf (ArrayValue members) target =
  fromMaybe (-1) (Seq.findIndexL (== target) members)
arrayIndexOf _ _ = -1

{-| O(n) membership test using structural equality. -}
arrayContains :: Value -> Value -> Bool
arrayContains array target = arrayIndexOf array target >= 0
