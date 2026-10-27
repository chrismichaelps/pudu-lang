{-| @Pudu.Compiler.Frame.Body — ordered effects and explicit continuations. -}
module Pudu.Compiler.Frame.Body (lowerBlock, lowerExpression) where

import Control.Monad (when)
import qualified Data.Map.Strict as Map
import Pudu.Compiler.Frame.Match (MatchLowering (..), lowerMatch)
import Pudu.Compiler.Frame.State
  ( Build, BuildState (buildFunctions, buildLayouts), Flow (..), LoopTarget (..), begin
  , bindLocal, emit, fault, findLoop, finish, freshLabel, freshSlot, getState
  , isOpen, moveValue, readLocal, saveValue, storeValue, withLoop )
import Pudu.Core
  ( CoreBinaryOperator (..), CoreBlock (..), CoreExpression (..)
  , CoreExpressionShape (..), CoreFunction (..), CoreLayout (..), CoreLocal (..), CoreParameter (..)
  , CoreStatement (..), CoreStatementShape (..), CoreType (..), CoreVariant (..) )
import Data.Text (Text)
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
      Completed payload -> bindLocal at local >>= \slot -> moveValue at slot payload
  CoreAssign local expression -> do
    value <- lowerExpression expression
    case value of
      Stopped -> pure ()
      Completed payload -> readLocal at local >>= \slot -> moveValue at slot payload
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
        maybe (pure ()) (\slot -> moveValue at slot payload) (targetResult target)
        finish (FrameJump (Just at) (targetBreak target))

