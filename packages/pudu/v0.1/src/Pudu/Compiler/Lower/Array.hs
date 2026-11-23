{-| @Pudu.Compiler.Lower.Array — array literals, indexing and the built-in
    methods. The runtime does the ones that only move items; `map`, `filter`
    and `reduce` become loops calling the closure once per item, in order,
    as `callArrayMethod` does. -}
module Pudu.Compiler.Lower.Array
  ( LowerCallback, lowerArrayLiteral, lowerArrayIndex, lowerArrayMethod, lowerArrayLoop, reboxArray, takeReceiver, collect, stops, stopped
  ) where

import Data.List (mapAccumL)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments (ArgumentBlame (AtInvocation), argumentFailure, clampedPosition, collectArguments)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued, popLoop, pushLoop)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refuse, refused)
import Pudu.Compiler.Lower.Sort (sortStatements)
import Pudu.Compiler.Lower.Types (LowerTypes, isDynamic, sumVariants, typeFactAt, typeForSpan)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, invalidRuntimeIndex, joinRuntimeArms, mapRuntimeChoice, preserveRuntimeResult, projectRuntimeValue, runtimeCarriers, runtimeResultType, widen)
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
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
    (after, Just written)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | all ((== element) . coreExpressionType) cores -> (after, Just (CoreExpression at kind (CoreArray cores), kind))
      | any (hasRuntimeChoice . coreExpressionType) cores
      , let stored = combinedElement element (map coreExpressionType cores)
            (ready, projected) = mapAccumL (\current -> projectRuntimeValue types current stored) after cores
            arrayType = CoreArrayType stored
      , all ((== stored) . coreExpressionType) projected ->
          (ready, Just (CoreExpression at arrayType (CoreArray projected), arrayType))
      | otherwise -> halt at "an array literal whose items have different types" after
     where
      types = contextTypes (lowerContext after)
      cores = map (widen types element) written
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
lowerArrayIndex lower state whole receiver key = case typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver) of
  Just CoreArrayType{} -> Just operands
  Just CoreTextType -> Just operands
  _ -> Nothing
 where
  at = locatedSpan key
  operands = case collectArguments lower state [receiver, key] of
    (after, Nothing) -> refused after
    (after, Just cores@[container, index])
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | any (hasRuntimeChoice . coreExpressionType) cores || tupleReceiver container ->
          let (bound, held) = bindLocal after "" (coreExpressionType container)
              (withKey, heldKey) = bindLocal bound "" (coreExpressionType index)
              (ready, result) = select withKey (reading held) (reading heldKey)
              declarations = [declare held container, declare heldKey index]
           in (ready, do
                (answer, _) <- result
                let types = contextTypes (lowerContext ready)
                    carried = maybe answer (\checked -> preserveRuntimeResult checked answer) (typeForSpan types whole)
                    kind = coreExpressionType carried
                pure (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just carried))), kind))
      | otherwise -> select after container index
    (after, Just _) -> refused after
  tupleReceiver value = case coreExpressionType value of
    CoreTupleType _ -> True
    _ -> False
  reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  declare local value = CoreStatement (coreExpressionSpan value) (CoreDeclare local value)
  select current container index
    | Just selected <- mapRuntimeChoice current at CoreNeverType container
        (\ready held -> fmap (fmap fst) (select ready held index)) = selected
    | Just selected <- mapRuntimeChoice current at CoreNeverType index
        (\ready held -> fmap (fmap fst) (select ready container held)) = selected
    | CoreIntegerType _ <- coreExpressionType index =
        let position = clampedPosition at index
         in case coreExpressionType container of
              CoreArrayType element -> (current, Just (CoreExpression at element (CoreIndex container position), element))
              CoreTextType -> (current, Just (CoreExpression at CoreCharType
                (CoreTextMethod TextCharAt container [position]), CoreCharType))
              CoreTupleType members ->
                let member offset kind = CoreArm at
                      (CoreLiteralPattern (CoreExpression at intType (CoreIntegerLiteral PlatformSigned (toInteger offset))))
                      Nothing (CoreExpression at kind (CoreTupleIndex offset container))
                    failure = argumentFailure AtInvocation at "E7004" "index out of range"
                    arms = zipWith member [0 ..] members <> [CoreArm at CoreWildcardPattern Nothing failure]
                    chosen = joinRuntimeArms at CoreNeverType position arms
                 in (current, Just (chosen, coreExpressionType chosen))
              _ -> invalid current container index
    | otherwise = invalid current container index
  invalid current container index =
    let (ready, failure) = invalidRuntimeIndex current at container [index]
     in (ready, Just (failure, CoreNeverType))

