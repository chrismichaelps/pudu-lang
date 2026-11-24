{-| @Pudu.Compiler.Lower.ArrayLoop — traversal over retained collection inputs. -}
module Pudu.Compiler.Lower.ArrayLoop (CallbackSpecializer, arrayMethodWith, joinsHeldText) where

import Data.List (mapAccumL)
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments (argumentFailure, argumentFailureWith, methodArgumentBlame, stopped, stops)
import Pudu.Compiler.Lower.Control (popLoop, pushLoop)
import Pudu.Compiler.Lower.Default (couldReturnLoanFinals, suppliedArguments, withCallableArity, withLoanedCallableArity)
import Pudu.Compiler.Lower.Dynamic (mapRuntimeChoice, projectRuntimeValue)
import Pudu.Compiler.Lower.Sort (sortStatements)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), bindLocal, halt, intType, refused )
import Pudu.Compiler.Lower.Types (LowerTypes, isDynamic, nativeValueType, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))
type CallbackSpecializer = [CoreType] -> LowerState -> CoreExpression -> Maybe Lowered

dynamicTextVariant :: LowerTypes -> CoreType -> Maybe CoreVariant
dynamicTextVariant types kind
  | isDynamic kind, Just variants <- sumVariants types kind
  , variant : _ <- filter ((== [CoreTextType]) . map snd . coreVariantFields) variants = Just variant
  | otherwise = Nothing

joinsHeldText :: LowerTypes -> CoreType -> Bool
joinsHeldText types kind = case runtimeChoiceAlternatives kind of
  Just _ -> True
  Nothing -> dynamicTextVariant types kind /= Nothing

arrayMethodWith :: CallbackSpecializer -> LowerState -> Span -> Text -> Maybe ([CoreExpression], CoreExpression)
  -> CoreType -> CoreType -> (CoreExpression -> CoreExpression) -> Lowered
arrayMethodWith specialize state at member operands kind element toItems = case member of
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
                Just value ->
                    let (checked, applied)
                          | maps = (invoked, value)
                          | otherwise = predicate (coreExpressionType core /= CoreRangeType)
                              "filter predicate must return Bool" invoked value
                        answered = coreExpressionType applied
                        output = outputKind answered
                        (withOutput, outputLocal) = hidden checked output
                        pushed itemValue = statement (CoreAssign outputLocal (expression output
                          (CoreArrayMethod ArrayPushValue (expression output (CoreTakeLocal outputLocal)) [itemValue])))
                        turn item = statement (CoreDeclare itemLocal (reading item)) : (case answered of
                          CoreNeverType -> [statement (CoreEvaluate applied)]
                          _ | maps -> [pushed applied]
                            | otherwise -> [statement (CoreIf applied (CoreBlock [pushed (reading item)] Nothing) Nothing)])
                        (body, loop) = walkArrayItems at withOutput arrayLocal element turn
                        prefix = prefixArray <> [statement (CoreDeclare functionLocal function)] <> convertArray <>
                          [statement (CoreDeclare outputLocal (expression output (CoreArray [])))]
                     in (body, Just (expression output (CoreBlockValue (CoreBlock (prefix <> loop) (Just (reading outputLocal)))), output))
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
                Just value ->
                      let (checked, applied) = predicate True "sortBy comparison must return Bool" invoked value
                          before x y = expression (coreExpressionType applied) (CoreBlockValue (CoreBlock
                            [statement (CoreDeclare left x), statement (CoreDeclare right y)] (Just applied)))
                          (final, statements, result) = sortStatements checked at arrayLocal before
                       in (final, Just (expression kind (CoreBlockValue (CoreBlock (prefix <> statements) (Just (reading result)))), kind))
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

  invokeCallback = invoke True
  invoke adaptable current function arguments
    | Just selected <- mapRuntimeChoice current at CoreNeverType function
        (\ready held -> invoke adaptable ready held arguments) = fmap (fmap fst) selected
    | CoreFunctionType inputs result <- callableKind =
        invokeFunction current inputs result
    | CoreCallbackType{} <- callableKind = halt at "an array callback through a foreign token" current
    | nativeValueType callableKind = (current, Just (notCallable (expression CoreTextType (CoreRuntimeKind function))))
    | otherwise = halt at "an array callback with no native layout" current
   where
    callableKind = coreExpressionType function
    invokeFunction entered inputs result =
      let (ready, chosen)
            | couldReturnLoanFinals callableKind =
                withLoanedCallableArity blame at entered False [] function inputs result arguments apply
            | otherwise =
                withCallableArity blame at entered False function inputs result arguments
                  (\prior defaulted -> apply prior defaulted [])
       in (ready, (checkCallable function . fst) <$> chosen)
     where
      apply prior defaulted loans target given =
        let carry current' (expected, operand) =
              projectRuntimeValue (contextTypes (lowerContext current')) current' expected operand
            (ready, projected) = mapAccumL carry prior (zip inputs given)
            passed = if defaulted then suppliedArguments at inputs projected else projected
            called = expression result (CoreCallValue target passed)
            value
              | map coreExpressionType passed == inputs, null loans = called
              | map coreExpressionType passed == inputs
              , CoreTupleType (answer : finals) <- result, length finals == length loans =
                  expression answer (CoreTupleIndex 0 called)
              | otherwise = mismatch
            mismatch = argumentFailure blame at "E7001" "cannot call a function value with these arguments"
            replay = ready{lowerContext = (lowerContext ready){contextNeedsCallableReplay = True}}
         in if map coreExpressionType passed == inputs
              then (ready, Just (value, coreExpressionType value))
              else if adaptable && null loans
                then case specialize (map coreExpressionType given) replay target of
                  Just (after, Just (selected, _)) ->
                    let (finished, answer) = invoke False after selected given
                     in (finished, (\held -> (held, coreExpressionType held)) <$> answer)
                  Just (after, Nothing) -> refused after
                  Nothing -> (replay, Just (mismatch, CoreNeverType))
                else (ready, Just (mismatch, CoreNeverType))

  checkCallable function applied =
    let label = expression CoreTextType (CoreRuntimeKind function)
        reject name = CoreArm at (CoreLiteralPattern (literal name)) Nothing (notCallable (literal name))
        arms = map reject ["builtin", "task", "foreign function"]
          <> [CoreArm at CoreWildcardPattern Nothing applied]
     in expression (coreExpressionType applied) (CoreMatch label arms)

  notCallable label = argumentFailureWith blame at "E7001" Nothing
    (expression CoreTextType (CoreBinary CoreAdd (literal "cannot call a ") label))

  predicate strict message current value
    | coreExpressionType value `elem` [CoreBoolType, CoreNeverType] = (current, value)
    | Just (ready, Just (selected, _)) <- mapRuntimeChoice current at CoreBoolType value
        (\next held -> let (after, result) = predicate strict message next held in (after, Just result)) =
        (ready, selected)
    | otherwise =
        let answer | strict = argumentFailure blame at "E7001" message
                   | otherwise = expression CoreBoolType (CoreBoolLiteral False)
            block = CoreBlock [statement (CoreEvaluate value)] (Just answer)
         in (current, expression (coreExpressionType answer) (CoreBlockValue block))

  literal = expression CoreTextType . CoreTextLiteral
  blame = methodArgumentBlame state

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
