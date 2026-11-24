{-| @Pudu.Compiler.Lower.Control — numeric lexical loop targets and Never joins.
    Traversal callbacks keep the expression/block recursion owned by Body. -}
module Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinType, pushLoop, popLoop
  , ConditionUse (StrictCondition, MatchGuard), lowerCondition
  , printValued, expressionIsPrintValued, droppedTail
  ) where

import Data.List (mapAccumL)
import Data.Maybe (isJust)
import Data.Text (Text)
import Pudu.Compiler.Lower.Dynamic (isDynamic, joinRuntimeArms, widenTo)
import Pudu.Compiler.Lower.State
  ( LowerContext (..), LowerState (..), LoopFrame (..), bindLocal, halt, refused )
import Pudu.Compiler.Lower.Types (nativeValueType, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Block (..), Expression, Located (..), Statement (..))
import Pudu.Source (Span)

type ExpressionLowerer = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type BlockLowerer = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)

data ConditionUse = StrictCondition | MatchGuard

{-| A guard accepts only true. A strict condition diagnoses any non-Bool. -}
lowerCondition :: ConditionUse -> Span -> ExpressionLowerer -> ExpressionLowerer
lowerCondition use at lower state written = case lower state written of
  (after, Nothing) -> refused after
  (after, Just (value, _)) -> select after value
 where
  expression kind shape = CoreExpression at kind shape
  select current held
    | kind `elem` [CoreBoolType, CoreNeverType] = (current, Just (held, kind))
    | isDynamic kind || isJust (runtimeChoiceAlternatives kind) =
        case sumVariants (contextTypes (lowerContext current)) kind >>= traverse payloadOf of
          Nothing -> halt at "a condition without a settled payload layout" current
          Just variants ->
            let (after, arms) = mapAccumL arm current variants
                result = joinRuntimeArms at CoreBoolType held <$> sequence arms
             in (after, (\value -> (value, coreExpressionType value)) <$> result)
    | otherwise = case use of
        StrictCondition ->
          let text = expression CoreTextType
              message = text (CoreBinary CoreAdd (text (CoreTextLiteral "expected a bool, found a "))
                (text (CoreRuntimeKind held)))
           in (current, Just (expression CoreNeverType (CoreFailText "E7001" Nothing message Nothing), CoreNeverType))
        MatchGuard ->
          let effects = [CoreStatement (coreExpressionSpan held) (CoreEvaluate held)]
              value = expression CoreBoolType (CoreBlockValue (CoreBlock effects (Just (expression CoreBoolType (CoreBoolLiteral False)))))
           in (current, Just (value, CoreBoolType))
   where
    kind = coreExpressionType held
  payloadOf variant = case coreVariantFields variant of
    [(_, payload)] -> Just (coreVariantName variant, payload)
    _ -> Nothing
  arm current (tag, kind) =
    let (bound, local) = bindLocal current "" kind
        (after, result) = select bound (expression kind (CoreReadLocal local))
     in (after, (\(body, _) -> CoreArm at (CoreVariantPattern tag [CoreBindPattern local]) Nothing body) <$> result)

lowerWhile :: ExpressionLowerer -> BlockLowerer -> Span -> Maybe (Located Text) -> Located Expression -> Located Block -> LowerState -> (LowerState, Maybe (CoreExpression, CoreType))
lowerWhile lower block spanValue label condition body state =
  case lowerCondition StrictCondition spanValue lower state condition of
    (after, Just stopped@(_, CoreNeverType)) -> (after, Just stopped)
    (afterCondition, Just (coreCondition, _)) ->
      let (pushed, identity) = pushLoop label afterCondition
          (afterBody, coreBody, _) = block pushed (droppedTail body)
       in (popLoop afterBody, Just (CoreExpression spanValue CoreUnitType (CoreWhileValue identity coreCondition coreBody), CoreUnitType))
    (after, Nothing) -> refused after

lowerLoop :: BlockLowerer -> Span -> Maybe (Located Text) -> Located Block -> LowerState -> (LowerState, Maybe (CoreExpression, CoreType))
lowerLoop block spanValue label body state =
  let expected = typeForSpan (contextTypes (lowerContext state)) spanValue
      (pushed, identity) = pushLoopWith expected label state
      (after, coreBody, _) = block pushed (droppedTail body)
      resultType = case lowerLoops after of
        frame : _ -> maybe CoreNeverType id (loopBreakType frame)
        [] -> CoreNeverType
   in (popLoop after, Just (CoreExpression spanValue resultType (CoreLoopValue identity coreBody), resultType))

{-| A loop body's value is thrown away each turn, so its tail is just another
    statement. Lowered that way, a tail like `match ... { case _ => print(..) }`
    doesn't have to produce print's Result. -}