{-| A built-in method when the receiver is an array. -}
lowerArrayMethod :: LowerExpression -> LowerCallback -> LowerState -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerArrayMethod lower lowerCallback state at receiver member arguments = case receiverType of
  Just (CoreArrayType checked) -> Just $ case receiveOperands lower (arrayOperands checked) state receiver arguments of
    (after, Nothing) -> refused after
    (after, operands@(Just (written, core)))
      | any stops (core : written) -> (after, Just (stopped at (core : written), CoreNeverType))
      | kind@(CoreArrayType element) <- coreExpressionType core ->
          let loop = arrayMethodWith after at member operands kind element id
           in case lookup member (direct kind element) of
                Just (name, parameters, result)
                  | name /= ArrayJoinWith || not (joinsHeldText types element) ->
                      runtime after checked element name parameters result core written
                _ -> loop
      | otherwise -> halt at "an array method without an array receiver" after
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  receiverType = case locatedValue receiver of
    ArrayExpression members -> arrayAt state (locatedSpan receiver) members
    _ -> typeForSpan types (locatedSpan receiver)
  arrayOperands checked kind current written = case (kind, member, written) of
    (CoreArrayType element, "reduce", [callback, seed]) ->
      reduceOperands lower lowerCallback at checked element current callback seed
    (CoreArrayType element, method, [callback])
      | method `elem` ["map", "filter", "sortBy"], element /= checked ->
          let inputs = if method == "sortBy" then [element, element] else [element]
           in collect (lowerCallback inputs) current [callback]
    _ -> collect lower current written
  runtime after checked element name parameters result core written
    | length parameters == length written
    , let currentTypes = contextTypes (lowerContext after)
          (ready, operands) = mapAccumL (\current (parameter, operand) ->
            projectRuntimeValue currentTypes current parameter operand) after (zip parameters written)
    , map coreExpressionType operands == parameters =
        answer ready result core operands
    | Just (leading, value) <- elementOperand name written
    , all ((== intType) . coreExpressionType) leading
    , let actual = coreExpressionType value
    , hasRuntimeChoice element || hasRuntimeChoice actual =
        let stored = combinedElement checked [element, actual]
            (copied, source) = reboxArray after at element stored core
            (ready, operand) = projectRuntimeValue (contextTypes (lowerContext copied)) copied stored value
            output = if name `elem` [ArrayPushValue, ArrayInsertAt] then CoreArrayType stored else result
         in answer ready output source (leading <> [operand])
    | ArrayConcatWith <- name
    , [right] <- written
    , CoreArrayType other <- coreExpressionType right
    , hasRuntimeChoice element || hasRuntimeChoice other =
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

dynamicTextVariant :: LowerTypes -> CoreType -> Maybe CoreVariant
dynamicTextVariant types kind
  | isDynamic kind, Just variants <- sumVariants types kind
  , variant : _ <- filter ((== [CoreTextType]) . map snd . coreVariantFields) variants = Just variant
  | otherwise = Nothing

joinsHeldText :: LowerTypes -> CoreType -> Bool
joinsHeldText types kind = case runtimeChoiceAlternatives kind of
  Just _ -> True
  Nothing -> dynamicTextVariant types kind /= Nothing

{-| `map`, `filter` and `reduce` over something that is not itself an array:
    `toItems` converts the retained receiver after all supplied operands run. -}
lowerArrayLoop :: LowerExpression -> LowerCallback -> LowerState -> Span -> Located Expression -> Text -> [Located Expression]
  -> CoreType -> (CoreExpression -> CoreExpression) -> Lowered
