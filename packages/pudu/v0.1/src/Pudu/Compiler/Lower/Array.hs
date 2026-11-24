{-| @Pudu.Compiler.Lower.Array — array literals, indexing and the built-in
    methods. The runtime does the ones that only move items; `map`, `filter`
    and `reduce` become loops calling the closure once per item, in order,
    as `callArrayMethod` does. -}
module Pudu.Compiler.Lower.Array
  ( LowerCallback, literalElementCarrier, lowerArrayLiteral, lowerArrayMethod, lowerArrayLoop, reboxArray, takeReceiver, collect, stops, stopped
  ) where

import Data.List (mapAccumL)
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Arguments
  ( ArgumentSlot (..), argumentFailure, argumentFailureWith
  , callWithRuntimeArguments, collectArguments, methodArgumentBlame, stopped, stops, wrappedPosition
  )
import Pudu.Compiler.Lower.ArrayLoop (arrayMethodWith, joinsHeldText)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, intType, refuse, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, nativeValueType, typeFactAt, typeForSpan)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (commonAggregateCarrier, projectRuntimeValue, runtimeCarriers, runtimeResultType, widen)
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId (..), Type (..))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type LowerCallback = [CoreType] -> LowerExpression
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| `[a, b, c]`: the items run in order. -}
lowerArrayLiteral :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerArrayLiteral lower state at members = case arrayAt state at members of
  Just kind@(CoreArrayType element) -> case collect lower state members of
    (after, Nothing) -> refused after
    (after, Just written) ->
      let types = contextTypes (lowerContext after)
          carry desired current = projectRuntimeValue types current desired
          (ready, cores) = mapAccumL (carry element) after written
          kinds = map coreExpressionType cores
       in if any stops cores
            then (ready, Just (stopped at cores, CoreNeverType))
            else if all (== element) kinds
              then (ready, Just (CoreExpression at kind (CoreArray cores), kind))
              else if all nativeValueType kinds
                then
                  let stored = literalElementCarrier types element kinds
                      (settled, projected) = mapAccumL (carry stored) ready cores
                      arrayType = CoreArrayType stored
                   in if all ((== stored) . coreExpressionType) projected
                        then (settled, Just (CoreExpression at arrayType (CoreArray projected), arrayType))
                        else halt at "an array literal whose items have different types" settled
                else halt at "an array literal whose items have different types" ready
  _ -> halt at "an array without a native element type" state

literalElementCarrier :: LowerTypes -> CoreType -> [CoreType] -> CoreType
literalElementCarrier types checked kinds
  | all (== checked) kinds = checked
  | otherwise = fromMaybe (runtimeResultType checked (foldMap runtimeCarriers kinds))
      (commonAggregateCarrier types checked kinds)

{-| The array type at a literal. `[]` with nothing to settle its element
    type holds no item, so any layout serves; unit is used, as for a sum's
    unconstrained argument. An open variable anywhere else may stand for a
    type real values have, and stays unrepresented. -}
arrayAt :: LowerState -> Span -> [Located Expression] -> Maybe CoreType
arrayAt state at members = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind -> Just kind
  Nothing
    | null members
    , Just (NominalType (NominalId Nothing "Array") [VariableType _]) <- typeFactAt (contextTypes (lowerContext state)) at ->
        Just (CoreArrayType CoreUnitType)
    | otherwise -> Nothing

{-| A built-in method when the receiver is an array. -}
lowerArrayMethod :: LowerExpression -> LowerCallback -> LowerState -> Span -> CoreType -> CoreExpression -> Text
  -> [Located Expression] -> Lowered
