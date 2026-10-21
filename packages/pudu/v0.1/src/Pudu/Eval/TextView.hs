{-| @Eval.TextView.Module — byte-addressed reads of a Str for Std.StringView -}
module Pudu.Eval.TextView
  ( callTextByteSize
  , callTextByteSlice
  , callTextByteFind
  , callTextByteFindLast
  , callTextScalarAt
  , byteSlice
  , byteFind
  , byteFindLast
  , scalarAt
  ) where

import Data.Bits ((.&.))
import qualified Data.Text as Text
import qualified Data.Text.Array as TextArray
import Data.Text.Internal (Text (..))
import Data.Text.Internal.Search (indices)
import Data.Text.Unsafe (Iter (..), dropWord8, iter, lengthWord8, takeWord8)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.Source (Span)

someValue :: Value -> Value
someValue v = VariantValue "Some" [v]

noneValue :: Value
noneValue = VariantValue "None" []

{-| Whether a byte offset in `0..=size` starts a scalar or ends the text. -}
isScalarBoundary :: Text -> Integer -> Bool
isScalarBoundary (Text array offset size) at
  | at < 0 || at > toInteger size = False
  | at == toInteger size = True
  | otherwise = TextArray.unsafeIndex array (offset + fromInteger at) .&. 0xC0 /= 0x80

callTextByteSize :: Span -> [Value] -> Evaluator Value
callTextByteSize spanValue arguments = case arguments of
  [StrValue text] -> pure (intOf (toInteger (lengthWord8 text)))
  [_] -> abortAt (Just spanValue) "E7001" "textByteSize expects a Str" Nothing
  _ -> abortAt (Just spanValue) "E7003" "textByteSize expects one argument" Nothing

{-| The bytes from `start` up to `end`, sharing the source's array, when both
    are scalar boundaries in order. -}
byteSlice :: Text -> Integer -> Integer -> Maybe Text
byteSlice text start end
  | start <= end && isScalarBoundary text start && isScalarBoundary text end =
      Just (takeWord8 (fromInteger (end - start)) (dropWord8 (fromInteger start) text))
  | otherwise = Nothing

{-| The first match of a needle at or after `from`. A match of well-formed
    UTF-8 starts on a leading byte, so it is always on a scalar boundary. -}
byteFind :: Text -> Text -> Integer -> Maybe Integer
byteFind text needle from
  | from < 0 || from > toInteger (lengthWord8 text) = Nothing
  | Text.null needle = Just from
  | otherwise = case indices needle (dropWord8 (fromInteger from) text) of
      found : _ -> Just (from + toInteger found)
      [] -> Nothing

{-| The last match, overlapping ones included, found by comparing backwards
    from the last offset a match could start at. -}
byteFindLast :: Text -> Text -> Maybe Integer
byteFindLast (Text array offset size) (Text needleArray needleOffset width)
  | width == 0 = Just (toInteger size)
  | otherwise = toInteger <$> go (size - width)
 where
  go at
    | at < 0 = Nothing
    | matchesAt at 0 = Just at
    | otherwise = go (at - 1)
  matchesAt at index
    | index == width = True
    | TextArray.unsafeIndex array (offset + at + index)
        /= TextArray.unsafeIndex needleArray (needleOffset + index) = False
    | otherwise = matchesAt at (index + 1)

{-| The scalar starting at a byte offset, with how many bytes encode it. -}
scalarAt :: Text -> Integer -> Maybe (Char, Int)
scalarAt text at
  | at < toInteger (lengthWord8 text) && isScalarBoundary text at =
      let Iter scalar width = iter text (fromInteger at) in Just (scalar, width)
  | otherwise = Nothing

callTextByteSlice :: Span -> [Value] -> Evaluator Value
callTextByteSlice spanValue arguments = case arguments of
  [StrValue text, IntValue _ start, IntValue _ end] ->
    pure (maybe noneValue (someValue . StrValue) (byteSlice text start end))
  [_, _, _] -> abortAt (Just spanValue) "E7001" "textByteSlice expects a Str and two Int offsets" Nothing
  _ -> abortAt (Just spanValue) "E7003" "textByteSlice expects three arguments" Nothing

callTextByteFind :: Span -> [Value] -> Evaluator Value
callTextByteFind spanValue arguments = case arguments of
  [StrValue text, StrValue needle, IntValue _ from] ->
    pure (maybe noneValue (someValue . intOf) (byteFind text needle from))
  [_, _, _] -> abortAt (Just spanValue) "E7001" "textByteFind expects two Str values and an Int offset" Nothing
  _ -> abortAt (Just spanValue) "E7003" "textByteFind expects three arguments" Nothing

callTextByteFindLast :: Span -> [Value] -> Evaluator Value
callTextByteFindLast spanValue arguments = case arguments of
  [StrValue text, StrValue needle] ->
    pure (maybe noneValue (someValue . intOf) (byteFindLast text needle))
  [_, _] -> abortAt (Just spanValue) "E7001" "textByteFindLast expects two Str values" Nothing
  _ -> abortAt (Just spanValue) "E7003" "textByteFindLast expects two arguments" Nothing

callTextScalarAt :: Span -> [Value] -> Evaluator Value
callTextScalarAt spanValue arguments = case arguments of
  [StrValue text, IntValue _ at] ->
    pure $ case scalarAt text at of
      Just (scalar, width) -> someValue (TupleValue [CharValue scalar, intOf (toInteger width)])
      Nothing -> noneValue
  [_, _] -> abortAt (Just spanValue) "E7001" "textScalarAt expects a Str and an Int offset" Nothing
  _ -> abortAt (Just spanValue) "E7003" "textScalarAt expects two arguments" Nothing
