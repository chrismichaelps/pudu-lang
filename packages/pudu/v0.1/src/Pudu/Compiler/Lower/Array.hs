{-| @Pudu.Compiler.Lower.Array — array literals, indexing and the built-in
    methods. The runtime does the ones that only move items; `map`, `filter`
    and `reduce` become loops calling the closure once per item, in order,
    as `callArrayMethod` does. -}
module Pudu.Compiler.Lower.Array
  ( lowerArrayLiteral, lowerArrayIndex, lowerArrayMethod, takeReceiver, collect, stops, stopped
  ) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, popLoop, pushLoop)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Sort (sortStatements)
import Pudu.Compiler.Lower.Types (typeFactAt, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId (..), Type (..))

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| `[a, b, c]`: the items run in order. -}
lowerArrayLiteral :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerArrayLiteral lower state at members = case arrayAt state at members of
  Just kind@(CoreArrayType element) -> case collect lower state members of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | all ((== element) . coreExpressionType) cores -> (after, Just (CoreExpression at kind (CoreArray cores), kind))
      | otherwise -> halt at "an array literal whose items have different types" after
  _ -> halt at "an array without a native element type" state

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

{-| `array[index]` or `text[index]`: the receiver, then the index. A failure
    reports at the index. -}
lowerArrayIndex :: LowerExpression -> LowerState -> Span -> Located Expression -> Located Expression -> Maybe Lowered
lowerArrayIndex lower state _ receiver key = case typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver) of
  Just (CoreArrayType element) -> Just $ case collect lower state [receiver, key] of
    (after, Nothing) -> refused after
    (after, Just cores@[array, index])
      | any stops cores -> (after, Just (stopped (locatedSpan key) cores, CoreNeverType))
      | coreExpressionType index == intType ->
          (after, Just (CoreExpression (locatedSpan key) element (CoreIndex array index), element))
    (after, Just _) -> halt (locatedSpan key) "an array index that is not an Int" after
  -- A Str index is charAt, but the text runs before the index here.
  Just CoreTextType -> Just $ case collect lower state [receiver, key] of
    (after, Nothing) -> refused after
    (after, Just cores@[text, index])
      | any stops cores -> (after, Just (stopped (locatedSpan key) cores, CoreNeverType))
      | coreExpressionType index == intType ->
          let (withText, held) = bindLocal after "" CoreTextType
              at' = locatedSpan key
              read' = CoreExpression at' CoreTextType (CoreReadLocal held)
              charAt = CoreExpression at' CoreCharType (CoreTextMethod TextCharAt read' [index])
           in (withText, Just (CoreExpression at' CoreCharType (CoreBlockValue (CoreBlock
                [CoreStatement at' (CoreDeclare held text)] (Just charAt))), CoreCharType))
    (after, Just _) -> halt (locatedSpan key) "a Str index that is not an Int" after
  _ -> Nothing

{-| A built-in method when the receiver is an array; Nothing otherwise. The
    arguments run before the receiver, as every method call's do. -}
lowerArrayMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerArrayMethod lower state at receiver member arguments = case receiverType of
  Just kind@(CoreArrayType element) -> case lookup member (direct kind element) of
    Just (name, parameters, result) -> Just (runtime name parameters result)
    Nothing -> case member of
      "map" | Just (CoreArrayType mapped) <- typeForSpan types at -> Just (looped kind element (Just mapped))
      "filter" -> Just (looped kind element Nothing)
      "reduce" -> Just (reduced kind element)
      "sortBy" -> Just (sorted kind)
      _ -> Just (halt at ("the array method '" <> member <> "'") state)
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  receiverType = case locatedValue receiver of
    ArrayExpression members -> arrayAt state (locatedSpan receiver) members
    _ -> typeForSpan types (locatedSpan receiver)
  -- Everything after the receiver's own evaluation reads hidden locals.
  operands current = case collect lower current arguments of
    (after, Nothing) -> (after, Nothing)
    (after, Just cores) -> case lower after receiver of
      (final, Just (core, _))
        | expressionIsPrintValued core -> halt (locatedSpan receiver) "a Result[(), Str] method receiver" final
        | otherwise -> (final, Just (cores, core))
      (final, Nothing) -> (final, Nothing)

  runtime name parameters result = case operands state of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (cores <> [core]) -> (after, Just (stopped at (cores <> [core]), CoreNeverType))
      | map coreExpressionType cores /= parameters -> halt at ("a call to " <> member <> " with these arguments") after
      | otherwise -> (after, Just (CoreExpression at result (CoreArrayMethod name core cores), result))

  -- map and filter: an output array built item by item.
  looped kind element mapped = case operands state of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (cores <> [core]) -> (after, Just (stopped at (cores <> [core]), CoreNeverType))
      | [function] <- cores ->
          let outputKind = maybe kind CoreArrayType mapped
              (withFunction, functionLocal) = hidden after (coreExpressionType function)
              (withArray, arrayLocal) = hidden withFunction kind
              (withOutput, outputLocal) = hidden withArray outputKind
              (body, loop) = walk withOutput arrayLocal element $ \item ->
                let applied = expression (maybe CoreBoolType id mapped) (CoreCallValue (reading functionLocal) [reading item])
                    pushed value = statement (CoreAssign outputLocal (expression outputKind
                      (CoreArrayMethod ArrayPushValue (expression outputKind (CoreTakeLocal outputLocal)) [value])))
                 in case mapped of
                      Just _ -> [pushed applied]
                      Nothing -> [statement (CoreIf applied (CoreBlock [pushed (reading item)] Nothing) Nothing)]
              prefix =
                [ statement (CoreDeclare functionLocal function), statement (CoreDeclare arrayLocal core)
                , statement (CoreDeclare outputLocal (expression outputKind (CoreArray []))) ]
           in (body, Just (expression outputKind (CoreBlockValue (CoreBlock (prefix <> loop) (Just (reading outputLocal)))), outputKind))
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") after

  -- reduce: the accumulator first, then the item, as `foldM` passes them.
  reduced kind element = case operands state of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (cores <> [core]) -> (after, Just (stopped at (cores <> [core]), CoreNeverType))
      | [function, initial] <- cores ->
          let accumulated = coreExpressionType initial
              (withFunction, functionLocal) = hidden after (coreExpressionType function)
              (withInitial, accumulatorLocal) = hidden withFunction accumulated
              (withArray, arrayLocal) = hidden withInitial kind
              (body, loop) = walk withArray arrayLocal element $ \item ->
                [ statement (CoreAssign accumulatorLocal (expression accumulated
                    (CoreCallValue (reading functionLocal) [reading accumulatorLocal, reading item]))) ]
              prefix =
                [ statement (CoreDeclare functionLocal function), statement (CoreDeclare accumulatorLocal initial)
                , statement (CoreDeclare arrayLocal core) ]
           in (body, Just (expression accumulated (CoreBlockValue (CoreBlock (prefix <> loop) (Just (reading accumulatorLocal)))), accumulated))
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") after

  -- sortBy: the closure and the array run once, then the sort asks the
  -- closure exactly what `sortWith` asks it.
  sorted kind = case operands state of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (cores <> [core]) -> (after, Just (stopped at (cores <> [core]), CoreNeverType))
      | [function] <- cores ->
          let (withFunction, functionLocal) = hidden after (coreExpressionType function)
              (withArray, arrayLocal) = hidden withFunction kind
              (final, statements, result) = sortStatements withArray at arrayLocal functionLocal
              prefix = [statement (CoreDeclare functionLocal function), statement (CoreDeclare arrayLocal core)]
           in (final, Just (expression kind (CoreBlockValue (CoreBlock (prefix <> statements) (Just (reading result)))), kind))
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") after

  -- One turn per item, reading the length once, as traversing the sequence does.
  walk current arrayLocal element turn =
    let (withLength, lengthLocal) = hidden current intType
        (withIndex, indexLocal) = hidden withLength intType
        (withItem, itemLocal) = hidden withIndex element
        (pushed, identity) = pushLoop Nothing withItem
        condition = expression CoreBoolType (CoreBinary CoreLess (reading indexLocal) (reading lengthLocal))
        step = statement (CoreAssign indexLocal (expression intType (CoreBinary CoreAdd (reading indexLocal) one)))
        loop = expression CoreUnitType (CoreWhileValue identity condition (CoreBlock
          ([statement (CoreDeclare itemLocal (expression element (CoreIndex (reading arrayLocal) (reading indexLocal))))]
            <> turn itemLocal <> [step]) Nothing))
        statements =
          [ statement (CoreDeclare lengthLocal (expression intType (CoreArrayMethod ArrayLengthOf (reading arrayLocal) [])))
          , statement (CoreDeclare indexLocal (expression intType (CoreIntegerLiteral PlatformSigned 0)))
          , statement (CoreEvaluate loop) ]
     in (popLoop pushed, statements)

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
    , ("reverse", (ArrayReversed, [], kind)) ]
    <> [("join", (ArrayJoinWith, [CoreTextType], CoreTextType)) | element `elem` [CoreTextType, CoreUnitType]]

  hidden current kind = bindLocal current "" kind
  expression kind shape = CoreExpression at kind shape
  statement shape = CoreStatement at shape
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  one = expression intType (CoreIntegerLiteral PlatformSigned 1)

{-| `x = x.push(...)` and the like read `x` last, then replace it, so the
    receiver can be taken rather than shared and the buffer stays unique. -}
takeReceiver :: CoreLocal -> CoreExpression -> CoreExpression
takeReceiver local expression = case coreExpressionShape expression of
  CoreArrayMethod name receiver arguments
    | name `elem` [ArrayPushValue, ArrayPopLast, ArrayInsertAt, ArrayRemoveAt, ArrayConcatWith]
    , CoreReadLocal read' <- coreExpressionShape receiver
    , read' == local ->
        expression{coreExpressionShape = CoreArrayMethod name receiver{coreExpressionShape = CoreTakeLocal local} arguments}
  _ -> expression

collect :: LowerExpression -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression])
collect lower = go []
 where
  go done current [] = (current, Just (reverse done))
  go done current (next : rest) = case lower current next of
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan next) "a Result[(), Str] value in an array operation" after
      | otherwise -> go (core : done) after rest
    (after, Nothing) -> (after, Nothing)

stops :: CoreExpression -> Bool
stops core = coreExpressionType core == CoreNeverType

stopped :: Span -> [CoreExpression] -> CoreExpression
stopped at cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
  [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))
