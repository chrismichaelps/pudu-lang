{-| @Pudu.Core.Frame — typed blocks and explicit call continuations. -}
module Pudu.Core.Frame
  ( FrameModule (..), FrameFunction (..), FrameBlock (..), FrameLabel (..)
  , FrameSlot (..), FrameSlotId (..), FrameInstruction (..), FrameTerminator (..)
  , FrameValue (..), FrameValueShape (..), FrameUnaryOperator (..)
  , FrameScalarOperator, scalarOperator, coreScalarOperator, FrameFault (..)
  ) where

import Data.Text (Text)
import Data.Word (Word64)
import Pudu.FloatLiteral (FloatWidth)
import Data.Map.Strict (Map)
import Pudu.Core (CoreArrayMethodName, CoreBinaryOperator (..), CoreClosureInfo, CoreKeyedMethodName, CoreLayout, CoreRangeMethodName, CoreTextMethodName, CoreType)
import Pudu.IntegerLiteral (IntegerKind)
import Pudu.Source (Span)

newtype FrameLabel = FrameLabel Int deriving stock (Eq, Ord, Show)
newtype FrameSlotId = FrameSlotId Int deriving stock (Eq, Ord, Show)

data FrameSlot = FrameSlot
  { frameSlotId :: !FrameSlotId
  , frameSlotName :: !Text
  , frameSlotType :: !CoreType
  , frameSlotSpan :: !Span
  }
  deriving stock (Eq, Show)

data FrameModule = FrameModule
  { frameModuleName :: !Text
  , frameModuleEntry :: !Text
  , frameModuleFunctions :: ![FrameFunction]
  , frameModuleLayouts :: !(Map CoreType CoreLayout)
  , frameModuleClosures :: !(Map Text CoreClosureInfo)
  }
  deriving stock (Eq, Show)

data FrameFunction = FrameFunction
  { frameFunctionName :: !Text
  , frameFunctionParameters :: ![FrameSlot]
  , frameFunctionResult :: !CoreType
  , frameFunctionSlots :: ![FrameSlot]
  , frameFunctionEntry :: !FrameLabel
  , frameFunctionBlocks :: ![FrameBlock]
  }
  deriving stock (Eq, Show)

data FrameBlock = FrameBlock
  { frameBlockLabel :: !FrameLabel
  , frameBlockInstructions :: ![FrameInstruction]
  , frameBlockTerminator :: !FrameTerminator
  }
  deriving stock (Eq, Show)

data FrameInstruction
  = FrameStore !FrameSlot !FrameValue
  | FramePrintLiteral !Span !Text
  | FramePrintSlot !Span !FrameSlot
  | FramePrintUnit !Span
  {-| The second slot's value moves into the first, and the second is left empty. -}
  | FrameMove !FrameSlot !FrameSlot
  deriving stock (Eq, Show)

{-| A call saves its destination and resume block before the dispatcher enters its callee. -}
data FrameTerminator
  = FrameJump !(Maybe Span) !FrameLabel
  | FrameBranch !Span !FrameSlot !FrameLabel !FrameLabel
  | FrameCall !Span !Text ![FrameSlot] !(Maybe FrameSlot) !FrameLabel
  {-| A call through the closure in the first slot, which is also its first argument. -}
  | FrameCallValue !Span !FrameSlot ![FrameSlot] !(Maybe FrameSlot) !FrameLabel
  | FrameReturn !(Maybe Span) !(Maybe FrameSlot)
  | FrameOperatorFailure !Span !Text
  {-| A diagnostic with this code and help whose message is the text in the slot. -}
  | FrameFailText !Span !Text !(Maybe Text) !FrameSlot !(Maybe FrameSlot)
  deriving stock (Eq, Show)

data FrameValue = FrameValue
  { frameValueSpan :: !Span
  , frameValueType :: !CoreType
  , frameValueShape :: !FrameValueShape
  }
  deriving stock (Eq, Show)

data FrameValueShape
  = FrameIntegerLiteral !IntegerKind !Integer
  | FrameFloatLiteral !FloatWidth !Word64
  | FrameBoolLiteral !Bool
  | FrameTextLiteral !Text
  | FrameCharLiteral !Char
  | FrameCharCode !FrameSlot
  | FrameIntegerFits !IntegerKind !FrameSlot
  | FrameCharOfCode !FrameSlot
  | FrameKeyedMethod !CoreKeyedMethodName !FrameSlot ![FrameSlot]
  | FrameComparable !FrameSlot
  | FrameRangeValue !(Maybe FrameSlot) !Bool !(Maybe FrameSlot)
  | FrameRangeMethod !CoreRangeMethodName !FrameSlot ![FrameSlot]
  | FrameIntegerConvert !IntegerKind !FrameSlot
  | FrameAggregate ![FrameSlot]
  | FrameMember !Int !FrameSlot
  {-| A sum value: the variant's index and its payload in declaration order. -}
  | FrameConstruct !Int ![FrameSlot]
  {-| Whether the sum in the slot holds the variant with this index. -}
  | FrameIsVariant !Int !FrameSlot
  {-| A payload member of the variant the slot is known to hold. -}
  | FramePayload !Int !FrameSlot
  {-| The held variant's name as text. -}
  | FrameVariantName !FrameSlot
  | FrameDisplay !FrameSlot
  | FrameShow !FrameSlot
  | FrameTextMethod !CoreTextMethodName !FrameSlot ![FrameSlot]
  | FrameUnitLiteral
  {-| A closure over the named lifted function, holding these values. -}
  | FrameClosure !Text ![FrameSlot]
  {-| Capture number i of the closure in the slot. -}
  | FrameCapture !Int !FrameSlot
  | FrameArray ![FrameSlot]
  {-| An array method on the receiver slot with these arguments. -}
  | FrameArrayMethod !CoreArrayMethodName !FrameSlot ![FrameSlot]
  {-| The array's item at the index, or E7004 at the value's span. -}
  | FrameIndex !FrameSlot !FrameSlot
  | FrameRead !FrameSlot
  | FrameUnary !FrameUnaryOperator !FrameSlot
  | FrameBinary !FrameScalarOperator !FrameSlot !FrameSlot
  deriving stock (Eq, Show)

data FrameUnaryOperator = FrameNegate | FrameComplement | FrameNot
  deriving stock (Eq, Show)

{-| Logical operators require control flow and cannot enter an eager right-hand side. -}
newtype FrameScalarOperator = FrameScalarOperator CoreBinaryOperator
  deriving stock (Eq, Show)

scalarOperator :: CoreBinaryOperator -> Maybe FrameScalarOperator
scalarOperator CoreAnd = Nothing
scalarOperator CoreOr = Nothing
scalarOperator operator = Just (FrameScalarOperator operator)

coreScalarOperator :: FrameScalarOperator -> CoreBinaryOperator
coreScalarOperator (FrameScalarOperator operator) = operator

data FrameFault = FrameFault
  { frameFaultSpan :: !(Maybe Span)
  , frameFaultMessage :: !Text
  }
  deriving stock (Eq, Show)
