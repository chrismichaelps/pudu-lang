{-| @Eval.MultiMap — fused persistent updates for the MultiMap indexes. -}
module Pudu.Eval.MultiMap
  ( callMultiMapAdd
  , callMultiMapContains
  , multiMapPrimitive
  , multiMapWrapper
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Pudu.Eval.Builtin.Collection (unorderableKey)
import Pudu.Eval.Env (Env (..), Evaluator (..), abortAt, callLimit, descend, tally)
import Pudu.Eval.Operator (checkedResult)
import Pudu.Eval.Place (exclusiveParameters)
import Pudu.Eval.Order (comparableValue)
import Pudu.Eval.Value
  ( Builtin (..), Captured (..), Closure (..), Frame (..), IntPairEntry (..), OrdValue (..), Value (..), intOf, intPairMap )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..), Expression (..), Function (..), FunctionBody (..), Parameter (..) )
import Pudu.IntegerLiteral (IntegerKind, defaultIntegerKind, integerKindFits, integerKindMeet)
import Pudu.Source (Span)
import qualified Pudu.Runtime.SeriesMap as SeriesMap

{-| Append and count with one traversal of each index. Both trees remain
    persistent, and overwrites keep the same representative as Map insertion. -}
callMultiMapAdd :: Span -> [Value] -> Evaluator Value
callMultiMapAdd spanValue arguments = case arguments of
  [RecordValue _ fields, key, value]
    | Just (MapValue groups) <- lookup "groups" fields
    , Just occurrences <- lookup "occurrences" fields -> do
        if comparableValue key
          then pure ()
          else unorderableKey spanValue key "map key" >> pure ()
        let (heldGroup, added) = Map.insertLookupWithKey append (OrdValue key)
              (ArrayValue (Seq.singleton value)) groups
        case heldGroup of
          Nothing -> pure ()
          Just ArrayValue{} -> pure ()
          _ -> abortAt (Just spanValue) "E7001" "multiMapAdd expects array groups" Nothing
        let pair = TupleValue [key, value]
        if comparableValue pair
          then pure ()
          else unorderableKey spanValue pair "map key" >> pure ()
        (heldCount, counted) <- insertOccurrence spanValue occurrences key value
        let result = pure (RecordValue "MultiMap" [("groups", MapValue added), ("occurrences", counted)])
        case heldCount of
          Nothing -> result
          Just (IntValue kind count)
            | integerKindFits (integerKindMeet kind defaultIntegerKind) (count + 1) -> result
            | otherwise -> checkedResult spanValue (integerKindMeet kind defaultIntegerKind) "add" (count + 1)
          _ -> abortAt (Just spanValue) "E7001" "multiMapAdd expects Int occurrence counts" Nothing
   where
    append _ _ (ArrayValue members) = ArrayValue (members Seq.|> value)
    append _ _ other = other
  [_, _, _] -> abortAt (Just spanValue) "E7001" "multiMapAdd expects a MultiMap" Nothing
  _ -> abortAt (Just spanValue) "E7003" "multiMapAdd expects three arguments" Nothing

{-| Membership follows the occurrence index without inspecting group arrays. -}
callMultiMapContains :: Span -> [Value] -> Evaluator Value
callMultiMapContains spanValue arguments = case arguments of
  [RecordValue _ fields, key, value]
    | Just occurrences <- lookup "occurrences" fields ->
        containsOccurrence spanValue occurrences key value
  [_, _, _] -> abortAt (Just spanValue) "E7001" "multiMapContains expects a MultiMap" Nothing
  _ -> abortAt (Just spanValue) "E7003" "multiMapContains expects three arguments" Nothing

{-| Only integer pairs fitting the host index enter the numeric representation. -}
integerPair :: Value -> Value -> Maybe (Int, Int, IntegerKind, IntegerKind)
integerPair (IntValue keyKind key) (IntValue valueKind value)
  | fits key && fits value = Just (fromInteger key, fromInteger value, keyKind, valueKind)
 where
  fits number = number >= toInteger (minBound :: Int) && number <= toInteger (maxBound :: Int)
integerPair _ _ = Nothing

