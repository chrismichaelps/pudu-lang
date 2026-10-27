{-| @Pudu.Compiler.Lower.Control — numeric lexical loop targets and Never joins.
    Traversal callbacks keep the expression/block recursion owned by Body. -}
module Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinType
  , printValued, expressionIsPrintValued
  ) where

import Data.Text (Text)
import Pudu.Compiler.Lower.State
  ( LowerState (..), LoopFrame (..), halt, intType, refused )
import Pudu.Core
import Pudu.Frontend.Syntax (Block, Expression, Located (..))
import Pudu.Source (Span)

type ExpressionLowerer = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type BlockLowerer = LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)

lowerWhile :: ExpressionLowerer -> BlockLowerer -> Span -> Maybe (Located Text) -> Located Expression -> Located Block -> LowerState -> (LowerState, Maybe (CoreExpression, CoreType))
lowerWhile expression block spanValue label condition body state =
  case expression state condition of
    (afterCondition, Just (coreCondition, conditionType))
      | conditionType `elem` [CoreBoolType, CoreNeverType] ->
          let (pushed, identity) = pushLoop label afterCondition
              (afterBody, coreBody, _) = block pushed body
              resultType = if conditionType == CoreNeverType then CoreNeverType else CoreUnitType
           in (popLoop afterBody, Just (CoreExpression spanValue resultType (CoreWhileValue identity coreCondition coreBody), resultType))
      | otherwise -> halt (locatedSpan condition) ("a while condition of type " <> coreTypeName conditionType) afterCondition
    (after, Nothing) -> refused after

lowerLoop :: BlockLowerer -> Span -> Maybe (Located Text) -> Located Block -> LowerState -> (LowerState, Maybe (CoreExpression, CoreType))
lowerLoop block spanValue label body state =
  let (pushed, identity) = pushLoop label state
      (after, coreBody, _) = block pushed body
      resultType = case lowerLoops after of
        frame : _ -> maybe CoreNeverType id (loopBreakType frame)
        [] -> CoreNeverType
   in (popLoop after, Just (CoreExpression spanValue resultType (CoreLoopValue identity coreBody), resultType))

pushLoop :: Maybe (Located Text) -> LowerState -> (LowerState, CoreLoopId)
pushLoop label state =
  let identity = CoreLoopId (lowerNextLoop state)
   in (state{lowerNextLoop = lowerNextLoop state + 1, lowerLoops = LoopFrame identity (locatedValue <$> label) Nothing : lowerLoops state}, identity)

popLoop :: LowerState -> LowerState
popLoop state = state{lowerLoops = drop 1 (lowerLoops state)}

{-| The operand finishes before observing this break. In particular a Never
    operand can already transfer to this or an enclosing destination. -}
lowerTransfer :: ExpressionLowerer -> Span -> Maybe (Located Text) -> Maybe (Maybe (Located Expression)) -> LowerState -> (LowerState, Maybe CoreStatement)
lowerTransfer expression spanValue label transfer state = case destination of
  Nothing -> halt spanValue "a loop transfer without a native target" state
  Just identity -> case transfer of
    Nothing -> built state (CoreContinue identity)
    Just Nothing -> observe identity state Nothing CoreUnitType
    Just (Just operand) -> case expression state operand of
      (after, Just (coreOperand, operandType))
        | expressionIsPrintValued coreOperand -> halt (locatedSpan operand) "breaking with a Result[(), Str] value" after
        | operandType `elem` [intType, CoreBoolType, CoreUnitType, CoreNeverType] -> observe identity after (Just coreOperand) operandType
        | otherwise -> halt (locatedSpan operand) ("breaking with a " <> coreTypeName operandType <> " value") after
      (after, Nothing) -> refused after
  where
    destination = case [loopIdentity frame | frame <- lowerLoops state, maybe True (\name -> loopLabel frame == Just (locatedValue name)) label] of
      identity : _ -> Just identity
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
