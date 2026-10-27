{-| @Pudu.Compiler.Frame.State — block construction, typed slots and resolved loop targets. -}
module Pudu.Compiler.Frame.State
  ( Build, BuildState (..), Flow (..), LoopTarget (..), runBuild, initialState
  , getState, modifyState, fault, freshSlot, bindLocal, readLocal, emit, finish
  , freshLabel, begin, isOpen, withLoop, findLoop, saveValue, storeValue, moveValue
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Core (CoreFunction, CoreLayout, CoreLocal (..), CoreLoopId, CoreType (..))
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameInstruction (..), FrameLabel (..)
  , FrameSlot (..), FrameSlotId (..), FrameTerminator, FrameValue (..), FrameValueShape (..) )
import Pudu.Source (Span)

data Flow = Stopped | Completed !(Maybe FrameSlot) deriving stock (Eq, Show)

data LoopTarget = LoopTarget
  { targetContinue :: !FrameLabel
  , targetBreak :: !FrameLabel
  , targetResult :: !(Maybe FrameSlot)
  }

data BuildState = BuildState
  { buildNextSlot :: !Int
  , buildSlots :: !(Map FrameSlotId FrameSlot)
  , buildLocals :: !(Map Int FrameSlot)
  , buildNextLabel :: !Int
  , buildCurrent :: !(Maybe (FrameLabel, [FrameInstruction]))
  , buildBlocks :: !(Map FrameLabel FrameBlock)
  , buildLoops :: !(Map CoreLoopId LoopTarget)
  , buildFunctions :: !(Map Text CoreFunction)
  , buildLayouts :: !(Map CoreType CoreLayout)
  }

newtype Build a = Build { runBuild :: BuildState -> Either FrameFault (a, BuildState) }

instance Functor Build where
  fmap f action = Build $ \state -> do
    (value, after) <- runBuild action state
    pure (f value, after)

instance Applicative Build where
  pure value = Build $ \state -> Right (value, state)
  functions <*> values = do
    f <- functions
    value <- values
    pure (f value)

instance Monad Build where
  action >>= next = Build $ \state -> do
    (value, after) <- runBuild action state
    runBuild (next value) after

initialState :: Map Text CoreFunction -> Map CoreType CoreLayout -> BuildState
initialState functions layouts = BuildState 0 Map.empty Map.empty 1
  (Just (FrameLabel 0, [])) Map.empty Map.empty functions layouts

getState :: Build BuildState
getState = Build $ \state -> Right (state, state)

modifyState :: (BuildState -> BuildState) -> Build ()
modifyState f = Build $ \state -> Right ((), f state)

fault :: Maybe Span -> Text -> Build a
fault at message = Build $ \_ -> Left (FrameFault at message)

freshSlot :: Span -> Text -> CoreType -> Build FrameSlot
freshSlot at name kind = case kind of
  CoreNeverType -> fault (Just at) "a payload slot for Never"
  _ -> do
    state <- getState
    let identity = FrameSlotId (buildNextSlot state)
        slot = FrameSlot identity name kind at
    modifyState $ \current -> current
      { buildNextSlot = buildNextSlot current + 1
      , buildSlots = Map.insert identity slot (buildSlots current)
      }
    pure slot

bindLocal :: Span -> CoreLocal -> Build FrameSlot
bindLocal at local = do
  state <- getState
  if Map.member (coreLocalId local) (buildLocals state)
    then fault (Just at) "a duplicate Core local identity"
    else do
      slot <- freshSlot at (coreLocalName local) (coreLocalType local)
      modifyState $ \current -> current{buildLocals = Map.insert (coreLocalId local) slot (buildLocals current)}
      pure slot

readLocal :: Span -> CoreLocal -> Build FrameSlot
readLocal at local = do
  state <- getState
  case Map.lookup (coreLocalId local) (buildLocals state) of
    Just slot | frameSlotType slot == coreLocalType local -> pure slot
    _ -> fault (Just at) "a Core local without matching frame storage"

emit :: FrameInstruction -> Build ()
emit instruction = do
  state <- getState
  case buildCurrent state of
    Nothing -> fault Nothing "an instruction after a block terminator"
    Just (label, instructions) -> modifyState $ \current -> current
      {buildCurrent = Just (label, instruction : instructions)}

finish :: FrameTerminator -> Build ()
finish terminator = do
  state <- getState
  case buildCurrent state of
    Nothing -> fault Nothing "a second terminator for one block"
    Just (label, instructions) -> modifyState $ \current -> current
      { buildCurrent = Nothing
      , buildBlocks = Map.insert label (FrameBlock label (reverse instructions) terminator) (buildBlocks current)
      }

freshLabel :: Build FrameLabel
freshLabel = do
  state <- getState
  modifyState $ \current -> current{buildNextLabel = buildNextLabel current + 1}
  pure (FrameLabel (buildNextLabel state))

begin :: FrameLabel -> Build ()
begin label = do
  state <- getState
  case buildCurrent state of
    Just _ -> fault Nothing "opening a block before closing its predecessor"
    Nothing | Map.member label (buildBlocks state) -> fault Nothing "a duplicate frame block label"
    Nothing -> modifyState $ \current -> current{buildCurrent = Just (label, [])}

isOpen :: Build Bool
isOpen = do
  state <- getState
  pure $ case buildCurrent state of Just _ -> True; Nothing -> False

withLoop :: CoreLoopId -> LoopTarget -> Build a -> Build a
withLoop identity target action = do
  before <- buildLoops <$> getState
  modifyState $ \state -> state{buildLoops = Map.insert identity target before}
  value <- action
  modifyState $ \state -> state{buildLoops = before}
  pure value

findLoop :: Span -> CoreLoopId -> Build LoopTarget
findLoop at identity = do
  state <- getState
  case Map.lookup identity (buildLoops state) of
    Just target -> pure target
    Nothing -> fault (Just at) "a transfer without its resolved loop destination"

saveValue :: FrameValue -> Build FrameSlot
saveValue value = do
  slot <- freshSlot (frameValueSpan value) "$value" (frameValueType value)
  emit (FrameStore slot value)
  pure slot

{-| Store a value the source slot holds and nothing reads again: an owned
    value moves rather than gaining a second reference, so a buffer built in
    a loop stays uniquely held. -}
moveValue :: Span -> FrameSlot -> Maybe FrameSlot -> Build ()
moveValue at target payload = case payload of
  Just source
    | frameSlotType source == frameSlotType target, ownedKind (frameSlotType target) ->
        emit (FrameMove target source)
  _ -> storeValue at target payload
 where
  ownedKind kind = case kind of
    CoreTextType -> True
    CoreTupleType _ -> True
    CoreRecordType _ _ -> True
    CoreSumType _ _ -> True
    CoreFunctionType _ _ -> True
    CoreArrayType _ -> True
    CoreMapType _ _ -> True
    CoreSetType _ -> True
    CoreRangeType -> True
    _ -> False

storeValue :: Span -> FrameSlot -> Maybe FrameSlot -> Build ()
storeValue at target payload = case payload of
  Just source | frameSlotType source == frameSlotType target ->
    emit (FrameStore target (FrameValue at (frameSlotType target) (FrameRead source)))
  Nothing | frameSlotType target == CoreUnitType ->
    emit (FrameStore target (FrameValue at CoreUnitType FrameUnitLiteral))
  _ -> fault (Just at) "a frame destination with an incompatible value"