lowerArrayLoop lower lowerCallback state at receiver member arguments kind toItems = case kind of
  CoreArrayType element ->
    let lowerOperands _ current written = case (member, written) of
          ("reduce", [callback, seed]) -> reduceOperands lower lowerCallback at element element current callback seed
          _ -> collect lower current written
        (after, operands) = receiveOperands lower lowerOperands state receiver arguments
     in arrayMethodWith after at member operands kind element toItems
  _ -> halt at ("the method '" <> member <> "'") state

receiveOperands :: LowerExpression
  -> (CoreType -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression]))
  -> LowerState -> Located Expression -> [Located Expression]
  -> (LowerState, Maybe ([CoreExpression], CoreExpression))
receiveOperands lower operands current receiver arguments = case lower current receiver of
  (after, Nothing) -> (after, Nothing)
  (after, Just (core, kind))
    | expressionIsPrintValued core -> halt (locatedSpan receiver) "a Result[(), Str] method receiver" after
    | kind == CoreNeverType -> (after, Just ([], core))
    | otherwise -> case operands kind after arguments of
        (final, Nothing) -> (final, Nothing)
        (final, Just cores) -> (final, Just (cores, core))

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

arrayMethodWith :: LowerState -> Span -> Text -> Maybe ([CoreExpression], CoreExpression)
  -> CoreType -> CoreType -> (CoreExpression -> CoreExpression) -> Lowered
