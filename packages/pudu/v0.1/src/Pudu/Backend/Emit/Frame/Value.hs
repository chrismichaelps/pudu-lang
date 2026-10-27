{-| @Pudu.Backend.Emit.Frame.Value — pure operations over saved frame cells. -}
module Pudu.Backend.Emit.Frame.Value (frameValue, slotText, cellMember) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import qualified Data.Map.Strict as Map
import Pudu.Backend.Emit.State
  ( EmitState (..), cString, cStringBytes, divideByZeroSite, failureSite, operatorFailureSite, overflowSite, shiftSites, textOfInt )
import Pudu.Backend.Emit.Aggregate (aggregateHelper, aggregateNeed, cellName, isAggregate, memberComparable, retained)
import Pudu.Diagnostic.Evaluation (cannotApplyBinaryMessage)
import Pudu.Backend.Emit.Support (integerHelper, integerKindText, integerLiteralText, isWideInteger)
import Pudu.Core (CoreBinaryOperator (..), CoreTextMethodName (..), CoreType (..))
import Pudu.Core.Frame
  ( FrameFault (..), FrameSlot (..), FrameSlotId (..), FrameUnaryOperator (..)
  , FrameValue (..), FrameValueShape (..), coreScalarOperator )
import Pudu.Diagnostic.Arithmetic (CheckedOperation (..))
import Pudu.FloatLiteral (FloatWidth (..))

