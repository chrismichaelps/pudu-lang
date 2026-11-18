{-| @Backend.Emit.Frame.References — the slot projection of frame operations. -}
module Pudu.Backend.Emit.Frame.References (instructionSlots, terminatorSlots, valueSlots) where

import Pudu.Core.Frame
  ( FrameInstruction (..), FrameSlot, FrameTerminator (..)
  , FrameValue (..), FrameValueShape (..) )

instructionSlots :: Applicative f => (FrameSlot -> f FrameSlot) -> FrameInstruction -> f FrameInstruction
instructionSlots slot operation = case operation of
  FrameStore target value -> FrameStore <$> slot target <*> valueSlots slot value
  FrameMove target source -> FrameMove <$> slot target <*> slot source
  FramePrintSlot at source -> FramePrintSlot at <$> slot source
  FramePrintLiteral{} -> pure operation
  FramePrintUnit{} -> pure operation

terminatorSlots :: Applicative f => (FrameSlot -> f FrameSlot) -> FrameTerminator -> f FrameTerminator
terminatorSlots slot terminator = case terminator of
  FrameJump{} -> pure terminator
  FrameBranch at condition yes no -> (\value -> FrameBranch at value yes no) <$> slot condition
  FrameCall at name arguments destination next ->
    (\args result -> FrameCall at name args result next) <$> traverse slot arguments <*> traverse slot destination
  FrameCallValue at callee arguments destination next ->
    (\closure args result -> FrameCallValue at closure args result next)
      <$> slot callee <*> traverse slot arguments <*> traverse slot destination
  FrameReturn at result -> FrameReturn at <$> traverse slot result
  FrameOperatorFailure{} -> pure terminator
  FrameFailText at code help message computed ->
    FrameFailText at code help <$> slot message <*> traverse slot computed
  FrameFailCaller at code help message -> FrameFailCaller at code help <$> slot message

valueSlots :: Applicative f => (FrameSlot -> f FrameSlot) -> FrameValue -> f FrameValue
valueSlots slot value = (\shape -> value{frameValueShape = shape}) <$> case frameValueShape value of
  shape@FrameIntegerLiteral{} -> pure shape
  shape@FrameFloatLiteral{} -> pure shape
  shape@FrameDecimalLiteral{} -> pure shape
  shape@FrameBoolLiteral{} -> pure shape
  shape@FrameTextLiteral{} -> pure shape
  shape@FrameBytesLiteral{} -> pure shape
  shape@FrameCharLiteral{} -> pure shape
  FrameCharCode source -> FrameCharCode <$> slot source
  FrameIntegerFits kind source -> FrameIntegerFits kind <$> slot source
  FrameCharOfCode source -> FrameCharOfCode <$> slot source
  FrameKeyedMethod method receiver arguments -> FrameKeyedMethod method <$> slot receiver <*> traverse slot arguments
  FrameComparable source -> FrameComparable <$> slot source
  FrameRangeValue start exclusive end ->
    (\first lastValue -> FrameRangeValue first exclusive lastValue) <$> traverse slot start <*> traverse slot end
  FrameRangeMethod method receiver arguments -> FrameRangeMethod method <$> slot receiver <*> traverse slot arguments
  FrameBytesMethod method receiver arguments -> FrameBytesMethod method <$> slot receiver <*> traverse slot arguments
  FrameDecimalMethod method arguments -> FrameDecimalMethod method <$> traverse slot arguments
  FrameKernel kernel immediates arguments -> FrameKernel kernel immediates <$> traverse slot arguments
  FrameCallback operation operand -> FrameCallback operation <$> slot operand
  FrameForeign foreignCall arguments -> FrameForeign foreignCall <$> traverse slot arguments
  FrameForeignSettle -> pure FrameForeignSettle
  FrameIntegerConvert kind source -> FrameIntegerConvert kind <$> slot source
  FrameAggregate members -> FrameAggregate <$> traverse slot members
  FrameMember index source -> FrameMember index <$> slot source
  FrameConstruct variant members -> FrameConstruct variant <$> traverse slot members
  FrameIsVariant variant source -> FrameIsVariant variant <$> slot source
  FramePayload index source -> FramePayload index <$> slot source
  FrameRuntimeKind source -> FrameRuntimeKind <$> slot source
  FrameDisplay source -> FrameDisplay <$> slot source
  FrameShow source -> FrameShow <$> slot source
  FrameOutputError newline stderr source -> FrameOutputError newline stderr <$> slot source
  FrameTextMethod method receiver arguments -> FrameTextMethod method <$> slot receiver <*> traverse slot arguments
  FrameUnitLiteral -> pure FrameUnitLiteral
  FrameZero -> pure FrameZero
  FrameClosure name captures -> FrameClosure name <$> traverse slot captures
  FrameCapture index source -> FrameCapture index <$> slot source
  FrameArray items -> FrameArray <$> traverse slot items
  FrameArrayMethod method receiver arguments -> FrameArrayMethod method <$> slot receiver <*> traverse slot arguments
  FrameIndex source index -> FrameIndex <$> slot source <*> slot index
  FrameRead source -> FrameRead <$> slot source
  FrameUnary operator source -> FrameUnary operator <$> slot source
  FrameBinary operator left right -> FrameBinary operator <$> slot left <*> slot right
