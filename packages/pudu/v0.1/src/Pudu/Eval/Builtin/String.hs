{-| @Program.Eval.Builtin.String — text method dispatch and scalar manipulation -}
module Pudu.Eval.Builtin.String
  ( callStringMethod
  , indexOfText
  ) where

import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text

import Pudu.Eval.Bytes (bytesFromText)
import Pudu.Eval.Env (Evaluator (..), abortAt)
import Pudu.Eval.Value (StringMethod (..), Value (..), intOf, stringMethodName)
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
    (StringIsEmpty, []) -> pure (BoolValue (Text.null text))
    (StringCharAt, [IntValue _ index]) -> charAt text index
    (StringIndexOf, [StrValue needle]) -> pure (intOf (indexOfText text needle))
    (StringContains, [StrValue needle]) -> pure (BoolValue (Text.isInfixOf needle text))
    (StringStartsWith, [StrValue needle]) -> pure (BoolValue (Text.isPrefixOf needle text))
    (StringEndsWith, [StrValue needle]) -> pure (BoolValue (Text.isSuffixOf needle text))
    (StringDrop, [IntValue _ count])
      | count < 0 -> outOfRange "a drop count cannot be negative"
      | otherwise -> pure (StrValue (Text.drop (fromInteger count) text))
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

indexOfText :: Text -> Text -> Integer
indexOfText text needle = case Text.breakOn needle text of
  (before, rest)
    | Text.null rest, not (Text.null needle) -> -1
    | otherwise -> fromIntegral (Text.length before)
