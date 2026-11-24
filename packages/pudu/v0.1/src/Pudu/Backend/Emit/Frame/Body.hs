{-| @Pudu.Backend.Emit.Frame.Body — generated bodies suspend at source calls;
    a direct function's body runs to its return and calls direct callees as
    plain C functions. -}
module Pudu.Backend.Emit.Frame.Body (emitFrameBodies) where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Aggregate (aggregateHelper, aggregateNeed, cType, isAggregate, ownedType, released, retained)
import Pudu.Backend.Emit.Frame.Direct (enteredDirect)
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Backend.Emit.Frame.Value (cellMember, frameValue, slotText)
import Pudu.Backend.Emit.State
  ( EmitState (..), callDepthSite, cString, cStringBytes, line, operatorFailureSite, profileLabel, textFailureSite, textOfInt )
import Pudu.Backend.Emit.Support (integerHelper, zeroValue)
import Pudu.Core (CoreType (..))
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameFunction (..), FrameInstruction (..)
  , FrameLabel (..), FrameModule (..), FrameSlot (..), FrameSlotId (..), FrameTerminator (..), takenSlotName )

-- | How a body continues: suspending to the dispatcher, or running to its
-- return as a direct function.
data Mode = Suspending | Running

-- | What a terminator needs about the module: each function's identity and
-- definition, and which functions are direct.
data Callees = Callees
  { calleeIds :: !(Map Text Int)
  , calleeFunctions :: !(Map Text FrameFunction)
  , calleeDirect :: !(Set Text)
  }

{-| The bodies of every function, given the direct set. Prototypes of the
    direct functions come first, so any body may call one. -}
emitFrameBodies :: Set Text -> EmitState -> FrameModule -> Either FrameFault (EmitState, Set Text)
emitFrameBodies direct state source = do
  let functions = frameModuleFunctions source
      identities = Map.fromList (zip (map frameFunctionName functions) [0 ..])
      callees = Callees identities (Map.fromList [(frameFunctionName function, function) | function <- functions]) direct
      -- Every body is declared first, under the label a profiler shows.
      prototypes =
        [ "static pudu_step pudu_body_" <> textOfInt identity <> "(pudu_frame *frame)"
            <> profileLabel "body" (frameFunctionName function) identity <> ";"
        | (identity, function) <- zip [0 :: Int ..] functions ]
        <> [ "static pudu_cell pudu_run_" <> textOfInt identity <> "(pudu_frame *frame)"
               <> profileLabel "run" (frameFunctionName function) identity <> ";"
           | (identity, function) <- zip [0 :: Int ..] functions, Set.member (frameFunctionName function) direct ]
        <> [ "static pudu_cell pudu_direct_" <> textOfInt identity <> "(const pudu_cell *arguments)"
               <> profileLabel "direct" (frameFunctionName function) identity <> ";"
           | (identity, function) <- zip [0 :: Int ..] functions, Set.member (frameFunctionName function) (enteredDirect source direct) ]
  if Map.size identities /= length functions
    then Left (FrameFault Nothing "duplicate frame function identities")
    else foldM (emitFunction callees) (linesInto state{emitFunctionIds = identities} prototypes, Set.empty) (zip [0 ..] functions)

emitFunction :: Callees -> (EmitState, Set Text) -> (Int, FrameFunction)
  -> Either FrameFault (EmitState, Set Text)