lowerExpression :: CoreExpression -> Build Flow
lowerExpression expression@(CoreExpression at kind shape) = case shape of
  CoreIntegerLiteral integerKind number -> value (FrameIntegerLiteral integerKind number)
  CoreFloatLiteral width bits -> value (FrameFloatLiteral width bits)
  CoreBoolLiteral boolean -> value (FrameBoolLiteral boolean)
  CoreTextLiteral text -> value (FrameTextLiteral text)
  CoreCharLiteral character -> value (FrameCharLiteral character)
  CoreCharCode operand -> rendered FrameCharCode operand
  CoreIntegerFits kind' operand -> rendered (FrameIntegerFits kind') operand
  CoreCharOfCode operand -> rendered FrameCharOfCode operand
  CoreIntegerConvert kind' operand -> rendered (FrameIntegerConvert kind') operand
  CoreTuple members -> do
    operands <- lowerOperands members
    maybe (pure Stopped) (value . FrameAggregate) operands
  CoreTupleIndex position operand -> rendered (FrameMember position) operand
  CoreRecord written -> do
    operands <- lowerOperands (map snd written)
    declared <- recordLayout kind
    case (operands, declared) of
      (Nothing, _) -> pure Stopped
      (Just slots, Just fields) -> do
        -- Written order ran; the record holds declaration order.
        let byName = zip (map fst written) slots
        case traverse (\(name, _) -> lookup name byName) fields of
          Just ordered -> value (FrameAggregate ordered)
          Nothing -> fault (Just at) "a record literal without every declared field"
      _ -> fault (Just at) "a record literal without a record type"
  CoreConstruct name written -> do
    operands <- lowerOperands (map snd written)
    variants <- sumLayout kind
    case (operands, variants >>= \found -> lookup name [(coreVariantName v, (i, v)) | (i, v) <- zip [0 ..] found]) of
      (Nothing, _) -> pure Stopped
      (Just slots, Just (index, variant)) -> do
        let byName = zip (map fst written) slots
        case traverse (\(field, _) -> lookup field byName) (coreVariantFields variant) of
          Just ordered -> value (FrameConstruct index ordered)
          Nothing -> fault (Just at) "a variant without every payload member"
      _ -> fault (Just at) "a variant outside its sum"
  CoreVariantName operand -> rendered FrameVariantName operand
  CoreFailText code help message computed -> do
    text <- lowerScalar message
    case text of
      Stopped -> pure Stopped
      Completed Nothing -> fault (Just at) "a failure message without a value"
      Completed (Just slot) -> case computed of
        Nothing -> finish (FrameFailText at code help slot Nothing) >> pure Stopped
        Just helpText -> do
          lowered <- lowerScalar helpText
          case lowered of
            Stopped -> pure Stopped
            Completed Nothing -> fault (Just at) "failure help without a value"
            Completed (Just helpSlot) -> finish (FrameFailText at code help slot (Just helpSlot)) >> pure Stopped
  CoreMatch subject arms -> lowerMatch (MatchLowering lowerExpression lowerScalar resultSlot) at kind subject arms
  CoreRecordUpdate base written -> do
    held <- lowerScalar base
    declared <- recordLayout kind
    case (held, declared) of
      (Stopped, _) -> pure Stopped
      (Completed (Just source), Just declaredFields) -> do
        operands <- lowerOperands (map snd written)
        case operands of
          Nothing -> pure Stopped
          Just slots -> do
            let byName = zip (map fst written) slots
            members <- traverse (\(position, (name, fieldKind)) -> case lookup name byName of
                Just slot -> pure slot
                Nothing -> saveValue (FrameValue at fieldKind (FrameMember position source)))
              (zip [0 ..] declaredFields)
            value (FrameAggregate members)
      _ -> fault (Just at) "a record update without a record base"
  CoreField name operand -> do
    declared <- recordLayout (coreExpressionType operand)
    case declared >>= \fields -> lookup name (zip (map fst fields) [0 ..]) of
      Just position -> rendered (FrameMember position) operand
      Nothing -> fault (Just at) "a field read outside a record"
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
  CoreDisplay operand
    | coreExpressionType operand == CoreTextType -> lowerExpression operand
    | otherwise -> rendered FrameDisplay operand
  CoreShow operand -> rendered FrameShow operand
  CoreTextMethod name receiver arguments -> do
    -- The evaluator reads the arguments before the receiver.
    operands <- lowerOperands (arguments <> [receiver])
    case operands of
      Nothing -> pure Stopped
      Just slots -> case reverse slots of
        target : backwards -> value (FrameTextMethod name target (reverse backwards))
        [] -> fault (Just at) "a text method without its receiver"
  CorePrint operand -> lowerPrint at operand
  CoreOutputError errors newline operand -> rendered (FrameOutputError errors newline) operand
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
  CoreClosure name captures -> do
    operands <- lowerOperands captures
    maybe (pure Stopped) (value . FrameClosure name) operands
  CoreCapture position operand -> rendered (FrameCapture position) operand
  CoreCallValue callee arguments -> do
    operands <- lowerOperands (callee : arguments)
    case (operands, coreExpressionType callee) of
      (Nothing, _) -> pure Stopped
      (Just (closure : slots), CoreFunctionType inputs result) -> do
        when (map frameSlotType slots /= inputs || kind /= result) $
          fault (Just at) "a call through a value with incompatible frame types"
        destination <- resultSlot at kind
        resume <- freshLabel
        finish (FrameCallValue at closure slots destination resume)
        begin resume
        pure (Completed destination)
      _ -> fault (Just at) "a call through a value that is not a function"
  CoreArray members -> do
    operands <- lowerOperands members
    maybe (pure Stopped) (value . FrameArray) operands
  CoreArrayMethod name receiver arguments -> do
    -- The evaluator reads the arguments before the receiver.
    operands <- lowerOperands (arguments <> [receiver])
    case operands of
      Nothing -> pure Stopped
      Just slots -> case reverse slots of
        target : backwards -> value (FrameArrayMethod name target (reverse backwards))
        [] -> fault (Just at) "an array method without its receiver"
  CoreKeyedMethod name receiver arguments -> do
    operands <- lowerOperands (arguments <> [receiver])
    case operands of
      Nothing -> pure Stopped
      Just slots -> case reverse slots of
        target : backwards -> value (FrameKeyedMethod name target (reverse backwards))
        [] -> fault (Just at) "a map or set operation without its receiver"
  CoreComparable operand -> rendered FrameComparable operand
  CoreRangeValue low inclusive high -> do
    operands <- lowerOperands (foldMap pure low <> foldMap pure high)
    case operands of
      Nothing -> pure Stopped
      Just slots -> case (low, high, slots) of
        (Just _, Just _, [l, h]) -> value (FrameRangeValue (Just l) inclusive (Just h))
        (Just _, Nothing, [l]) -> value (FrameRangeValue (Just l) inclusive Nothing)
        (Nothing, Just _, [h]) -> value (FrameRangeValue Nothing inclusive (Just h))
        (Nothing, Nothing, []) -> value (FrameRangeValue Nothing inclusive Nothing)
        _ -> fault (Just at) "a range whose ends did not lower"
  CoreBytesMethod name receiver arguments -> do
    operands <- lowerOperands (arguments <> [receiver])
    case operands of
      Nothing -> pure Stopped
      Just slots -> case reverse slots of
        target : backwards -> value (FrameBytesMethod name target (reverse backwards))
        [] -> fault (Just at) "a byte operation without its receiver"
  CoreRangeMethod name receiver arguments -> do
    operands <- lowerOperands (arguments <> [receiver])
    case operands of
      Nothing -> pure Stopped
      Just slots -> case reverse slots of
        target : backwards -> value (FrameRangeMethod name target (reverse backwards))
        [] -> fault (Just at) "a range operation without its receiver"
  CoreIndex container index -> do
    operands <- lowerOperands [container, index]
    case operands of
      Just [array, position] -> value (FrameIndex array position)
      Just _ -> fault (Just at) "an index without its array"
      Nothing -> pure Stopped
  CoreTakeLocal local -> do
    source <- readLocal at local
    target <- freshSlot at "$taken" (coreLocalType local)
    emit (FrameMove target source)
    pure (Completed (Just target))
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
    rendered shapeOf operand = do
      result <- lowerScalar operand
      case result of
        Stopped -> pure Stopped
        Completed (Just slot) -> value (shapeOf slot)
        Completed Nothing -> fault (Just at) "a rendered operand without a value"
    unary operator operand = do
      result <- lowerScalar operand
      case result of
        Stopped -> pure Stopped
        Completed (Just slot) -> value (FrameUnary operator slot)
        Completed Nothing -> fault (Just (coreExpressionSpan expression)) "a unary operand without a value"

