{-| @Pudu.Backend.Emit.Frame.Body — generated bodies suspend at source calls. -}
module Pudu.Backend.Emit.Frame.Body (emitFrameBodies) where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Backend.Emit.Frame.Value (cellMember, frameValue, slotText)
import Pudu.Backend.Emit.State
  ( EmitState (..), callDepthSite, cString, cStringBytes, line, operatorFailureSite, textOfInt )
import Pudu.Backend.Emit.Support (zeroValue)
import Pudu.Core (CoreType (..))
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameFunction (..), FrameInstruction (..)
  , FrameLabel (..), FrameModule (..), FrameSlot (..), FrameSlotId (..), FrameTerminator (..) )

emitFrameBodies :: EmitState -> FrameModule -> Either FrameFault (EmitState, Set Text)
emitFrameBodies state source = do
  let functions = frameModuleFunctions source
      identities = Map.fromList (zip (map frameFunctionName functions) [0 ..])
  if Map.size identities /= length functions
    then Left (FrameFault Nothing "duplicate frame function identities")
    else foldM (emitFunction identities) (state, Set.empty) (zip [0 ..] functions)

emitFunction :: Map Text Int -> (EmitState, Set Text) -> (Int, FrameFunction)
  -> Either FrameFault (EmitState, Set Text)
emitFunction identities (state, needs) (identity, function) = do
  let opened = linesInto state
        [ "static pudu_step pudu_body_" <> textOfInt identity <> "(pudu_frame *frame) {"
        , "  for (;;) {", "    switch (frame->pc) {" ]
  (after, selected) <- foldM emitBlock (opened, needs) (frameFunctionBlocks function)
  pure (linesInto after
    [ "    default: return (pudu_step){.kind = PUDU_INVALID};", "    }", "  }", "}" ], selected)
  where
    emitBlock current block = do
      let (before, selected) = current
          opened = line before ("    case " <> labelText (frameBlockLabel block) <> ":")
      afterInstructions <- foldM instruction (opened, selected) (frameBlockInstructions block)
      terminator identities function afterInstructions (frameBlockTerminator block)

instruction :: (EmitState, Set Text) -> FrameInstruction -> Either FrameFault (EmitState, Set Text)
instruction (state, needs) operation = case operation of
  FrameStore target value -> do
    destination <- slotText target
    (after, expression, selected) <- frameValue state value
    pure (line after ("      " <> destination <> " = " <> expression <> ";"), Set.union needs selected)
  FramePrintLiteral _ text -> printed "print_str" (cString text <> ", " <> textOfInt (cStringBytes text))
  FramePrintUnit _ -> printed "print_str" "\"()\", 2"
  FramePrintSlot at slot -> do
    value <- slotText slot
    case frameSlotType slot of
      CoreIntegerType _ -> printed "print_int" value
      CoreBoolType -> printed "print_bool" value
      CoreUnitType -> printed "print_str" "\"()\", 2"
      _ -> Left (FrameFault (Just at) "an unrepresented frame print value")
  where
    printed helper arguments = Right
      (line state ("      (void)pudu_" <> helper <> "(" <> arguments <> ");"), Set.insert helper needs)

terminator :: Map Text Int -> FrameFunction -> (EmitState, Set Text) -> FrameTerminator
  -> Either FrameFault (EmitState, Set Text)
terminator identities function (state, needs) ending = case ending of
  FrameJump _ target -> pure (jump state (labelText target), needs)
  FrameBranch _ slot yes no -> do
    predicate <- slotText slot
    pure (jump state (predicate <> " ? " <> labelText yes <> " : " <> labelText no), needs)
  FrameCall at name arguments destination resume -> case Map.lookup name identities of
    Nothing -> Left (FrameFault (Just at) "an unknown generated frame callee")
    Just callee -> do
      copies <- traverse copyArgument (zip [0 ..] arguments)
      target <- case destination of
        Nothing -> Right []
        Just slot -> do
          _ <- slotText slot
          pure [", .has_destination = 1, .destination = " <> slotIndex slot]
      let (afterSite, index) = callDepthSite state at
          afterCopies = linesInto afterSite copies
          afterResume = line afterCopies ("      frame->pc = " <> labelText resume <> ";")
          result = "      return (pudu_step){.kind = PUDU_CALL, .function = " <> textOfInt callee
            <> ", .argument_count = " <> textOfInt (length arguments)
            <> foldMap id target <> ", .call_site = &pudu_sites[" <> textOfInt index <> "]};"
      pure (line afterResume result, Set.union needs (Set.fromList ["site", "colored", "fail"]))
  FrameReturn _ payload -> do
    value <- case frameFunctionResult function of
      CoreUnitType -> Right ""
      CoreNeverType -> Right ""
      resultType -> case cellMember resultType of
        Nothing -> Left (FrameFault Nothing "an unrepresented frame return type")
        Just member -> do
          expression <- maybe (Right (zeroValue resultType)) slotText payload
          pure (", .result = {." <> member <> " = " <> expression <> "}")
    pure (line state ("      return (pudu_step){.kind = PUDU_RETURN" <> value <> "};"), needs)
  FrameOperatorFailure at message ->
    let (after, index) = operatorFailureSite state at message
     in pure (linesInto after
          [ "      pudu_fail(&pudu_sites[" <> textOfInt index <> "]);"
          , "      return (pudu_step){.kind = PUDU_INVALID};" ]
        , Set.union needs (Set.fromList ["site", "colored", "fail"]))
  where
    jump current target = linesInto current ["      frame->pc = " <> target <> ";", "      continue;"]
    copyArgument (index, slot) = do
      _ <- slotText slot
      pure ("      frame->arguments[" <> textOfInt index <> "] = frame->slots[" <> slotIndex slot <> "];")

slotIndex :: FrameSlot -> Text
slotIndex slot = case frameSlotId slot of FrameSlotId identity -> textOfInt identity

labelText :: FrameLabel -> Text
labelText (FrameLabel identity) = textOfInt identity

linesInto :: EmitState -> [Text] -> EmitState
linesInto = foldl' line