emitFunction callees (state, needs) (identity, function)
  | not (targets `Set.isSubsetOf` defined) = Left (FrameFault Nothing "an unknown frame block target")
  | Set.member (frameFunctionName function) (calleeDirect callees) = do
      let header =
            [ "static pudu_cell pudu_run_" <> number <> "(pudu_frame *frame) {"
            , "  (void)frame;" ]
          before = length (emitOutput state)
          opened = line state ("  goto " <> localLabel entry <> ";")
      (emitted, selected) <- foldM (emitBlock Running) (opened, needs) blocks
      -- Unowned slots live in C locals: nothing outside this body reads them,
      -- since unwinding releases only owned slots. Only the slots the body
      -- mentions are declared, and the rewrite touches only its own lines.
      let fresh = length (emitOutput emitted) - before
          added = reverse (take fresh (emitOutput emitted))
          used = [slot | slot <- locals, any (Text.isInfixOf (slotPlace slot)) added]
          body = header <> concatMap localSlot used <> map (localize used) added
          after = emitted{emitOutput = reverse body <> drop fresh (emitOutput emitted)}
      -- The table keeps a body for calls through a value; it forwards here.
      pure (linesInto after
        [ "}"
        , "static pudu_step pudu_body_" <> number <> "(pudu_frame *frame) {"
        , "  pudu_step pudu_done = {.kind = PUDU_RETURN};"
        , "  pudu_done.result = pudu_run_" <> number <> "(frame);"
        , "  return pudu_done;"
        , "}" ], selected)
  | otherwise = do
      let opened = linesInto state
            [ "static pudu_step pudu_body_" <> number <> "(pudu_frame *frame) {"
            , "  switch (frame->pc) {" ]
          resumed = linesInto opened
            (["    case " <> labelText target <> ": goto " <> localLabel target <> ";" | target <- Set.toList resumes]
             <> ["    default: return (pudu_step){.kind = PUDU_INVALID};", "  }"])
      (after, selected) <- foldM (emitBlock Suspending) (resumed, needs) blocks
      pure (line after "}", selected)
  where
    number = textOfInt identity
    entry = frameFunctionEntry function
    blocks = frameFunctionBlocks function
    defined = Set.fromList (map frameBlockLabel blocks)
    targets = Set.fromList (entry : concatMap (successors . frameBlockTerminator) blocks)
    resumes = Set.fromList (entry : concatMap (suspends . frameBlockTerminator) blocks)
    successors ending = case ending of
      FrameJump _ target -> [target]
      FrameBranch _ _ yes no -> [yes, no]
      FrameSwitchVariant _ _ cases fallback -> fallback : map snd cases
      FrameCall _ _ _ _ resume -> [resume]
      FrameCallValue _ _ _ _ resume -> [resume]
      _ -> []
    suspends ending = case ending of
      FrameCall _ name _ _ resume | Set.notMember name (calleeDirect callees) -> [resume]
      FrameCallValue _ _ _ _ resume -> [resume]
      _ -> []
    parameters = Set.fromList (map slotIndex (frameFunctionParameters function))
    locals = [slot | slot <- frameFunctionSlots function, not (ownedType (frameSlotType slot))]
    -- A parameter arrives in its frame slot; any other local starts zeroed.
    localSlot slot
      | Set.member (slotIndex slot) parameters = ["  pudu_cell " <> localName slot <> " = " <> slotPlace slot <> ";"]
      | otherwise = ["  pudu_cell " <> localName slot <> ";", "  memset(&" <> localName slot <> ", 0, sizeof " <> localName slot <> ");"]
    localName slot = "pudu_s" <> slotIndex slot
    slotPlace slot = "frame->slots[" <> slotIndex slot <> "]"
    localize used text = foldl' (\current slot -> Text.replace (slotPlace slot) (localName slot) current) text used
    emitBlock mode current block = do
      let (before, selected) = current
          target = frameBlockLabel block
          labelPrefix = if Set.member target targets then localLabel target <> ": " else ""
          opened = line before ("  " <> labelPrefix <> "{")
      afterInstructions <- foldM instruction (opened, selected) (frameBlockInstructions block)
      (closed, used) <- terminator mode callees function afterInstructions (frameBlockTerminator block)
      pure (line closed "  }", used)

instruction :: (EmitState, Set Text) -> FrameInstruction -> Either FrameFault (EmitState, Set Text)
instruction (state, needs) operation = case operation of
  FrameStore target value -> do
    destination <- slotText target
    (after, expression, selected) <- frameValue state value
    let kind = frameSlotType target
        required = Set.union needs selected
    if kind == CoreTextType
      then pure (line after ("      pudu_text_slot_store(&" <> destination <> ", " <> expression <> ");"),
        Set.insert "text_slot_store" required)
      else do
        let stored
              | ownedType kind =
                  "      { " <> cType kind <> " pudu_next = " <> expression <> "; " <> released kind destination
                    <> " " <> destination <> " = pudu_next; }"
              | otherwise = "      " <> destination <> " = " <> expression <> ";"
        pure (line after stored, required)
  FrameMove target source -> do
    destination <- slotText target
    origin <- slotText source
    let kind = frameSlotType target
    if kind == CoreTextType
      then pure (line state ("      pudu_text_slot_move(&" <> destination <> ", &" <> origin <> ");"),
        Set.insert "text_slot_move" needs)
      else pure (line state ("      { " <> cType kind <> " pudu_moved = " <> origin <> "; " <> origin <> " = NULL; "
                    <> released kind destination <> " " <> destination <> " = pudu_moved; }"), needs)
  FramePrintLiteral _ text -> printed "print_str" (cString text <> ", " <> textOfInt (cStringBytes text))
  FramePrintUnit _ -> printed "print_str" "\"()\", 2"
  FramePrintSlot at slot -> do
    value <- slotText slot
    case frameSlotType slot of
      CoreIntegerType _ -> printed (integerHelper (frameSlotType slot) "print_int") value
      CoreFloatType _ -> printed "print_float" value
      CoreBoolType -> printed "print_bool" value
      CoreTextType -> printed "print_text" value
      CoreCharType -> printed "print_char" value
      kind | isAggregate kind -> Right
        ( line state ("      { pudu_text pudu_shown = " <> aggregateHelper "show" kind <> "(" <> value
            <> "); pudu_print_text(pudu_shown); pudu_text_release(pudu_shown); }")
        , Set.union needs (Set.fromList [aggregateNeed "show" kind, "print_text"]) )
      CoreUnitType -> printed "print_str" "\"()\", 2"
      _ -> Left (FrameFault (Just at) "an unrepresented frame print value")
  where
    printed helper arguments = Right
      (line state ("      (void)pudu_" <> helper <> "(" <> arguments <> ");"), Set.insert helper needs)

