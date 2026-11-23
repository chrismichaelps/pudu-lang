{-| @Pudu.Compiler.Lower.Slice — exact bounds checks for bracket slices. -}
module Pudu.Compiler.Lower.Slice (lowerBracketIndex, lowerIndexOn) where

import Data.List (mapAccumL)
import Data.Maybe (isNothing)
import Pudu.Compiler.Lower.Arguments
  ( ArgumentBlame (AtInvocation), argumentFailure, clampedPosition, collectArguments, exactPosition
  , integerComparison, stopped, stops )
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, invalidRuntimeIndex, joinRuntimeArms, mapRuntimeChoice, preserveRuntimeResult)
import Pudu.Compiler.Lower.Range (selectRangeEndpoint)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, intType, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.Source (Span)
import Pudu.IntegerLiteral (IntegerKind (BigIntKind, PlatformSigned))

type LowerExpression = LowerState -> Located Expression -> Lowered
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

lowerBracketIndex :: LowerExpression -> LowerState -> Span -> Located Expression -> Located Expression -> Lowered
lowerBracketIndex lower state whole receiver key@(Located at keyShape) =
  fmap (fmap preserve) $ case keyShape of
    RangeExpression start inclusive end ->
      withOperands (receiver : foldMap pure start <> foldMap pure end) $ \ready -> \case
        [held, low, high] -> written ready held (Just low) inclusive (Just high)
        [held, bound] | Just _ <- start -> written ready held (Just bound) inclusive Nothing
        [held, bound] -> written ready held Nothing inclusive (Just bound)
        [held] -> written ready held Nothing inclusive Nothing
        _ -> refused ready
    _ -> case collectArguments lower state [receiver, key] of
      (after, Just [held, position]) -> lowerIndexOn after at held position
      (after, Just operands) | any stops operands -> (after, Just (stopped at operands, CoreNeverType))
      (after, _) -> refused after
 where
  types = contextTypes (lowerContext state)
  preserve (value, _) =
    let carried = maybe value (\checked -> preserveRuntimeResult checked value) (typeForSpan types whole)
     in (carried, coreExpressionType carried)
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
           in sliceOn at ready container (maybe zero id safeLow) (maybe zero id safeHigh) hasEnd (boolean inclusive)

  withEndpoint current Nothing consume = consume current Nothing
  withEndpoint current (Just operand) consume =
    selectRangeEndpoint at current operand (\ready value -> consume ready (Just value))

  selectReceiver current held extras consume
    | Just selected <- mapRuntimeChoice current at CoreNeverType held
        (\ready selected -> fmap (fmap fst) (selectReceiver ready selected extras consume)) = selected
    | sliceable (coreExpressionType held) = consume current held
    | otherwise = invalid current held extras

  invalid current held extras =
    let (ready, failure) = invalidRuntimeIndex current at held extras
     in (ready, Just (failure, CoreNeverType))

  wrap statements (value, kind) = (expression kind (CoreBlockValue (CoreBlock statements (Just value))), kind)
  expression = CoreExpression at
  statement = CoreStatement at
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  declare local value = statement (CoreDeclare local value)
  number = expression intType . CoreIntegerLiteral PlatformSigned
  zero = number 0
  boolean = expression CoreBoolType . CoreBoolLiteral

sliceable :: CoreType -> Bool
sliceable kind = case kind of
  CoreArrayType _ -> True
  CoreTextType -> True
  CoreBytesType -> True
  _ -> False

{-| Dispatch by the retained key and receiver. The bracket syntax's
    checked type does not choose the operation once the values run. -}
