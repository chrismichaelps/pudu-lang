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
import Pudu.Core (CoreBinaryOperator (..), CoreType)
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
  deriving stock (Eq, Show)

{-| A call saves its destination and resume block before the dispatcher enters its callee. -}
data FrameTerminator
  = FrameJump !(Maybe Span) !FrameLabel
  | FrameBranch !Span !FrameSlot !FrameLabel !FrameLabel
  | FrameCall !Span !Text ![FrameSlot] !(Maybe FrameSlot) !FrameLabel
  | FrameReturn !(Maybe Span) !(Maybe FrameSlot)
  | FrameOperatorFailure !Span !Text
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
  | FrameDisplay !FrameSlot
  | FrameShow !FrameSlot
  | FrameUnitLiteral
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