terminator :: Mode -> Callees -> FrameFunction -> (EmitState, Set Text) -> FrameTerminator
  -> Either FrameFault (EmitState, Set Text)
terminator mode callees function (state, needs) ending = case ending of
  FrameJump _ target -> pure (jump state target, needs)
  FrameBranch _ slot yes no -> do
    predicate <- slotText slot
    pure (line state ("      if (" <> predicate <> ") goto " <> localLabel yes <> "; else goto " <> localLabel no <> ";"), needs)
  FrameSwitchVariant at subject cases fallback
    | not (isAggregate (frameSlotType subject)) -> Left (FrameFault (Just at) "a variant switch without an aggregate subject")
    | Set.size (Set.fromList (map fst cases)) /= length cases || any ((< 0) . fst) cases ->
        Left (FrameFault (Just at) "an invalid variant switch table")
    | otherwise -> do
        held <- slotText subject
        pure (linesInto state
          (["      switch (" <> held <> "->fields[0].scalar) {"]
            <> ["        case " <> textOfInt tag <> ": goto " <> localLabel target <> ";" | (tag, target) <- cases]
            <> ["        default: goto " <> localLabel fallback <> ";", "      }"]), needs)
  FrameCall at name arguments destination resume -> case (Map.lookup name (calleeIds callees), Map.lookup name (calleeFunctions callees)) of
    (Just callee, Just definition) | Set.member name (calleeDirect callees) -> do
      copies <- traverse moveArgument (zip [0 ..] arguments)
      stored <- case destination of
        Nothing -> Right ["        " <> orVoid (released (frameFunctionResult definition) ("pudu_answer." <> memberOf (frameFunctionResult definition)))]
        Just slot -> do
          place <- slotText slot
          -- The answer arrives retained; the destination's old value goes.
          pure [ "        " <> released (frameFunctionResult definition) place
               , "        frame->slots[" <> slotIndex slot <> "] = pudu_answer;" ]
      let (afterSite, index) = callDepthSite state at
          call = linesInto (linesInto afterSite copies)
            ([ "      if (pudu_frame_depth > " <> textOfInt callDepthLimit <> ") pudu_fail(&pudu_sites[" <> textOfInt index <> "]);"
             , "      pudu_frame_depth += 1;"
             , "      {"
             , "        pudu_transfer = " <> transferMask arguments <> ";"
             , "        pudu_cell pudu_answer = pudu_direct_" <> textOfInt callee <> "(frame->arguments);" ]
             <> stored
             <> [ "      }", "      pudu_frame_depth -= 1;" ])
      pure (jump call resume, Set.union needs (Set.fromList ["site", "colored", "fail"]))
    (Just _, _) | Running <- mode -> Left (FrameFault (Just at) "a direct body calling a function on the heap path")
    (Nothing, _) -> Left (FrameFault (Just at) "an unknown generated frame callee")
    (Just callee, _) -> do
      copies <- traverse moveArgument (zip [0 ..] arguments)
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
            <> ", .transfer = " <> transferMask arguments
            <> foldMap id target <> ", .call_site = &pudu_sites[" <> textOfInt index <> "]};"
      pure (line afterResume result, Set.union needs (Set.fromList ["site", "colored", "fail"]))
  -- The dispatcher passes the closure only to a lifted body.
  FrameCallValue at _ _ _ _ | Running <- mode ->
    Left (FrameFault (Just at) "a direct body calling through a function value")
  FrameCallValue at closure arguments destination resume -> do
    callee <- slotText closure
    copies <- traverse copyArgument (zip [0 ..] (closure : arguments))
    target <- case destination of
      Nothing -> Right []
      Just slot -> do
        _ <- slotText slot
        pure [", .has_destination = 1, .destination = " <> slotIndex slot]
    let (afterSite, index) = callDepthSite state at
        afterCopies = linesInto afterSite copies
        afterResume = line afterCopies ("      frame->pc = " <> labelText resume <> ";")
        result = "      return (pudu_step){.kind = PUDU_CALL, .closure_call = 1, .function = (size_t)" <> callee <> "->fields[0].scalar"
          <> ", .argument_count = " <> textOfInt (1 + length arguments)
          <> foldMap id target <> ", .call_site = &pudu_sites[" <> textOfInt index <> "]};"
    pure (line afterResume result, Set.union needs (Set.fromList ["site", "colored", "fail"]))
  FrameReturn _ payload -> do
    result <- case frameFunctionResult function of
      CoreUnitType -> Right Nothing
      CoreNeverType -> Right Nothing
      resultType -> case cellMember resultType of
        Nothing -> Left (FrameFault Nothing "an unrepresented frame return type")
        Just member -> do
          expression <- maybe (Right (zeroValue resultType)) slotText payload
          -- The frame releases its slots after this, so the result keeps its own reference.
          let (returned, wanted) = retained resultType expression
          pure (Just ("." <> member <> " = " <> returned, wanted))
    let (field, extra) = maybe ("", []) id result
        returned = case (mode, result) of
          (Running, Just (value, _)) -> "      return (pudu_cell){" <> value <> "};"
          (Running, Nothing) -> "      return (pudu_cell){0};"
          (Suspending, _) -> "      return (pudu_step){.kind = PUDU_RETURN" <> (if field == "" then "" else ", .result = {" <> field <> "}") <> "};"
    pure (line state returned, Set.union needs (Set.fromList extra))
  FrameFailText at code help message computed -> do
    text <- slotText message
    helpText <- traverse slotText computed
    let (after, index) = textFailureSite state at code help
        call = case helpText of
          Nothing -> "      pudu_fail_text(&pudu_sites[" <> textOfInt index <> "], " <> text <> ");"
          Just extra -> "      pudu_fail_text_help(&pudu_sites[" <> textOfInt index <> "], " <> text <> ", " <> extra <> ");"
    pure (linesInto after
      [ call
      , invalid ]
      , Set.union needs (Set.fromList ["site", "colored", "fail", maybe "fail_text" (const "fail_text_help") helpText]))
  FrameFailCaller _ code help message -> do
    text <- slotText message
    pure (linesInto state
      [ "      pudu_fail_text_caller(frame->call_site, " <> cString code <> ", " <> maybe "NULL" cString help <> ", " <> text <> ");"
      , invalid ]
      , Set.union needs (Set.fromList ["site", "colored", "fail", "fail_text", "fail_text_caller"]))
  FrameOperatorFailure at message ->
    let (after, index) = operatorFailureSite state at message
     in pure (linesInto after
          [ "      pudu_fail(&pudu_sites[" <> textOfInt index <> "]);"
          , invalid ]
        , Set.union needs (Set.fromList ["site", "colored", "fail"]))
  where
    jump current target = line current ("      goto " <> localLabel target <> ";")
    -- A failure helper does not return; a direct body has no step to report.
    invalid = case mode of
      Suspending -> "      return (pudu_step){.kind = PUDU_INVALID};"
      Running -> "      abort();"
    orVoid statement = if statement == "" then "(void)pudu_answer;" else statement
    memberOf kind = maybe "integer" id (cellMember kind)
    copyArgument (index, slot) = do
      _ <- slotText slot
      pure ("      frame->arguments[" <> textOfInt index <> "] = frame->slots[" <> slotIndex slot <> "];")
    -- A moved argument leaves the caller; its slot no longer holds the reference.
    moveArgument (index, slot) = do
      copied <- copyArgument (index, slot)
      pure (if transferred index slot then copied <> " frame->slots[" <> slotIndex slot <> "].box = NULL;" else copied)

{-| Moved boxed arguments, by position, as the mask callee entry reads. -}
transferMask :: [FrameSlot] -> Text
transferMask arguments =
  textOfInt (sum [2 ^ index | (index, slot) <- zip [0 :: Int ..] arguments, transferred index slot] :: Int) <> "u"

{-| The mask names the first 32 positions; a later moved argument is copied
    and retained as any other. -}
transferred :: Int -> FrameSlot -> Bool
transferred index slot = index < 32 && frameSlotName slot == takenSlotName && cellMember (frameSlotType slot) == Just "box"

slotIndex :: FrameSlot -> Text
slotIndex slot = case frameSlotId slot of FrameSlotId identity -> textOfInt identity

labelText :: FrameLabel -> Text
labelText (FrameLabel identity) = textOfInt identity

localLabel :: FrameLabel -> Text
localLabel target = "pudu_block_" <> labelText target

linesInto :: EmitState -> [Text] -> EmitState
linesInto = foldl' line