lowerIndexOn :: LowerState -> Span -> CoreExpression -> CoreExpression -> Lowered
lowerIndexOn state at receiver key
  | any stops operands = (state, Just (stopped at operands, CoreNeverType))
  | any (hasRuntimeChoice . coreExpressionType) operands
      || coreExpressionType key == CoreRangeType
      || isTuple (coreExpressionType receiver) && isNothing (literalPosition key) =
      let (bound, target) = hold state receiver
          (ready, prefix, position)
            | Just _ <- literalPosition key = (bound, [declare target receiver], key)
            | otherwise =
                let (withKey, retained) = hold bound key
                 in (withKey, [declare target receiver, declare retained key], reading retained)
          wrap (value, kind) = (expression kind (CoreBlockValue (CoreBlock prefix (Just value))), kind)
       in fmap (fmap wrap) (select ready (reading target) position)
  | otherwise = select state receiver key
 where
  operands = [receiver, key]
  isTuple CoreTupleType{} = True
  isTuple _ = False
  literalPosition value = case coreExpressionShape value of
    CoreIntegerLiteral _ position -> Just position
    _ -> Nothing
  hold current value = bindLocal current "" (coreExpressionType value)
  declare local value = CoreStatement (coreExpressionSpan value) (CoreDeclare local value)
  expression = CoreExpression at
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  select current container index
    | Just selected <- mapRuntimeChoice current at CoreNeverType container
        (\ready held -> fmap (fmap fst) (select ready held index)) = selected
    | Just selected <- mapRuntimeChoice current at CoreNeverType index
        (\ready held -> fmap (fmap fst) (select ready container held)) = selected
    | coreExpressionType index == CoreRangeType, sliceable (coreExpressionType container) =
        let field name kind = expression kind (CoreRangeMethod name index [])
            exactKind = CoreIntegerType BigIntKind
         in sliceOn at current container (field RangeStartExact exactKind) (field RangeEndExact exactKind)
              (field RangeHasEnd CoreBoolType) (field RangeIsInclusiveOf CoreBoolType)
    | CoreIntegerType _ <- coreExpressionType index = scalar current container index
    | otherwise = invalid current container index
  scalar current container index = case coreExpressionType container of
    CoreArrayType element ->
      (current, Just (expression element (CoreIndex container position), element))
    CoreTextType ->
      (current, Just (expression CoreCharType (CoreTextMethod TextCharAt container [position]), CoreCharType))
    CoreTupleType members
      | Just offset <- literalPosition index
      , offset >= 0, offset < toInteger (length members)
      , kind : _ <- drop (fromInteger offset) members ->
          (current, Just (expression kind (CoreTupleIndex (fromInteger offset) container), kind))
      | Just _ <- literalPosition index ->
          let effects = [CoreStatement (coreExpressionSpan container) (CoreEvaluate container)]
           in (current, Just (expression CoreNeverType (CoreBlockValue (CoreBlock effects (Just boundsFailure))), CoreNeverType))
    CoreTupleType members ->
      let member offset kind = CoreArm at
            (CoreLiteralPattern (expression intType (CoreIntegerLiteral PlatformSigned (toInteger offset))))
            Nothing (expression kind (CoreTupleIndex offset container))
          arms = zipWith member [0 ..] members <> [CoreArm at CoreWildcardPattern Nothing boundsFailure]
          chosen = joinRuntimeArms at CoreNeverType position arms
       in (current, Just (chosen, coreExpressionType chosen))
    _ -> invalid current container index
   where
    position = clampedPosition at index
  boundsFailure = argumentFailure AtInvocation at "E7004" "index out of range"
  invalid current container position =
    let (ready, failure) = invalidRuntimeIndex current at container [position]
     in (ready, Just (failure, CoreNeverType))

sliceOn :: Span -> LowerState -> CoreExpression -> CoreExpression -> CoreExpression
  -> CoreExpression -> CoreExpression -> Lowered
sliceOn at current container low high hasEnd inclusive =
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

 where
  expression = CoreExpression at
  statement = CoreStatement at
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  declare local value = statement (CoreDeclare local value)
  wrap statements (value, kind) = (expression kind (CoreBlockValue (CoreBlock statements (Just value))), kind)
  number = expression intType . CoreIntegerLiteral PlatformSigned
  zero = number 0
  one = number 1
  text = expression CoreTextType . CoreTextLiteral
  compare' = integerComparison at
  both a b = expression CoreBoolType (CoreBinary CoreAnd a b)
  either' a b = expression CoreBoolType (CoreBinary CoreOr a b)
  choose kind test yes no = expression kind (CoreIfValue test (CoreBlock [] (Just yes)) no)
  when' condition failure = statement (CoreIf condition (CoreBlock [statement (CoreEvaluate failure)] Nothing) Nothing)
  fail' message help computed = expression CoreNeverType (CoreFailText "E7004" help (text message) computed)