insertOccurrence :: Span -> Value -> Value -> Value -> Evaluator (Maybe Value, Value)
insertOccurrence spanValue occurrences key value = case (occurrences, integerPair key value) of
  (IntPairMapValue index _, Just pair) -> pure (indexed index pair)
  (MapValue entries, Just pair) | Map.null entries -> pure (indexed IntMap.empty pair)
  (MapValue entries, _) ->
    let (held, next) = Map.insertLookupWithKey increment
          (OrdValue (TupleValue [key, value])) (intOf 1) entries
     in pure (held, MapValue next)
  _ -> abortAt (Just spanValue) "E7001" "multiMapAdd expects occurrence maps" Nothing
 where
  indexed index (number, member, keyKind, valueKind) =
    let (held, nextIndex) = IntMap.alterF update number index
        entry count
          | keyKind == defaultIntegerKind && valueKind == defaultIntegerKind = PlatformIntPairEntry count
          | otherwise = IntPairEntry keyKind valueKind count
        update existing =
          let values = maybe SeriesMap.empty id existing
              (previous, next) = SeriesMap.insertLookupWithKey sameUnit
                (\_ _ old -> entry (incrementCount (entryCount old)))
                member (entry (intOf 1)) values
           in (fmap entryCount previous, Just next)
     in (held, intPairMap nextIndex)
  sameUnit (PlatformIntPairEntry (IntValue kind 1)) (PlatformIntPairEntry (IntValue other 1)) =
    kind == defaultIntegerKind && other == defaultIntegerKind
  sameUnit _ _ = False
  entryCount (PlatformIntPairEntry count) = count
  entryCount (IntPairEntry _ _ count) = count
  increment _ _ old = incrementCount old
  incrementCount (IntValue kind count) =
    IntValue (integerKindMeet kind defaultIntegerKind) (count + 1)
  incrementCount other = other

containsOccurrence :: Span -> Value -> Value -> Value -> Evaluator Value
containsOccurrence spanValue occurrences key value = case (occurrences, integerPair key value) of
  (IntPairMapValue index _, Just (number, member, _, _)) ->
    pure (BoolValue (maybe False (maybe False (const True) . SeriesMap.lookup member) (IntMap.lookup number index)))
  (MapValue entries, _) ->
    pure (BoolValue (Map.member (OrdValue (TupleValue [key, value])) entries))
  _ -> abortAt (Just spanValue) "E7001" "multiMapContains expects occurrence maps" Nothing

{-| A complete body forwarding its parameters to a captured primitive needs
    neither a parameter frame nor a second call dispatch. Captured identity,
    rather than a function's spelling, proves which operation will run. -}
multiMapWrapper :: Closure -> Maybe (Maybe Span -> [Value] -> Evaluator Value)
multiMapWrapper closure = do
  (innerSpan, builtin) <- if closureSelf closure == Nothing
    then case closureMultiMap closure of
      Just cached -> Just cached
      Nothing -> multiMapPrimitive closure
    else Nothing
  primitive <- case builtin of
    MultiMapAddBuiltin -> Just callMultiMapAdd
    MultiMapContainsBuiltin -> Just callMultiMapContains
    _ -> Nothing
  pure $ \callSpan values -> do
    tally "closure call"
    Evaluator $ \env ->
      let Evaluator run =
            if envDepth env > callLimit
              then descend callSpan >> primitive innerSpan values
              else primitive innerSpan values
       in run env

multiMapPrimitive :: Closure -> Maybe (Span, Builtin)
multiMapPrimitive closure = do
  let function = closureFunction closure
      parameters = functionParameters function
      names = map (locatedValue . parameterName . locatedValue) parameters
  case (functionAsync function, closureSelf closure, names) of
    (False, Nothing, [_, _, _]) -> pure ()
    _ -> Nothing
  if null (exclusiveParameters function) then pure () else Nothing
  if all ((== Nothing) . parameterDefault . locatedValue) parameters then pure () else Nothing
  Located _ body <- functionBody function
  Located innerSpan expression <- case body of
    ExpressionBody inner -> Just inner
    BlockBody (Located _ Block{blockStatements = [], blockResult = Just inner}) -> Just inner
    _ -> Nothing
  CallExpression (Located _ (NameExpression (name :| []))) arguments <- Just expression
  forwarded <- traverse forwardedName arguments
  if forwarded == names && name `notElem` names then pure () else Nothing
  Captured frames _ <- closureCaptured closure
  primitive <- case capturedBinding name frames of
    Just (BuiltinValue MultiMapAddBuiltin) -> Just MultiMapAddBuiltin
    Just (BuiltinValue MultiMapContainsBuiltin) -> Just MultiMapContainsBuiltin
    _ -> Nothing
  pure (innerSpan, primitive)
 where
  forwardedName (Located _ (NameExpression (name :| []))) = Just name
  forwardedName _ = Nothing
  capturedBinding _ [] = Nothing
  capturedBinding name (MapFrame bindings : rest) = case Map.lookup name bindings of
    Just value -> Just value
    Nothing -> capturedBinding name rest
  capturedBinding _ (SlotFrame{} : _) = Nothing
  capturedBinding _ (CellFrame{} : _) = Nothing
