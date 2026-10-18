{-| @Pudu.Compiler.Frame.Body — ordered effects and explicit continuations. -}
module Pudu.Compiler.Frame.Body (lowerBlock, lowerExpression) where

import Control.Monad (when)
import qualified Data.Map.Strict as Map
import Pudu.Compiler.Frame.State
  ( Build, BuildState (buildFunctions), Flow (..), LoopTarget (..), begin
  , bindLocal, emit, fault, findLoop, finish, freshLabel, freshSlot, getState
  , isOpen, readLocal, saveValue, storeValue, withLoop )
import Pudu.Core
  ( CoreBinaryOperator (..), CoreBlock (..), CoreExpression (..)
  , CoreExpressionShape (..), CoreFunction (..), CoreLocal (..), CoreParameter (..)
  , CoreStatement (..), CoreStatementShape (..), CoreType (..) )
import Pudu.Core.Frame
  ( FrameInstruction (..), FrameSlot, FrameSlot (frameSlotType), FrameTerminator (..)
  , FrameUnaryOperator (..), FrameValue (..), FrameValueShape (..), scalarOperator )
import Pudu.Source (Span)

lowerBlock :: CoreBlock -> Build Flow
lowerBlock block = statements (coreBlockStatements block)
  where
    statements [] = maybe (pure (Completed Nothing)) lowerExpression (coreBlockResult block)
    statements (statement : rest) = do
      lowerStatement statement
      open <- isOpen
      if open then statements rest else pure Stopped

lowerStatement :: CoreStatement -> Build ()
lowerStatement (CoreStatement at shape) = case shape of
  CoreDeclare local expression -> do
    value <- lowerExpression expression
    case value of
      Stopped -> pure ()
      Completed payload -> bindLocal at local >>= \slot -> storeValue at slot payload
  CoreAssign local expression -> do
    value <- lowerExpression expression
    case value of
      Stopped -> pure ()
      Completed payload -> readLocal at local >>= \slot -> storeValue at slot payload
  CoreEvaluate expression -> lowerExpression expression >> pure ()
  CoreIf condition yes no -> lowerIf at CoreUnitType condition yes no >> pure ()
  CoreReturn expression -> do
    value <- maybe (pure (Completed Nothing)) lowerExpression expression
    case value of
      Stopped -> pure ()
      Completed payload -> finish (FrameReturn (Just at) payload)
  CoreContinue identity -> do
    target <- findLoop at identity
    finish (FrameJump (Just at) (targetContinue target))
  CoreBreak identity expression -> do
    value <- maybe (pure (Completed Nothing)) lowerExpression expression
    case value of
      Stopped -> pure ()
      Completed payload -> do
        target <- findLoop at identity
        maybe (pure ()) (\slot -> storeValue at slot payload) (targetResult target)
        finish (FrameJump (Just at) (targetBreak target))

lowerExpression :: CoreExpression -> Build Flow
lowerExpression expression@(CoreExpression at kind shape) = case shape of
  CoreIntegerLiteral integerKind number -> value (FrameIntegerLiteral integerKind number)
  CoreBoolLiteral boolean -> value (FrameBoolLiteral boolean)
  CoreTextLiteral _ -> pure (Completed Nothing)
  CoreReadLocal local -> readLocal at local >>= value . FrameRead
  CoreNegate operand -> unary FrameNegate operand
  CoreComplement operand -> unary FrameComplement operand
  CoreNot operand -> unary FrameNot operand
  CoreBinary operator left right
    | operator == CoreAnd || operator == CoreOr -> logical at operator left right
    | otherwise -> do
        operands <- lowerOperands [left, right]
        case operands of
          Nothing -> pure Stopped
          Just [lhs, rhs] -> case scalarOperator operator of
            Just scalar -> value (FrameBinary scalar lhs rhs)
            Nothing -> fault (Just at) "a logical operator in an eager expression"
          Just _ -> fault (Just at) "an invalid binary operand count"
  CoreDisplay operand -> discard <$> lowerExpression operand
  CorePrint operand -> lowerPrint at operand
  CoreCall name arguments -> do
    operands <- lowerOperands arguments
    case operands of
      Nothing -> pure Stopped
      Just slots -> do
        functions <- buildFunctions <$> getState
        case Map.lookup name functions of
          Nothing -> fault (Just at) "an unknown frame callee"
          Just callee -> do
            let expected = map (coreLocalType . coreParameterLocal) (coreFunctionParameters callee)
            when (map frameSlotType slots /= expected || kind /= coreFunctionResult callee) $
              fault (Just at) "a call with incompatible frame types"
            destination <- resultSlot at kind
            resume <- freshLabel
            finish (FrameCall at name slots destination resume)
            begin resume
            pure (Completed destination)
  CoreOperatorFailure message operands -> do
    flow <- effects operands
    case flow of
      Stopped -> pure Stopped
      Completed _ -> finish (FrameOperatorFailure at message) >> pure Stopped
  CoreBlockValue block -> lowerBlock block
  CoreIfValue condition yes no -> lowerIf at kind condition yes (Just no)
  CoreWhileValue identity condition body -> do
    test <- freshLabel
    bodyLabel <- freshLabel
    exit <- freshLabel
    finish (FrameJump Nothing test)
    begin test
    predicate <- lowerScalar condition
    case predicate of
      Stopped -> pure Stopped
      Completed (Just slot) -> do
        finish (FrameBranch at slot bodyLabel exit)
        begin bodyLabel
        _ <- withLoop identity (LoopTarget test exit Nothing) (lowerBlock body)
        open <- isOpen
        when open (finish (FrameJump Nothing test))
        begin exit
        pure (Completed Nothing)
      Completed Nothing -> fault (Just at) "a while condition without a value"
  CoreLoopValue identity body -> do
    bodyLabel <- freshLabel
    exit <- freshLabel
    destination <- resultSlot at kind
    finish (FrameJump Nothing bodyLabel)
    begin bodyLabel
    _ <- withLoop identity (LoopTarget bodyLabel exit destination) (lowerBlock body)
    open <- isOpen
    when open (finish (FrameJump Nothing bodyLabel))
    if kind == CoreNeverType then pure Stopped else do
      begin exit
      pure (Completed destination)
  where
    value node = Completed . Just <$> saveValue (FrameValue at kind node)
    unary operator operand = do
      result <- lowerScalar operand
      case result of
        Stopped -> pure Stopped
        Completed (Just slot) -> value (FrameUnary operator slot)
        Completed Nothing -> fault (Just (coreExpressionSpan expression)) "a unary operand without a value"

