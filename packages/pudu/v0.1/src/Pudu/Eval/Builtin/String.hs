{-| @Program.Eval.Builtin.String — text method dispatch and scalar manipulation -}
module Pudu.Eval.Builtin.String
  ( callStringMethod
  , callStringMethodFast
  , drop1Text
  , dropText
  , indexOfText
  ) where

import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Array as Array
import Data.Text.Internal (Text (..))

import Pudu.Eval.Bytes (bytesFromText)
import Pudu.Eval.Env (Evaluator (..), abortAt)
import Pudu.Eval.Value (StringMethod (..), Value (..), boolValue, intOf, stringMethodName)
import Pudu.Source (Span)

{-| Apply a built-in text method.
    Every one answers with a new value: text is a value, and a method that
    changed its receiver would make two names for one string disagree. Indices
    count Unicode scalars, not bytes, so `charAt` and `slice` agree with what a
    reader counting characters expects — the same choice indexing already makes.

    An index outside the text is `E7004` rather than a clamped or empty answer.
    A silent clamp turns a logic error into wrong output that looks correct. -}
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
callStringMethod spanValue method receiver arguments = case receiver of
  StrValue text -> apply text
  _ -> abortAt (Just spanValue) "E7001" "not text" Nothing
 where
  apply text = case (method, arguments) of
    (StringLength, []) -> pure (intOf (fromIntegral (Text.length text)))
    (StringIsEmpty, []) -> pure (boolValue (Text.null text))
    (StringCharAt, [IntValue _ index]) -> charAt text index
    (StringIndexOf, [StrValue needle]) -> pure (intOf (indexOfText text needle))
    (StringContains, [StrValue needle]) -> pure (boolValue (Text.isInfixOf needle text))
    (StringStartsWith, [StrValue needle]) -> pure (boolValue (Text.isPrefixOf needle text))
    (StringEndsWith, [StrValue needle]) -> pure (boolValue (Text.isSuffixOf needle text))
    (StringDrop, [IntValue _ count])
      | count < 0 -> outOfRange "a drop count cannot be negative"
      | count == 1 -> pure (StrValue (drop1Text text))
      | otherwise -> pure (StrValue (dropText (fromInteger count) text))
    (StringTake, [IntValue _ count])
      | count < 0 -> outOfRange "a take count cannot be negative"
      | otherwise -> pure (StrValue (Text.take (fromInteger count) text))
    (StringSpanOf, [StrValue accepted]) -> pure (spanLength (`Text.elem` accepted) text)
    (StringSpanNotOf, [StrValue rejected]) ->
      pure (spanLength (not . (`Text.elem` rejected)) text)
    (StringSlice, [IntValue _ from, IntValue _ to]) -> slice text from to
    (StringTrim, []) -> pure (StrValue (Text.strip text))
    (StringToUpper, []) -> pure (StrValue (Text.toUpper text))
    (StringToLower, []) -> pure (StrValue (Text.toLower text))
    (StringReplace, [StrValue needle, StrValue replacement])
      | Text.null needle -> pure (StrValue text)
      | otherwise -> pure (StrValue (Text.replace needle replacement text))
    (StringRepeat, [IntValue _ count])
      | count < 0 -> outOfRange "a repeat count cannot be negative"
      | otherwise -> pure (StrValue (Text.replicate (fromInteger count) text))
    (StringSplit, [StrValue separator])
      | Text.null separator -> pure (textArray (Text.chunksOf 1 text))
      | otherwise -> pure (textArray (Text.splitOn separator text))
    (StringToBytes, []) -> pure (bytesFromText text)
    (StringChars, []) -> pure (ArrayValue (Seq.fromList (map CharValue (Text.unpack text))))
    (StringLines, []) -> pure (textArray (Text.lines text))
    (StringReverse, []) -> pure (StrValue (Text.reverse text))
    _ -> wrongStringArity (stringMethodName method)

  textArray = ArrayValue . Seq.fromList . map StrValue

  spanLength holds = intOf . fromIntegral . Text.length . Text.takeWhile holds

  charAt text index
    | index < 0 || index >= fromIntegral (Text.length text) =
        outOfRange "index out of range"
    | otherwise = pure (CharValue (Text.index text (fromInteger index)))

  slice text from to
    | from < 0 = outOfRange "a slice cannot start before the text"
    | to < from = outOfRange "a slice cannot end before it starts"
    | otherwise =
        pure
          ( StrValue
              ( Text.take
                  (fromInteger (to - from))
                  (Text.drop (fromInteger from) text)
              )
          )

  outOfRange message = abortAt (Just spanValue) "E7004" message Nothing

  wrongStringArity name =
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> name) Nothing

