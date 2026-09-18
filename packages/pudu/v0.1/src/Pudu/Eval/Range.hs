{-| @Eval.Range — what a range is, and what can be asked of one.

    A range holds two ends rather than the values between them, so everything
    here is arithmetic until a caller asks for the values themselves. That is
    the whole point of the shape: `0..1_000_000` costs three fields, and only
    `toArray` and the walking methods pay for a million.

    Either end may be absent. An absent end means "as far as the thing this is
    applied to goes", which nothing here can know, so a method that needs a
    number where there is none is refused by name rather than guessing one. The
    one place absence is answered is `rangeBounds`, which is given the length of
    the value being indexed and resolves the range against it. -}
module Pudu.Eval.Range
  ( callRangeMethod
  , rangeBounds
  , rangeElements
  , rangeLength
  , rangeMethods
  , renderRange
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Sequence as Seq

import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (RangeMethod (..), Value (..), intOf, rangeMethodName)
import Pudu.Source (Span)

{-| The methods a range answers to, in the spelling the checker types them by. -}
rangeMethods :: [(Text, RangeMethod)]
rangeMethods =
  [ (rangeMethodName method, method)
  | method <-
      [ RangeLength
      , RangeIsEmpty
      , RangeContains
      , RangeStart
      , RangeEnd
      , RangeIsInclusive
      , RangeIsBounded
      , RangeToArray
      , RangeReverse
      , RangeStep
      , RangeMap
      , RangeFilter
      , RangeReduce
      , RangeSum
      ]
  ]

{-| How many values a bounded range covers, and nothing for one that is not
    bounded at both ends.

    Computed rather than counted: a range is its ends, and asking how far apart
    they are is subtraction whatever lies between them. A range whose end is
    below its start covers nothing rather than a negative count. -}
rangeLength :: Value -> Maybe Integer
rangeLength value = case value of
  RangeValue (Just low) inclusive (Just high) ->
    Just (max 0 (high - low + (if inclusive then 1 else 0)))
  _ -> Nothing

{-| The values a bounded range covers, in order.

    Lazy, so a caller that stops early — `first`, a `for` that breaks — pays
    only for what it read. -}
rangeElements :: Value -> Maybe [Integer]
rangeElements value = case value of
  RangeValue (Just low) inclusive (Just high) ->
    Just (if inclusive then [low .. high] else [low .. high - 1])
  _ -> Nothing

{-| Resolve a range against the length of what it is applied to.

    This is where an absent end is answered: an absent start is the beginning
    and an absent end is the length, which is what makes `items[2..]` the tail
    of a sequence the writer never measured. Both ends are then required to lie
    within the value and to be in order, because a slice that silently clamped
    would hand back a different sequence than the one that was asked for and
    hide the mistake that produced the bounds.

    Answers the half-open pair the sequence types take: the first index and the
    count. -}
rangeBounds :: Span -> Value -> Int -> Evaluator (Int, Int)
rangeBounds spanValue value size = case value of
  RangeValue lower inclusive upper -> do
    let start = maybe 0 id lower
        endExclusive = case upper of
          Nothing -> fromIntegral size
          Just high -> if inclusive then high + 1 else high
    if start < 0 || endExclusive > fromIntegral size
      then
        abortAt (Just spanValue) "E7004" "slice range out of bounds"
          ( Just
              ( "the range must lie within the value; it has "
                  <> Text.pack (show size)
                  <> " elements"
              )
          )
      else
        if endExclusive < start
          then
            abortAt (Just spanValue) "E7004" "slice range ends before it starts"
              (Just "write the lower bound first")
          else pure (fromInteger start, fromInteger (endExclusive - start))
  _ ->
    abortAt (Just spanValue) "E7001" "expected a range" Nothing

{-| A range as it is written, so an inspected one reads back as its source. -}
renderRange :: Maybe Integer -> Bool -> Maybe Integer -> Text
renderRange lower inclusive upper =
  foldMap number lower <> (if inclusive then "..=" else "..") <> foldMap number upper
 where
  number = Text.pack . show

{-| Apply a built-in range method.

    The walking methods are given the evaluator's own function application, so a
    closure written in the language is called the way any other call calls it. -}
callRangeMethod
  :: (Span -> Value -> [Value] -> Evaluator Value)
  -> Span
  -> RangeMethod
  -> Value
  -> [Value]
  -> Evaluator Value
callRangeMethod apply spanValue method receiver arguments =
  case (method, arguments) of
    (RangeLength, []) -> pure (intOf (fromIntegral (maybe 0 id (rangeLength receiver))))
    (RangeIsEmpty, []) -> pure (BoolValue (maybe False (== 0) (rangeLength receiver)))
    (RangeContains, [IntValue _ probe]) -> pure (BoolValue (covers probe))
    (RangeStart, []) -> pure (optionOfInteger lowerBound)
    (RangeEnd, []) -> pure (optionOfInteger upperBound)
    (RangeIsInclusive, []) -> pure (BoolValue inclusiveEnd)
    (RangeIsBounded, []) -> pure (BoolValue (rangeLength receiver /= Nothing))
    (RangeToArray, []) -> arrayOf <$> elements "toArray"
    (RangeReverse, []) -> arrayOf . reverse <$> elements "reverse"
    (RangeStep, [IntValue _ stride])
      | stride <= 0 ->
          abortAt (Just spanValue) "E7004" "a step must be positive"
            (Just "step by one or more; a range only ever counts upward")
      | otherwise -> arrayOf . every (fromInteger stride) <$> elements "step"
    (RangeMap, [function]) -> do
      values <- elements "map"
      mapped <- mapM (\held -> apply spanValue function [intOf (fromIntegral held)]) values
      pure (ArrayValue (Seq.fromList mapped))
    (RangeFilter, [function]) -> do
      values <- elements "filter"
      kept <- filterM (\held -> truthy <$> apply spanValue function [intOf (fromIntegral held)]) values
      pure (arrayOf kept)
    (RangeReduce, [function, initial]) -> do
      values <- elements "reduce"
      foldMWith function initial values
    (RangeSum, []) -> intOf . fromIntegral . sum <$> elements "sum"
    _ ->
      abortAt (Just spanValue) "E7012"
        ("wrong arguments for " <> rangeMethodName method) Nothing
 where
  (lowerBound, inclusiveEnd, upperBound) = case receiver of
    RangeValue low inclusive high -> (low, inclusive, high)
    _ -> (Nothing, False, Nothing)

  covers probe =
    maybe True (probe >=) lowerBound
      && maybe True (\high -> if inclusiveEnd then probe <= high else probe < high) upperBound

  {-| A method that hands back the values needs both ends. Refused by name, so
      the reader is told which method could not be answered rather than being
      left with a loop that does not finish. -}
  elements what = case rangeElements receiver of
    Just values -> pure values
    Nothing ->
      abortAt (Just spanValue) "E7004"
        (what <> " needs a range with both ends")
        (Just "give the range a start and an end, or bound it against a value first")

  arrayOf values = ArrayValue (Seq.fromList (map (intOf . fromIntegral) values))

  every stride = go 0
   where
    go _ [] = []
    go position (held : rest)
      | position `mod` stride == 0 = held : go (position + 1) rest
      | otherwise = go (position + 1) rest

  foldMWith function carried values = case values of
    [] -> pure carried
    held : rest -> do
      next <- apply spanValue function [carried, intOf (fromIntegral held)]
      foldMWith function next rest

  truthy value = case value of
    BoolValue flag -> flag
    _ -> False

  filterM test = go
   where
    go [] = pure []
    go (held : rest) = do
      keep <- test held
      remaining <- go rest
      pure (if keep then held : remaining else remaining)

  optionOfInteger found = case found of
    Just number -> VariantValue "Some" [intOf (fromIntegral number)]
    Nothing -> VariantValue "None" []
