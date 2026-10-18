{-| @Pudu.Diagnostic.Arithmetic — one home for the text of checked-arithmetic
    refusals.

    The tree evaluator, the unboxed loop path, and the native C runtime all
    refuse the same operations, and a programmer who reads one of those
    refusals must read the same words whichever path ran. The codes, messages,
    and help live here as plain text; building a `Diagnostic`, choosing a span,
    and rendering belong to their owners.
-}
module Pudu.Diagnostic.Arithmetic
  ( CheckedOperation (..)
  , checkedOperationName
  , divideByZeroCode
  , divideByZeroMessage
  , overflowCode
  , overflowHelp
  , overflowMessage
  , shiftCode, negativeShiftMessage, negativeShiftHelp, wideShiftMessage, wideShiftHelp
  ) where

import Data.Text (Text)
import Pudu.IntegerLiteral (IntegerKind, integerKindName)

{-| @Diagnostic.Arithmetic.Operation — the closed set of operations whose
    checked form can refuse. -}
data CheckedOperation
  = CheckedAdd
  | CheckedSubtract
  | CheckedMultiply
  | CheckedDivide
  | CheckedNegate
  deriving stock (Eq, Show)

{-| The operation's name as a reader meets it in the refusal sentence. -}
checkedOperationName :: CheckedOperation -> Text
checkedOperationName operation = case operation of
  CheckedAdd -> "add"
  CheckedSubtract -> "subtract"
  CheckedMultiply -> "multiply"
  CheckedDivide -> "divide"
  CheckedNegate -> "negate"

overflowCode :: Text
overflowCode = "E7005"

{-| @Diagnostic.Arithmetic.Overflow — the kind that cannot hold the result,
    named as the writer declared it. -}
overflowMessage :: IntegerKind -> CheckedOperation -> Text
overflowMessage kind operation =
  integerKindName kind <> " cannot hold the result of this " <> checkedOperationName operation

overflowHelp :: Text
overflowHelp =
  "use the wrapping or saturating form, or a wider type; "
    <> "checked arithmetic never truncates quietly"

divideByZeroCode :: Text
divideByZeroCode = "E7004"

divideByZeroMessage :: Text
divideByZeroMessage = "division by zero"

shiftCode :: Text
shiftCode = "E7004"

negativeShiftMessage :: Text
negativeShiftMessage = "a shift count cannot be negative"

negativeShiftHelp :: Text
negativeShiftHelp = "shift by a non-negative count smaller than the type's width"

wideShiftMessage :: IntegerKind -> Text
wideShiftMessage kind = "a shift count must be smaller than " <> integerKindName kind <> "'s width"

wideShiftHelp :: Text
wideShiftHelp = "mask the count, or use a wider type"