{-| Low-level O(1) character drop for Text.
    Directly inspects the underlying UTF-8 byte array to advance by the
    exact scalar byte width without decoding character streams or copying buffers. -}
{-# INLINE drop1Text #-}
drop1Text :: Text -> Text
drop1Text (Text arr off len)
  | len <= 0 = Text arr off 0
  | otherwise =
      let !w = Array.unsafeIndex arr off
          !delta
            | w < 0x80 = 1
            | w < 0xE0 = 2
            | w < 0xF0 = 3
            | otherwise = 4
          !d = min len delta
      in Text arr (off + d) (len - d)

{-# INLINE dropText #-}
dropText :: Int -> Text -> Text
dropText !n !t
  | n <= 0 = t
  | n == 1 = drop1Text t
  | otherwise = Text.drop n t

{-| Fast direct dispatch for built-in text methods without intermediate
    StringMethodValue closure allocation or dynamic environment queries. -}
callStringMethodFast :: Span -> Text -> Text -> [Value] -> Maybe (Evaluator Value)
callStringMethodFast spanValue member text arguments = case member of
  "drop" -> Just $ case arguments of
    [IntValue _ count]
      | count < 0 -> abortAt (Just spanValue) "E7004" "a drop count cannot be negative" Nothing
      | count == 1 -> pure (StrValue (drop1Text text))
      | otherwise -> pure (StrValue (dropText (fromInteger count) text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for drop" Nothing
  "isEmpty" -> Just $ case arguments of
    [] -> pure (boolValue (Text.null text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for isEmpty" Nothing
  "length" -> Just $ case arguments of
    [] -> pure (intOf (fromIntegral (Text.length text)))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for length" Nothing
  "charAt" -> Just $ case arguments of
    [IntValue _ index] -> charAtFast spanValue text index
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for charAt" Nothing
  "take" -> Just $ case arguments of
    [IntValue _ count]
      | count < 0 -> abortAt (Just spanValue) "E7004" "a take count cannot be negative" Nothing
      | otherwise -> pure (StrValue (Text.take (fromInteger count) text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for take" Nothing
  "contains" -> Just $ case arguments of
    [StrValue needle] -> pure (boolValue (Text.isInfixOf needle text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for contains" Nothing
  "startsWith" -> Just $ case arguments of
    [StrValue needle] -> pure (boolValue (Text.isPrefixOf needle text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for startsWith" Nothing
  "endsWith" -> Just $ case arguments of
    [StrValue needle] -> pure (boolValue (Text.isSuffixOf needle text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for endsWith" Nothing
  "indexOf" -> Just $ case arguments of
    [StrValue needle] -> pure (intOf (indexOfText text needle))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for indexOf" Nothing
  _ -> Nothing

charAtFast :: Span -> Text -> Integer -> Evaluator Value
charAtFast spanValue text index
  | index < 0 || index >= fromIntegral (Text.length text) =
      abortAt (Just spanValue) "E7004" "index out of range" Nothing
  | otherwise = pure (CharValue (Text.index text (fromInteger index)))

indexOfText :: Text -> Text -> Integer
indexOfText text needle = case Text.breakOn needle text of
  (before, rest)
    | Text.null rest, not (Text.null needle) -> -1
    | otherwise -> fromIntegral (Text.length before)