arrayMethodWith state at member operands kind element toItems = case member of
  "map" -> looped True
  "filter" -> looped False
  "reduce" -> reduced
  "sortBy" -> sorted
  "join" | joinsHeldText types element -> joined
  _ -> halt at ("the array method '" <> member <> "'") state
 where
  types = contextTypes (lowerContext state)

  -- map and filter: an output array built item by item.
  looped maps = case (state, operands) of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (core : cores) -> (after, Just (stopped at (core : cores), CoreNeverType))
      | [function] <- cores ->
          let (withFunction, functionLocal) = hidden after (coreExpressionType function)
              (withArray, arrayLocal, prefixArray, convertArray) = holdArray withFunction core
              (withItem, itemLocal) = hidden withArray element
              (invoked, invocation) = invokeCallback withItem (reading functionLocal) [reading itemLocal]
              outputKind answered
                | not maps = kind
                | answered /= CoreNeverType = CoreArrayType answered
                | Just mapped@CoreArrayType{} <- typeForSpan types at = mapped
                | otherwise = CoreArrayType CoreUnitType
           in case invocation of
                Just applied
                  | let answered = coreExpressionType applied
                  , maps || answered `elem` [CoreBoolType, CoreNeverType] ->
                    let output = outputKind answered
                        (withOutput, outputLocal) = hidden invoked output
                        pushed value = statement (CoreAssign outputLocal (expression output
                          (CoreArrayMethod ArrayPushValue (expression output (CoreTakeLocal outputLocal)) [value])))
                        turn item = statement (CoreDeclare itemLocal (reading item)) : (case answered of
                          CoreNeverType -> [statement (CoreEvaluate applied)]
                          _ | maps -> [pushed applied]
                            | otherwise -> [statement (CoreIf applied (CoreBlock [pushed (reading item)] Nothing) Nothing)])
                        (body, loop) = walkArrayItems at withOutput arrayLocal element turn
                        prefix = prefixArray <> [statement (CoreDeclare functionLocal function)] <> convertArray <>
                          [statement (CoreDeclare outputLocal (expression output (CoreArray [])))]
                     in (body, Just (expression output (CoreBlockValue (CoreBlock (prefix <> loop) (Just (reading outputLocal)))), output))
                Just _ -> halt at "an array filter whose callback does not return Bool" invoked
                Nothing -> refused invoked
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") after

  -- reduce: the accumulator first, then the item, as `foldM` passes them.
  reduced = case (state, operands) of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (core : cores) -> (after, Just (stopped at (core : cores), CoreNeverType))
      | [function, initial] <- cores ->
          let accumulated = coreExpressionType initial
              (withFunction, functionLocal) = hidden after (coreExpressionType function)
              (withInitial, accumulatorLocal) = hidden withFunction accumulated
              (withArray, arrayLocal, prefixArray, convertArray) = holdArray withInitial core
              (withItem, itemLocal) = hidden withArray element
              (invoked, invocation) = invokeCallback withItem (reading functionLocal) [reading accumulatorLocal, reading itemLocal]
              prefix =
                prefixArray <> [statement (CoreDeclare functionLocal function), statement (CoreDeclare accumulatorLocal initial)] <>
                convertArray
           in case invocation of
                Just applied ->
                  let (ready, carried) = projectRuntimeValue types invoked accumulated applied
                      (body, loop) = walkArrayItems at ready arrayLocal element $ \item ->
                        [ statement (CoreDeclare itemLocal (reading item))
                        , statement (CoreAssign accumulatorLocal carried) ]
                   in if coreExpressionType carried `elem` [accumulated, CoreNeverType]
                        then (body, Just (expression accumulated (CoreBlockValue (CoreBlock (prefix <> loop) (Just (reading accumulatorLocal)))), accumulated))
                        else halt at "an array reduction with incompatible callback result layouts" ready
                Nothing -> refused invoked
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") after

  -- sortBy: the array and the closure run once, then the sort asks the
  -- closure exactly what `sortWith` asks it.
  sorted = case (state, operands) of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (core : cores) -> (after, Just (stopped at (core : cores), CoreNeverType))
      | [function] <- cores ->
          let (withFunction, functionLocal) = hidden after (coreExpressionType function)
              (withArray, arrayLocal, prefixArray, convertArray) = holdArray withFunction core
              (withLeft, left) = hidden withArray element
              (withRight, right) = hidden withLeft element
              (invoked, invocation) = invokeCallback withRight (reading functionLocal) [reading left, reading right]
              prefix = prefixArray <> [statement (CoreDeclare functionLocal function)] <> convertArray
           in case invocation of
                Just applied
                  | coreExpressionType applied `elem` [CoreBoolType, CoreNeverType] ->
                      let before x y = expression (coreExpressionType applied) (CoreBlockValue (CoreBlock
                            [statement (CoreDeclare left x), statement (CoreDeclare right y)] (Just applied)))
                          (final, statements, result) = sortStatements invoked at arrayLocal before
                       in (final, Just (expression kind (CoreBlockValue (CoreBlock (prefix <> statements) (Just (reading result)))), kind))
                Just _ -> halt at "an array comparison whose callback does not return Bool" invoked
                Nothing -> refused invoked
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") after

  joined = case (state, operands) of
    (after, Nothing) -> refused after
    (after, Just (cores, core))
      | any stops (core : cores) -> (after, Just (stopped at (core : cores), CoreNeverType))
      | [separator] <- cores, coreExpressionType separator == CoreTextType ->
          let textArray = CoreArrayType CoreTextType
              (withArray, input, prefix, converted) = holdArray after core
              (withSeparator, between) = hidden withArray CoreTextType
              (withResult, texts) = hidden withSeparator textArray
              (withItem, itemLocal) = hidden withResult element
              (selected, piece) = joinText withItem (reading itemLocal)
              (final, loop) = walkArrayItems at selected input element $ \item ->
                [ statement (CoreDeclare itemLocal (reading item))
                , statement (CoreAssign texts (expression textArray (CoreArrayMethod ArrayPushValue
                    (expression textArray (CoreTakeLocal texts)) [piece]))) ]
              statements = prefix <> [statement (CoreDeclare between separator)] <> converted
                <> [statement (CoreDeclare texts (expression textArray (CoreArray [])))] <> loop
              result = expression CoreTextType (CoreArrayMethod ArrayJoinWith (reading texts) [reading between])
           in (final, Just (expression CoreTextType (CoreBlockValue (CoreBlock statements (Just result))), CoreTextType))
      | otherwise -> halt at "a call to join with these arguments" after

  joinText current core
    | coreExpressionType core == CoreTextType = (current, core)
    | Just (ready, Just (selected, _)) <- mapRuntimeChoice current at CoreTextType core
        (\prior held -> let (next, piece) = joinText prior held in (next, Just piece)) = (ready, selected)
    | Just variant <- dynamicTextVariant types (coreExpressionType core) =
        let (ready, payload) = hidden current CoreTextType
         in (ready, expression CoreTextType (CoreMatch core
              [ CoreArm at (CoreVariantPattern (coreVariantName variant) [CoreBindPattern payload]) Nothing (reading payload)
              , CoreArm at CoreWildcardPattern Nothing invalidText ]))
    | otherwise = (current, invalidText)
  invalidText = expression CoreNeverType (CoreFailText "E7001" Nothing
    (expression CoreTextType (CoreTextLiteral "join expects an array of text")) Nothing)

  invokeCallback current function arguments
    | Just selected <- mapRuntimeChoice current at CoreNeverType function
        (\ready held -> invokeCallback ready held arguments) = fmap (fmap fst) selected
    | CoreFunctionType inputs result <- coreExpressionType function
    , length inputs == length arguments
    , let (ready, projected) = mapAccumL (\prior (expected, given) ->
            projectRuntimeValue types prior expected given) current (zip inputs arguments)
    , map coreExpressionType projected == inputs =
        (ready, Just (expression result (CoreCallValue function projected)))
    | otherwise = halt at "an array callback with incompatible argument layouts" current

  holdArray current core =
    let (held, original) = hidden current (coreExpressionType core)
        declaration = [statement (CoreDeclare original core)]
     in if coreExpressionType core == kind
          then (held, original, declaration, [])
          else
            let (converted, array) = hidden held kind
             in (converted, array, declaration, [statement (CoreDeclare array (toItems (reading original)))])

  hidden current kind' = bindLocal current "" kind'
  expression kind' shape = CoreExpression at kind' shape
  statement shape = CoreStatement at shape
  reading local = expression (coreLocalType local) (CoreReadLocal local)

