{-| @Pudu.Backend.Emit.Frame.Value — pure operations over saved frame cells. -}
module Pudu.Backend.Emit.Frame.Value (frameValue, slotText, cellMember) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import Pudu.Backend.Emit.State
  ( EmitState, divideByZeroSite, overflowSite, shiftSites, textOfInt )
import Pudu.Backend.Emit.Support (integerHelper, integerKindText, integerLiteralText, isWideInteger)
import Pudu.Core (CoreBinaryOperator (..), CoreType (..))
import Pudu.Core.Frame
  ( FrameFault (..), FrameSlot (..), FrameSlotId (..), FrameUnaryOperator (..)
  , FrameValue (..), FrameValueShape (..), coreScalarOperator )
import Pudu.Diagnostic.Arithmetic (CheckedOperation (..))
import Pudu.FloatLiteral (FloatWidth (..))

cellMember :: CoreType -> Maybe Text
cellMember (CoreIntegerType kind) = Just (if isWideInteger kind then "wide" else "integer")
cellMember (CoreFloatType _) = Just "floating"
cellMember CoreBoolType = Just "scalar"
cellMember CoreUnitType = Just "scalar"
cellMember _ = Nothing

slotText :: FrameSlot -> Either FrameFault Text
slotText slot = case (frameSlotId slot, cellMember (frameSlotType slot)) of
  (FrameSlotId identity, Just member) | identity >= 0 ->
    Right ("frame->slots[" <> textOfInt identity <> "]." <> member)
  _ -> Left (FrameFault (Just (frameSlotSpan slot)) "an invalid scalar frame slot")

frameValue :: EmitState -> FrameValue -> Either FrameFault (EmitState, Text, Set Text)
frameValue state value = case frameValueShape value of
  FrameIntegerLiteral kind number -> done state (integerLiteralText kind number) []
  FrameFloatLiteral _ bits -> Right (state, "UINT64_C(0x" <> Text.pack (showHex bits "") <> ")", Set.empty)
  FrameBoolLiteral flag -> done state (if flag then "1" else "0") []
  FrameUnitLiteral -> done state "0" []
  FrameRead slot -> slotText slot >>= \text -> done state text []
  FrameUnary FrameNegate operand
    | CoreFloatType _ <- frameSlotType operand -> do
        text <- slotText operand
        floating ("pudu_float_neg(" <> text <> ")") "float_neg"
  FrameBinary scalar left right
    | CoreFloatType width <- frameSlotType left -> do
        lhs <- slotText left
        rhs <- slotText right
        let narrow = if width == Float32Width then "1" else "0"
            arithmetic helper = floating ("pudu_" <> helper <> "(" <> lhs <> ", " <> rhs <> ", " <> narrow <> ")") helper
            predicate helper = floating ("pudu_" <> helper <> "(" <> lhs <> ", " <> rhs <> ")") helper
        case coreScalarOperator scalar of
          CoreAdd -> arithmetic "float_add"
          CoreSubtract -> arithmetic "float_sub"
          CoreMultiply -> arithmetic "float_mul"
          CoreDivide -> arithmetic "float_div"
          CoreEqual -> predicate "float_eq"
          CoreNotEqual -> predicate "float_ne"
          CoreLess -> predicate "float_lt"
          CoreLessOrEqual -> predicate "float_le"
          CoreGreater -> predicate "float_gt"
          CoreGreaterOrEqual -> predicate "float_ge"
          _ -> refused "an operator floating frames do not carry"
  FrameUnary operator operand -> do
    text <- slotText operand
    case operator of
      FrameNot -> done state ("(!" <> text <> ")") []
      FrameComplement -> do
        (_, descriptor) <- integerKind
        done state (call "bit_not" [text, descriptor]) ["bit_not"]
      FrameNegate -> do
        (kind, descriptor) <- integerKind
        let (after, index) = overflowSite state at kind CheckedNegate
        done after (call "neg" [text, descriptor, site index]) ["neg"]
  FrameBinary scalar left right -> do
    lhs <- slotText left
    rhs <- slotText right
    let checked helper operation = do
          (kind, descriptor) <- integerKind
          let (after, index) = overflowSite state at kind operation
          done after (call helper [lhs, rhs, descriptor, site index]) [helper]
        binary helper = do
          (_, descriptor) <- integerKind
          done state (call helper [lhs, rhs, descriptor]) [helper]
        shift helper = do
          (kind, descriptor) <- integerKind
          let (after, negative, wide) = shiftSites state at kind
          done after (call helper [lhs, rhs, descriptor, site negative, site wide]) [helper]
        comparison symbol = case frameSlotType left of
          CoreIntegerType _ ->
            let helper = integerHelper (frameSlotType left) "compare"
             in done state (call helper [lhs, rhs] <> " " <> symbol <> " 0") [helper]
          CoreBoolType -> done state (lhs <> " " <> symbol <> " " <> rhs) []
          CoreUnitType -> done state (lhs <> " " <> symbol <> " " <> rhs) []
          _ -> refused "an unrepresented comparison operand"
    case coreScalarOperator scalar of
      CoreAdd -> checked "add" CheckedAdd
      CoreSubtract -> checked "sub" CheckedSubtract
      CoreMultiply -> checked "mul" CheckedMultiply
      CoreDivide -> do
        (kind, descriptor) <- integerKind
        let (afterZero, zero) = divideByZeroSite state at
            (after, overflow) = overflowSite afterZero at kind CheckedDivide
        done after (call "div" [lhs, rhs, descriptor, site zero, site overflow]) ["div"]
      CoreRemainder ->
        let (after, zero) = divideByZeroSite state at
         in done after (call "rem" [lhs, rhs, site zero]) ["rem"]
      CoreBitAnd -> binary "bit_and"
      CoreBitOr -> binary "bit_or"
      CoreBitXor -> binary "bit_xor"
      CoreShiftLeft -> shift "shift_left"
      CoreShiftRight -> shift "shift_right"
      CoreWrapAdd -> binary "wrap_add"
      CoreWrapSubtract -> binary "wrap_sub"
      CoreWrapMultiply -> binary "wrap_mul"
      CoreSaturateAdd -> binary "sat_add"
      CoreSaturateSubtract -> binary "sat_sub"
      CoreSaturateMultiply -> binary "sat_mul"
      CoreLess -> comparison "<"
      CoreLessOrEqual -> comparison "<="
      CoreGreater -> comparison ">"
      CoreGreaterOrEqual -> comparison ">="
      CoreEqual -> comparison "=="
      CoreNotEqual -> comparison "!="
      CoreAnd -> refused "an eager logical And in frame IR"
      CoreOr -> refused "an eager logical Or in frame IR"
  where
    at = frameValueSpan value
    refused :: Text -> Either FrameFault a
    refused reason = Left (FrameFault (Just at) reason)
    integerKind = case frameValueType value of
      CoreIntegerType kind -> case integerKindText kind of
        Just descriptor -> Right (kind, descriptor)
        Nothing -> refused "an unrepresented frame integer descriptor"
      _ -> refused "an integer frame operation without an integer result"
    floating text helper = Right (state, text, Set.singleton helper)
    done after text needs = Right (after, text, Set.fromList (map (integerHelper (frameValueType value)) needs))
    call helper arguments = "pudu_" <> integerHelper (frameValueType value) helper <> "(" <> Text.intercalate ", " arguments <> ")"
    site index = "&pudu_sites[" <> textOfInt index <> "]"