cellMember :: CoreType -> Maybe Text
cellMember CoreNeverType = Nothing
cellMember kind = Just (cellName kind)

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
  FrameTextLiteral text ->
    plain ("pudu_text_literal(" <> cString text <> ", " <> textOfInt (cStringBytes text) <> ")") ["text_literal"]
  FrameCharLiteral character -> done state ("UINT32_C(0x" <> Text.pack (showHex (fromEnum character) "") <> ")") []
  FrameCharCode slot -> slotText slot >>= \scalar -> plain ("pudu_make((uint64_t)" <> scalar <> ", 0)") ["make"]
  FrameRead slot -> slotText slot >>= \text -> uncurry plain (retained (frameSlotType slot) text)
  FrameAggregate members -> do
    operands <- traverse slotText members
    let kind = frameValueType value
    plain (aggregateHelper "make" kind <> "(" <> Text.intercalate ", " operands <> ")") [aggregateNeed "make" kind]
  FrameConstruct tag members -> do
    operands <- traverse slotText members
    let kind = frameValueType value
        operation = "make" <> textOfInt tag
    plain (aggregateHelper operation kind <> "(" <> Text.intercalate ", " operands <> ")") [aggregateNeed operation kind]
  FrameIsVariant tag held -> slotText held >>= \source -> done state ("(" <> source <> "->fields[0].scalar == " <> textOfInt tag <> ")") []
  FramePayload position held -> do
    source <- slotText held
    member <- maybe (refused "a payload member without a native representation") Right (cellMember (frameValueType value))
    uncurry plain (retained (frameValueType value) (source <> "->fields[" <> textOfInt (position + 1) <> "]." <> member))
  FrameVariantName held -> do
    source <- slotText held
    let kind = frameSlotType held
    plain (aggregateHelper "name" kind <> "(" <> source <> ")") [aggregateNeed "name" kind]
  FrameMember position tuple -> do
    source <- slotText tuple
    member <- maybe (refused "a tuple member without a native representation") Right (cellMember (frameValueType value))
    uncurry plain (retained (frameValueType value) (source <> "->fields[" <> textOfInt position <> "]." <> member))
  FrameClosure name members -> case Map.lookup name (emitFunctionIds state) of
    Nothing -> refused "a closure over an unknown function"
    Just identity -> do
      operands <- traverse slotText members
      let kind = frameValueType value
          operation = "closure" <> textOfInt identity
      plain (aggregateHelper operation kind <> "(" <> Text.intercalate ", " operands <> ")") [aggregateNeed operation kind]
  FrameCapture position closure -> do
    source <- slotText closure
    member <- maybe (refused "a capture without a native representation") Right (cellMember (frameValueType value))
    uncurry plain (retained (frameValueType value) (source <> "->fields[" <> textOfInt (position + 1) <> "]." <> member))
  FrameDisplay slot -> rendered slot
  FrameTextMethod name receiver arguments -> do
    target <- slotText receiver
    operands <- traverse slotText arguments
    let method helper extra = "pudu_" <> helper <> "(" <> Text.intercalate ", " (target : operands <> extra) <> ")"
        simple helper = plain (method helper []) [helper]
        counted helper message =
          let (after, index) = failureSite state at "E7004" message
           in Right (after, method helper [site index], Set.singleton helper)
    case name of
      TextLength -> simple "text_length"
      TextIsEmpty -> simple "text_is_empty"
      TextContains -> simple "text_contains"
      TextStartsWith -> simple "text_starts_with"
      TextEndsWith -> simple "text_ends_with"
      TextIndexOf -> simple "text_index_of"
      TextSpanOf -> plain (method "text_span" ["1"]) ["text_span"]
      TextSpanNotOf -> plain (method "text_span" ["0"]) ["text_span"]
      TextDrop -> counted "text_drop" "a drop count cannot be negative"
      TextTake -> counted "text_take" "a take count cannot be negative"
      TextSlice -> simple "text_slice"
      TextRepeat ->
        let (afterNegative, negative) = failureSite state at "E7004" "a repeat count cannot be negative"
            (after, limit) = failureSite afterNegative at "E7004" "repeated text exceeds the runtime size limit"
         in Right (after, method "text_repeat" [site negative, site limit], Set.singleton "text_repeat")
      TextReverse -> simple "text_reverse"
      TextEscapeHtml -> simple "text_escape_html"
      TextReplace -> simple "text_replace"
      TextTrim -> simple "text_trim"
      TextToUpper -> simple "text_to_upper"
      TextToLower -> simple "text_to_lower"
      TextCharAt -> counted "text_char_at" "index out of range"
  FrameShow slot
    | frameSlotType slot == CoreTextType -> slotText slot >>= \text -> plain ("pudu_text_show(" <> text <> ")") ["text_show"]
    | frameSlotType slot == CoreCharType -> slotText slot >>= \scalar -> plain ("pudu_char_show(" <> scalar <> ")") ["char_show"]
    | isAggregate (frameSlotType slot) -> rendered slot
    | otherwise -> rendered slot
  FrameBinary scalar left right
    | frameSlotType left == CoreTextType -> do
        lhs <- slotText left
        rhs <- slotText right
        let comparison symbol = plain ("(pudu_text_compare(" <> lhs <> ", " <> rhs <> ") " <> symbol <> " 0)") ["text_compare"]
        case coreScalarOperator scalar of
          CoreAdd -> plain ("pudu_text_concat(" <> lhs <> ", " <> rhs <> ")") ["text_concat"]
          CoreEqual -> comparison "=="
          CoreNotEqual -> comparison "!="
          CoreLess -> comparison "<"
          CoreLessOrEqual -> comparison "<="
          CoreGreater -> comparison ">"
          CoreGreaterOrEqual -> comparison ">="
          _ -> refused "an operator text frames do not carry"
  FrameBinary scalar left right
    | kind <- frameSlotType left, isAggregate kind -> do
        lhs <- slotText left
        rhs <- slotText right
        let equal = aggregateHelper "equal" kind <> "(" <> lhs <> ", " <> rhs <> ")"
            -- comparableValue first: a tuple holding a function anywhere has no order.
            (afterSite, index) = operatorFailureSite state at (cannotApplyBinaryMessage (symbolOf (coreScalarOperator scalar)) "tuple" "tuple")
            compared a b symbol = Right
              ( afterSite
              , "((" <> fst (memberComparable kind lhs) <> " && " <> fst (memberComparable kind rhs) <> ") ? ("
                  <> aggregateHelper "compare" kind <> "(" <> a <> ", " <> b <> ") " <> symbol <> " 0) : (pudu_fail(&pudu_sites[" <> textOfInt index <> "]), 0))"
              , Set.fromList [aggregateNeed "compare" kind, aggregateNeed "comparable" kind, "site", "colored", "fail"] )
        -- The evaluator orders tuples through Ord's defaults, and base writes
        -- those in terms of <=: x < y is not (y <= x). A NaN member makes
        -- compare answer GT both ways, so < and > are then both true; swapping
        -- the operands here keeps that.
        case coreScalarOperator scalar of
          CoreEqual -> plain equal [aggregateNeed "equal" kind]
          CoreNotEqual -> plain ("(!" <> equal <> ")") [aggregateNeed "equal" kind]
          CoreLess -> compared rhs lhs ">"
          CoreLessOrEqual -> compared lhs rhs "<="
          CoreGreater -> compared lhs rhs ">"
          CoreGreaterOrEqual -> compared rhs lhs "<="
          _ -> refused "an operator aggregate frames do not carry"
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
          CoreCharType -> done state (lhs <> " " <> symbol <> " " <> rhs) []
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
    symbolOf operator = case operator of
      CoreLess -> "<"
      CoreLessOrEqual -> "<="
      CoreGreater -> ">"
      _ -> ">="
    refused :: Text -> Either FrameFault a
    refused reason = Left (FrameFault (Just at) reason)
    integerKind = case frameValueType value of
      CoreIntegerType kind -> case integerKindText kind of
        Just descriptor -> Right (kind, descriptor)
        Nothing -> refused "an unrepresented frame integer descriptor"
      _ -> refused "an integer frame operation without an integer result"
    floating text helper = Right (state, text, Set.singleton helper)
    plain text needs = Right (state, text, Set.fromList needs)
    rendered slot = do
      text <- slotText slot
      case frameSlotType slot of
        CoreIntegerType kind
          | isWideInteger kind -> plain ("pudu_text_display_wide(" <> text <> ")") ["text_display_wide"]
          | otherwise -> plain ("pudu_text_display_int(" <> text <> ")") ["text_display_int"]
        CoreFloatType _ -> plain ("pudu_text_display_float(" <> text <> ")") ["text_display_float"]
        CoreBoolType -> plain ("(" <> text <> " ? pudu_text_literal(\"true\", 4) : pudu_text_literal(\"false\", 5))") ["text_literal"]
        CoreUnitType -> plain "pudu_text_literal(\"()\", 2)" ["text_literal"]
        CoreTextType -> plain ("pudu_text_retain(" <> text <> ")") ["text_retain"]
        CoreCharType -> plain ("pudu_char_text(" <> text <> ")") ["char_text"]
        kind | isAggregate kind -> plain (aggregateHelper "show" kind <> "(" <> text <> ")") [aggregateNeed "show" kind]
        _ -> refused "a rendered value without a native representation"
    done after text needs = Right (after, text, Set.fromList (map (integerHelper (frameValueType value)) needs))
    call helper arguments = "pudu_" <> integerHelper (frameValueType value) helper <> "(" <> Text.intercalate ", " arguments <> ")"
    site index = "&pudu_sites[" <> textOfInt index <> "]"
