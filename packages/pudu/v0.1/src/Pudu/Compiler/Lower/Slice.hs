{-| @Pudu.Compiler.Lower.Slice — exact bounds checks for bracket slices. -}
module Pudu.Compiler.Lower.Slice (lowerRangeIndex) where

import Data.List (mapAccumL)
import Pudu.Compiler.Lower.Arguments (collectArguments, exactPosition, integerComparison)
import Pudu.Compiler.Lower.Array (stopped, stops)
import Pudu.Compiler.Lower.Dynamic (invalidRuntimeIndex, mapRuntimeChoice)
import Pudu.Compiler.Lower.Range (selectRangeEndpoint)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))

type LowerExpression = LowerState -> Located Expression -> Lowered
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

lowerRangeIndex :: LowerExpression -> LowerState -> Located Expression -> Located Expression -> Maybe Lowered
lowerRangeIndex lower state receiver key@(Located at keyShape)
  | Just kind <- typeForSpan types (locatedSpan receiver), sliceable kind = case keyShape of
      RangeExpression start inclusive end -> Just $
        withOperands (receiver : foldMap pure start <> foldMap pure end) $ \ready -> \case
          [held, low, high] -> written ready held (Just low) inclusive (Just high)
          [held, bound] | Just _ <- start -> written ready held (Just bound) inclusive Nothing
          [held, bound] -> written ready held Nothing inclusive (Just bound)
          [held] -> written ready held Nothing inclusive Nothing
          _ -> refused ready
      _ | typeForSpan types at == Just CoreRangeType -> Just $
        withOperands [receiver, key] $ \ready -> \case
          [held, range] -> stored ready held range
          _ -> refused ready
      _ -> Nothing
  | otherwise = Nothing
 where
  types = contextTypes (lowerContext state)
  withOperands inputs consume = case collectArguments lower state inputs of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | otherwise ->
          let hold current value = bindLocal current "" (coreExpressionType value)
              (bound, locals) = mapAccumL hold after cores
              (ready, result) = consume bound (map reading locals)
           in (ready, wrap (zipWith declare locals cores) <$> result)

  written current held low inclusive high =
    withEndpoint current low $ \withLow safeLow ->
      withEndpoint withLow high $ \withHigh safeHigh ->
        selectReceiver withHigh held [] $ \ready container ->
          let hasEnd = boolean (maybe False (const True) safeHigh)
           in slice ready container (maybe zero id safeLow) (maybe zero id safeHigh) hasEnd (boolean inclusive)

  withEndpoint current Nothing consume = consume current Nothing
  withEndpoint current (Just operand) consume =
    selectRangeEndpoint at current operand (\ready value -> consume ready (Just value))

  stored current held range
    | Just selected <- mapRuntimeChoice current at CoreNeverType range
        (\ready alternative -> fmap (fmap fst) (stored ready held alternative)) = selected
    | coreExpressionType range == CoreRangeType =
        selectReceiver current held [] $ \ready container ->
          let field name kind = expression kind (CoreRangeMethod name range [])
           in slice ready container (field RangeStartOf intType) (field RangeEndOf intType)
                (field RangeHasEnd CoreBoolType) (field RangeIsInclusiveOf CoreBoolType)
    | otherwise = selectReceiver current held [range] (\ready target -> invalid ready target [range])

  selectReceiver current held extras consume
    | Just selected <- mapRuntimeChoice current at CoreNeverType held
        (\ready selected -> fmap (fmap fst) (selectReceiver ready selected extras consume)) = selected
    | sliceable (coreExpressionType held) = consume current held
    | otherwise = invalid current held extras

  invalid current held extras =
    let (ready, failure) = invalidRuntimeIndex current at held extras
     in (ready, Just (failure, CoreNeverType))

  slice current container low high hasEnd inclusive =
    let kind = coreExpressionType container
        (withSize, size) = bindLocal current "" intType
        (withLow, start) = bindLocal withSize "" (coreExpressionType low)
        (withHigh, end) = bindLocal withLow "" (coreExpressionType high)
        (ready, stop) = bindLocal withHigh "" intType
        lengthOf = case kind of
          CoreTextType -> expression intType (CoreTextMethod TextLength container [])
          CoreBytesType -> expression intType (CoreBytesMethod BytesLengthOf container [])
          _ -> expression intType (CoreArrayMethod ArrayLengthOf container [])
        startOutside = either' (compare' CoreLess (reading start) zero)
          (compare' CoreGreater (reading start) (reading size))
        endOutside = both hasEnd (either' (compare' CoreLess (reading end) zero)
          (choose CoreBoolType inclusive (compare' CoreGreaterOrEqual (reading end) (reading size))
            (compare' CoreGreater (reading end) (reading size))))
        (_, startIndex) = exactPosition at (reading start)
        (_, endIndex) = exactPosition at (reading end)
        stopValue = choose intType hasEnd
          (choose intType inclusive (expression intType (CoreBinary CoreAdd endIndex one)) endIndex)
          (reading size)
        lengthHelp = foldl1 (\a b -> expression CoreTextType (CoreBinary CoreAdd a b))
          [text "the range must lie within the value; it has ", expression CoreTextType (CoreDisplay (reading size)), text " elements"]
        bounds = [startIndex, reading stop]
        sliceOf = case kind of
          CoreTextType -> expression kind (CoreTextMethod TextSlice container bounds)
          CoreBytesType -> expression kind (CoreBytesMethod BytesSliceOf container bounds)
          _ -> expression kind (CoreArrayMethod ArraySliceOf container bounds)
        statements =
          [ declare size lengthOf
          , declare start low
          , declare end high
          , when' (either' startOutside endOutside) (fail' "slice range out of bounds" Nothing (Just lengthHelp))
          , declare stop stopValue
          , when' (compare' CoreLess (reading stop) startIndex)
              (fail' "slice range ends before it starts" (Just "write the lower bound first") Nothing) ]
     in (ready, Just (wrap statements (sliceOf, kind)))

  wrap statements (value, kind) = (expression kind (CoreBlockValue (CoreBlock statements (Just value))), kind)
  sliceable kind = case kind of
    CoreArrayType _ -> True
    CoreTextType -> True
    CoreBytesType -> True
    _ -> False
  expression = CoreExpression at
  statement = CoreStatement at
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  declare local value = statement (CoreDeclare local value)
  number = expression intType . CoreIntegerLiteral PlatformSigned
  zero = number 0
  one = number 1
  boolean = expression CoreBoolType . CoreBoolLiteral
  text = expression CoreTextType . CoreTextLiteral
  compare' = integerComparison at
  both a b = expression CoreBoolType (CoreBinary CoreAnd a b)
  either' a b = expression CoreBoolType (CoreBinary CoreOr a b)
  choose kind test yes no = expression kind (CoreIfValue test (CoreBlock [] (Just yes)) no)
  when' condition failure = statement (CoreIf condition (CoreBlock [statement (CoreEvaluate failure)] Nothing) Nothing)
  fail' message help computed = expression CoreNeverType (CoreFailText "E7004" help (text message) computed)