reboxArray :: LowerState -> Span -> CoreType -> CoreType -> CoreExpression -> (LowerState, CoreExpression)
reboxArray state at old new source
  | old == new = (state, source)
  | coreExpressionType projected == expected = (ready, projected)
  | otherwise = (refuse at "an array projection with incompatible element layouts" state, source)
 where
  expected = CoreArrayType new
  (ready, projected) = projectRuntimeValue (contextTypes (lowerContext state)) state expected source

walkArrayItems :: Span -> LowerState -> CoreLocal -> CoreType -> (CoreLocal -> [CoreStatement])
  -> (LowerState, [CoreStatement])
walkArrayItems at current arrayLocal held turn =
  let (withLength, lengthLocal) = hidden current intType
      (withIndex, indexLocal) = hidden withLength intType
      (withItem, itemLocal) = hidden withIndex held
      (pushed, identity) = pushLoop Nothing withItem
      condition = expression CoreBoolType (CoreBinary CoreLess (reading indexLocal) (reading lengthLocal))
      step = statement (CoreAssign indexLocal (expression intType (CoreBinary CoreAdd (reading indexLocal) one)))
      loop = expression CoreUnitType (CoreWhileValue identity condition (CoreBlock
        ([statement (CoreDeclare itemLocal (expression held (CoreIndex (reading arrayLocal) (reading indexLocal))))]
          <> turn itemLocal <> [step]) Nothing))
      statements =
        [ statement (CoreDeclare lengthLocal (expression intType (CoreArrayMethod ArrayLengthOf (reading arrayLocal) [])))
        , statement (CoreDeclare indexLocal (expression intType (CoreIntegerLiteral PlatformSigned 0)))
        , statement (CoreEvaluate loop) ]
   in (popLoop pushed, statements)

 where
  hidden current' kind = bindLocal current' "" kind
  expression = CoreExpression at
  statement = CoreStatement at
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  one = expression intType (CoreIntegerLiteral PlatformSigned 1)

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

stops :: CoreExpression -> Bool
stops core = coreExpressionType core == CoreNeverType

stopped :: Span -> [CoreExpression] -> CoreExpression
stopped at cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
  [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))