droppedTail :: Located Block -> Located Block
droppedTail (Located at (Block statements (Just tail'))) =
  Located at (Block (statements <> [Located (locatedSpan tail') (ExpressionStatement tail')]) Nothing)
droppedTail body = body

pushLoop :: Maybe (Located Text) -> LowerState -> (LowerState, CoreLoopId)
pushLoop = pushLoopWith Nothing

pushLoopWith :: Maybe CoreType -> Maybe (Located Text) -> LowerState -> (LowerState, CoreLoopId)
pushLoopWith expected label state =
  let identity = CoreLoopId (lowerNextLoop state)
      frame = LoopFrame identity (locatedValue <$> label) expected Nothing
   in (state{lowerNextLoop = lowerNextLoop state + 1, lowerLoops = frame : lowerLoops state}, identity)

popLoop :: LowerState -> LowerState
popLoop state = state{lowerLoops = drop 1 (lowerLoops state)}

{-| The operand finishes before observing this break. In particular a Never
    operand can already transfer to this or an enclosing destination. -}
lowerTransfer :: ExpressionLowerer -> Span -> Maybe (Located Text) -> Maybe (Maybe (Located Expression)) -> LowerState -> (LowerState, Maybe CoreStatement)
lowerTransfer expression spanValue label transfer state = case destination of
  Nothing -> halt spanValue "a loop transfer without a native target" state
  Just frame -> case transfer of
    Nothing -> built state (CoreContinue identity)
    Just Nothing -> observe identity state Nothing CoreUnitType
    Just (Just operand) -> case expression state operand of
      (after, Just lowered)
        | expressionIsPrintValued coreOperand -> halt (locatedSpan operand) "breaking with a Result[(), Str] value" after
        | nativeValueType operandType || operandType == CoreNeverType -> observe identity after (Just coreOperand) operandType
        | otherwise -> halt (locatedSpan operand) ("breaking with a " <> coreTypeName operandType <> " value") after
        where
          (coreOperand, operandType) = case loopExpectedBreakType frame of
            Just expected -> widenTo (contextTypes (lowerContext after)) expected lowered
            Nothing -> lowered
      (after, Nothing) -> refused after
    where
      identity = loopIdentity frame
  where
    destination = case [frame | frame <- lowerLoops state, maybe True (\name -> loopLabel frame == Just (locatedValue name)) label] of
      frame : _ -> Just frame
      [] -> Nothing
    built after shape = (after, Just (CoreStatement spanValue shape))
    observe identity after operand operandType
      | operandType == CoreNeverType = built after (CoreBreak identity operand)
      | otherwise = case traverse update (lowerLoops after) of
          Just frames -> built after{lowerLoops = frames} (CoreBreak identity operand)
          Nothing -> halt spanValue "loop breaks with different native result types" after
      where
        update frame
          | loopIdentity frame /= identity = Just frame
          | otherwise = case loopBreakType frame of
              Nothing -> Just frame{loopBreakType = Just operandType}
              Just previous -> (\joined -> frame{loopBreakType = Just joined}) <$> joinType previous operandType

joinType :: CoreType -> CoreType -> Maybe CoreType
joinType CoreNeverType right = Just right
joinType left CoreNeverType = Just left
joinType left right | left == right = Just left
joinType _ _ = Nothing

blockType :: [CoreStatement] -> Maybe CoreExpression -> CoreType
blockType statements result
  | any terminal statements = CoreNeverType
  | otherwise = maybe CoreUnitType coreExpressionType result
  where
    terminal (CoreStatement _ shape) = case shape of
      CoreReturn _ -> True
      CoreBreak _ _ -> True
      CoreContinue _ -> True
      CoreEvaluate expression -> coreExpressionType expression == CoreNeverType
      CoreDeclare _ expression -> coreExpressionType expression == CoreNeverType
      CoreAssign _ expression -> coreExpressionType expression == CoreNeverType
      CoreIf condition _ _ -> coreExpressionType condition == CoreNeverType

printValued :: CoreBlock -> Bool
printValued block
  | blockType (coreBlockStatements block) (coreBlockResult block) == CoreNeverType = False
  | otherwise = maybe False expressionIsPrintValued (coreBlockResult block)

expressionIsPrintValued :: CoreExpression -> Bool
expressionIsPrintValued expression
  | coreExpressionType expression == CoreNeverType = False
  | otherwise = case coreExpressionShape expression of
      CorePrint _ -> True
      CoreBlockValue block -> printValued block
      CoreIfValue _ thenBlock elseExpression -> printValued thenBlock || expressionIsPrintValued elseExpression
      _ -> False