lowerArrayMethod lower lowerCallback state at declaredElement receiver member arguments
  | kind@(CoreArrayType element) <- coreExpressionType receiver =
      case arrayOperands declaredElement kind state arguments of
        (after, Nothing) -> refused after
        (after, Just written)
          | any stops written -> (after, Just (stopped at (receiver : written), CoreNeverType))
          | otherwise -> case lookup member (direct kind element) of
              Just (name, parameters, result) ->
                let apply ready (held : operands)
                      | name == ArrayJoinWith, joinsHeldText types element =
                          arrayMethodWith ready at member (Just (operands, held)) kind element id
                      | otherwise =
                          runtime ready declaredElement element name parameters result held (positions name operands)
                    apply ready _ = refused ready
                 in callWithRuntimeArguments at (methodFailure name (length parameters) (length written))
                      (ExactSlot kind : slots name parameters) apply after (receiver : written)
              Nothing ->
                let arity = if member == "reduce" then 2 else 1
                    apply ready (held : operands) = arrayMethodWith ready at member (Just (operands, held)) kind element id
                    apply ready _ = refused ready
                 in callWithRuntimeArguments at (wrongArity arity) (ExactSlot kind : replicate arity AnySlot)
                      apply after (receiver : written)
  | otherwise = halt at "an array method without an array receiver" state
 where
  types = contextTypes (lowerContext state)
  arrayOperands checked kind current written = case (kind, member, written) of
    (CoreArrayType element, "reduce", [callback, seed]) ->
      reduceOperands lower lowerCallback at checked element current callback seed
    (CoreArrayType element, method, [callback])
      | method `elem` ["map", "filter", "sortBy"], element /= checked ->
          let inputs = if method == "sortBy" then [element, element] else [element]
           in collect (lowerCallback inputs) current [callback]
    _ -> collectArguments lower current written
  slots name parameters = case name of
    ArrayGetAt -> [IntegerSlot]
    ArrayRemoveAt -> [IntegerSlot]
    ArraySliceOf -> [IntegerSlot, IntegerSlot]
    ArrayInsertAt -> [IntegerSlot, AnySlot]
    ArrayConcatWith -> [ShapedSlot isArray]
    ArrayContainsValue -> [AnySlot]
    ArrayIndexOfValue -> [AnySlot]
    ArrayPushValue -> [AnySlot]
    _ -> map ExactSlot parameters
  isArray CoreArrayType{} = True
  isArray _ = False
  positions name operands = case name of
    ArrayGetAt -> map (wrappedPosition at) operands
    ArrayRemoveAt -> map (wrappedPosition at) operands
    ArraySliceOf -> map (wrappedPosition at) operands
    ArrayInsertAt -> case operands of
      first : rest -> wrappedPosition at first : rest
      [] -> []
    _ -> operands
  wrongArity arity = argumentFailureWith blame at "E7003" (Just "check the method's argument count")
    (CoreExpression at CoreTextType (CoreTextLiteral (member <> " expects " <> Text.pack (show (arity :: Int)) <> " argument(s)")))
  methodFailure name expected supplied
    | expected /= supplied = wrongArity expected
    | name == ArrayConcatWith = argumentFailure blame at "E7001" "concat expects an array"
    | name == ArrayJoinWith = argumentFailure blame at "E7001" "join expects text"
    | otherwise = wrongArity expected
  blame = methodArgumentBlame state
  runtime after checked element name parameters result core written
    | length parameters == length written
    , let currentTypes = contextTypes (lowerContext after)
          (ready, operands) = mapAccumL (\current (parameter, operand) ->
            projectRuntimeValue currentTypes current parameter operand) after (zip parameters written)
    , map coreExpressionType operands == parameters =
        answer ready result core operands
    | Just (leading, value) <- elementOperand name written
    , all ((== intType) . coreExpressionType) leading
    , let actual = coreExpressionType value =
        let stored = combinedElement checked [element, actual]
            (copied, source) = reboxArray after at element stored core
            (ready, operand) = projectRuntimeValue (contextTypes (lowerContext copied)) copied stored value
            output = if name `elem` [ArrayPushValue, ArrayInsertAt] then CoreArrayType stored else result
         in answer ready output source (leading <> [operand])
    | ArrayConcatWith <- name
    , [right] <- written
    , CoreArrayType other <- coreExpressionType right =
        let stored = combinedElement checked [element, other]
            (copied, left') = reboxArray after at element stored core
            (ready, right') = reboxArray copied at other stored right
         in answer ready (CoreArrayType stored) left' [right']
    | otherwise = halt at ("a call to " <> member <> " with these arguments") after
   where
    answer current result' receiver' operands =
      (current, Just (CoreExpression at result' (CoreArrayMethod name receiver' operands), result'))
  elementOperand name operands = case (name, operands) of
    (ArrayPushValue, [value]) -> Just ([], value)
    (ArrayInsertAt, [index, value]) -> Just ([index], value)
    (ArrayContainsValue, [value]) -> Just ([], value)
    (ArrayIndexOfValue, [value]) -> Just ([], value)
    _ -> Nothing
  direct kind element =
    [ ("length", (ArrayLengthOf, [], intType))
    , ("isEmpty", (ArrayIsEmptyOf, [], CoreBoolType))
    , ("get", (ArrayGetAt, [intType], element))
    , ("indexOf", (ArrayIndexOfValue, [element], intType))
    , ("contains", (ArrayContainsValue, [element], CoreBoolType))
    , ("push", (ArrayPushValue, [element], kind))
    , ("pop", (ArrayPopLast, [], kind))
    , ("insert", (ArrayInsertAt, [intType, element], kind))
    , ("remove", (ArrayRemoveAt, [intType], kind))
    , ("slice", (ArraySliceOf, [intType, intType], kind))
    , ("concat", (ArrayConcatWith, [kind], kind))
    , ("reverse", (ArrayReversed, [], kind))
    , ("join", (ArrayJoinWith, [CoreTextType], CoreTextType)) ]

combinedElement :: CoreType -> [CoreType] -> CoreType
combinedElement checked = runtimeResultType checked . Set.unions . map runtimeCarriers . (checked :)

{-| `map`, `filter` and `reduce` over something that is not itself an array:
    `toItems` converts the retained receiver after all supplied operands run. -}
lowerArrayLoop :: LowerExpression -> LowerCallback -> LowerState -> Span -> CoreExpression -> Text -> [Located Expression]
  -> CoreType -> (CoreExpression -> CoreExpression) -> Lowered
lowerArrayLoop lower lowerCallback state at receiver member arguments kind toItems = case kind of
  CoreArrayType element ->
    let lowerOperands current written = case (member, written) of
          ("reduce", [callback, seed]) -> reduceOperands lower lowerCallback at intType element current callback seed
          (_, [callback]) | element /= intType ->
            collect (lowerCallback [element]) current [callback]
          _ -> collect lower current written
        (after, operands) = lowerOperands state arguments
     in arrayMethodWith after at member ((\written -> (written, receiver)) <$> operands) kind element toItems
  _ -> halt at ("the method '" <> member <> "'") state

reduceOperands :: LowerExpression -> LowerCallback -> Span -> CoreType -> CoreType
  -> LowerState -> Located Expression -> Located Expression -> (LowerState, Maybe [CoreExpression])
reduceOperands lower lowerCallback at checkedElement element state callback initial =
  case collect lower state [initial] of
    (after, Just [seed]) ->
      let types = contextTypes (lowerContext after)
          checked = maybe (coreExpressionType seed) id (typeForSpan types at)
          initialized = widen types checked seed
          supplied = coreExpressionType initialized
          accumulator = if stops seed then checked else supplied
       in prepare after checked accumulator initialized
    (after, _) -> refused after
 where
  prepare current checked accumulator seed = case collect lowerWritten current [callback] of
    (after, Just [function])
      | any stops [function, seed] -> (after, Just [function, seed])
      | let answers = Set.unions [runtimeCarriers result |
              CoreFunctionType [_, _] result <- Set.toList (runtimeCarriers (coreExpressionType function))]
            wider = runtimeResultType checked (runtimeCarriers accumulator <> answers)
      , not (answers `Set.isSubsetOf` runtimeCarriers accumulator) ->
          prepare after checked wider seed
      | otherwise ->
          let (ready, held) = projectRuntimeValue (contextTypes (lowerContext after)) after accumulator seed
           in if coreExpressionType held == accumulator
                then (ready, Just [function, held])
                else halt at "an array reduction with incompatible accumulator layouts" ready
    (after, _) -> refused after
   where
    lowerWritten
      | accumulator /= checked || element /= checkedElement = lowerCallback [accumulator, element]
      | otherwise = lower

reboxArray :: LowerState -> Span -> CoreType -> CoreType -> CoreExpression -> (LowerState, CoreExpression)
reboxArray state at old new source
  | old == new = (state, source)
  | coreExpressionType projected == expected = (ready, projected)
  | otherwise = (refuse at "an array projection with incompatible element layouts" state, source)
 where
  expected = CoreArrayType new
  (ready, projected) = projectRuntimeValue (contextTypes (lowerContext state)) state expected source

{-| Take a replacement receiver only when every argument can finish without
    observing the cleared binding or transferring past the assignment. -}
takeReceiver :: CoreLocal -> CoreExpression -> CoreExpression
takeReceiver local expression = case coreExpressionShape expression of
  CoreArrayMethod name receiver arguments
    | name `elem` [ArrayPushValue, ArrayPopLast, ArrayInsertAt, ArrayRemoveAt, ArrayConcatWith, ArrayReplaceAt]
    , CoreReadLocal read' <- coreExpressionShape receiver
    , read' == local
    , all independent arguments ->
        expression{coreExpressionShape = CoreArrayMethod name receiver{coreExpressionShape = CoreTakeLocal local} arguments}
  _ -> expression
 where
  independent operand = case coreExpressionShape operand of
    CoreReadLocal other -> other /= local
    CoreIntegerLiteral{} -> True
    CoreFloatLiteral{} -> True
    CoreDecimalLiteral{} -> True
    CoreBoolLiteral{} -> True
    CoreTextLiteral{} -> True
    CoreBytesLiteral{} -> True
    CoreCharLiteral{} -> True
    _ -> False

collect :: LowerExpression -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression])
collect lower = go []
 where
  go done current [] = (current, Just (reverse done))
  go done current (next : rest) = case lower current next of
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan next) "a Result[(), Str] value in an array operation" after
      | stops core -> (after, Just (reverse (core : done)))
      | otherwise -> go (core : done) after rest
    (after, Nothing) -> (after, Nothing)