recordLayout :: CoreType -> Build (Maybe [(Text, CoreType)])
recordLayout kind = do
  layouts <- buildLayouts <$> getState
  pure $ case Map.lookup kind layouts of
    Just (CoreRecordLayout fields) -> Just fields
    _ -> Nothing

sumLayout :: CoreType -> Build (Maybe [CoreVariant])
sumLayout kind = do
  layouts <- buildLayouts <$> getState
  pure $ case Map.lookup kind layouts of
    Just (CoreSumLayout variants) -> Just variants
    _ -> Nothing

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
  CoreFloatType _ -> Just <$> freshSlot at "$result" kind
  CoreBoolType -> Just <$> freshSlot at "$result" kind
  CoreUnitType -> pure Nothing
  CoreNeverType -> pure Nothing
  CoreTextType -> Just <$> freshSlot at "$result" kind
  CoreCharType -> Just <$> freshSlot at "$result" kind
  CoreTupleType _ -> Just <$> freshSlot at "$result" kind
  CoreRecordType _ _ -> Just <$> freshSlot at "$result" kind
  CoreSumType _ _ -> Just <$> freshSlot at "$result" kind
  CoreFunctionType _ _ -> Just <$> freshSlot at "$result" kind
  CoreArrayType _ -> Just <$> freshSlot at "$result" kind
  CoreMapType _ _ -> Just <$> freshSlot at "$result" kind
  CoreSetType _ -> Just <$> freshSlot at "$result" kind
  CoreRangeType -> Just <$> freshSlot at "$result" kind
  CoreBytesType -> Just <$> freshSlot at "$result" kind

lowerPrint :: Span -> CoreExpression -> Build Flow
lowerPrint at operand = case coreExpressionShape operand of
  CoreTextLiteral text -> emit (FramePrintLiteral at text) >> pure (Completed Nothing)
  CoreDisplay inner | coreExpressionType inner /= CoreTextType -> do
    result <- lowerExpression inner
    case result of
      Stopped -> pure Stopped
      Completed payload -> do
        case payload of
          Just slot -> emit (FramePrintSlot at slot)
          Nothing | coreExpressionType inner == CoreUnitType -> emit (FramePrintUnit at)
          Nothing -> fault (Just at) "a display operand without a scalar value"
        pure (Completed Nothing)
  _ -> do
    result <- lowerExpression operand
    case result of
      Stopped -> pure Stopped
      Completed (Just slot) -> emit (FramePrintSlot at slot) >> pure (Completed Nothing)
      Completed Nothing -> fault (Just at) "a print argument without a text value"

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
        maybe (pure ()) (\target -> moveValue at target payload) destination
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
        Completed payload -> moveValue at destination payload >> finish (FrameJump Nothing join)
      begin join
      pure (Completed (Just destination))