discard :: Flow -> Flow
discard Stopped = Stopped
discard (Completed _) = Completed Nothing

lowerScalar :: CoreExpression -> Build Flow
lowerScalar expression = do
  result <- lowerExpression expression
  case result of
    Completed Nothing | coreExpressionType expression == CoreUnitType ->
      Completed . Just <$> saveValue (FrameValue (coreExpressionSpan expression) CoreUnitType FrameUnitLiteral)
    Completed Nothing -> fault (Just (coreExpressionSpan expression)) "a scalar operand without a value"
    _ -> pure result

lowerOperands :: [CoreExpression] -> Build (Maybe [FrameSlot])
lowerOperands = go []
  where
    go slots [] = pure (Just (reverse slots))
    go slots (expression : rest) = do
      result <- lowerScalar expression
      case result of
        Stopped -> pure Nothing
        Completed (Just slot) -> go (slot : slots) rest
        Completed Nothing -> fault (Just (coreExpressionSpan expression)) "an argument without a value"

effects :: [CoreExpression] -> Build Flow
effects [] = pure (Completed Nothing)
effects (expression : rest) = do
  result <- lowerExpression expression
  case result of
    Stopped -> pure Stopped
    Completed _ -> effects rest

resultSlot :: Span -> CoreType -> Build (Maybe FrameSlot)
resultSlot at kind = case kind of
  CoreIntegerType _ -> Just <$> freshSlot at "$result" kind
  CoreBoolType -> Just <$> freshSlot at "$result" kind
  CoreUnitType -> pure Nothing
  CoreNeverType -> pure Nothing
  CoreTextType -> fault (Just at) "a materialized text result in scalar frame IR"

lowerPrint :: Span -> CoreExpression -> Build Flow
lowerPrint at operand = case coreExpressionShape operand of
  CoreTextLiteral text -> emit (FramePrintLiteral at text) >> pure (Completed Nothing)
  CoreDisplay inner -> do
    result <- lowerExpression inner
    case result of
      Stopped -> pure Stopped
      Completed payload -> do
        case payload of
          Just slot -> emit (FramePrintSlot at slot)
          Nothing | coreExpressionType inner == CoreUnitType -> emit (FramePrintUnit at)
          Nothing -> fault (Just at) "a display operand without a scalar value"
        pure (Completed Nothing)
  _ -> fault (Just at) "a print argument outside the scalar frame contract"

lowerIf :: Span -> CoreType -> CoreExpression -> CoreBlock -> Maybe CoreExpression -> Build Flow
lowerIf at kind condition yes no = do
  predicate <- lowerScalar condition
  case predicate of
    Stopped -> pure Stopped
    Completed Nothing -> fault (Just at) "an if condition without a value"
    Completed (Just slot) -> do
      yesLabel <- freshLabel
      noLabel <- freshLabel
      join <- freshLabel
      destination <- resultSlot at kind
      finish (FrameBranch at slot yesLabel noLabel)
      begin yesLabel
      yesFlow <- lowerBlock yes
      yesNormal <- close join destination yesFlow
      begin noLabel
      noFlow <- maybe (pure (Completed Nothing)) lowerExpression no
      noNormal <- close join destination noFlow
      if yesNormal || noNormal then begin join >> pure (Completed destination) else pure Stopped
  where
    close join destination flow = case flow of
      Stopped -> pure False
      Completed payload -> do
        maybe (pure ()) (\target -> storeValue at target payload) destination
        finish (FrameJump Nothing join)
        pure True

logical :: Span -> CoreBinaryOperator -> CoreExpression -> CoreExpression -> Build Flow
logical at operator left right = do
  lhs <- lowerScalar left
  case lhs of
    Stopped -> pure Stopped
    Completed Nothing -> fault (Just at) "a logical operand without a value"
    Completed (Just slot) -> do
      rhsLabel <- freshLabel
      skipLabel <- freshLabel
      join <- freshLabel
      destination <- freshSlot at "$logical" CoreBoolType
      let (yes, no) = if operator == CoreAnd then (rhsLabel, skipLabel) else (skipLabel, rhsLabel)
      finish (FrameBranch at slot yes no)
      begin skipLabel
      storeValue at destination (Just slot)
      finish (FrameJump Nothing join)
      begin rhsLabel
      rhs <- lowerScalar right
      case rhs of
        Stopped -> pure ()
        Completed payload -> storeValue at destination payload >> finish (FrameJump Nothing join)
      begin join
      pure (Completed (Just destination))
