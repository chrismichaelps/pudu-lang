{-| @Backend.Emit.Frame.Slots — physical storage for nonoverlapping frame values. -}
module Pudu.Backend.Emit.Frame.Slots (compactFrameSlots) where

import Data.Functor.Const (Const (..))
import Data.Functor.Identity (Identity (..))
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Pudu.Backend.Emit.Aggregate (ownedType)
import Pudu.Backend.Emit.Frame.References (instructionSlots, terminatorSlots)
import Pudu.Core (CoreType)
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFunction (..), FrameInstruction (..), FrameLabel
  , FrameModule (..), FrameSlot (..), FrameSlotId (..), FrameValue (..), FrameValueShape (..) )

data Lifetime = Lifetime
  { first :: !Int
  , lastUse :: !Int
  , homeBlock :: !FrameLabel
  , beginsStored :: !Bool
  , oneBlock :: !Bool
  , endsEmpty :: !Bool
  }

data Pool = Pool
  { active :: !(Map (Int, FrameSlotId) ())
  , available :: !(Set FrameSlotId)
  }

data Allocation = Allocation
  { nextId :: !Int
  , pools :: !(Map CoreType Pool)
  , physicalIds :: !(Map FrameSlotId FrameSlotId)
  }

compactFrameSlots :: FrameModule -> FrameModule
compactFrameSlots source = source{frameModuleFunctions = map compactFunction (frameModuleFunctions source)}

compactFunction :: FrameFunction -> FrameFunction
compactFunction function
  | not canonical = function
  | nextId allocated == length slots = function
  | otherwise = function
      { frameFunctionParameters = map rename (frameFunctionParameters function)
      , frameFunctionSlots = Map.elems (Map.fromList [(frameSlotId new, new) | slot <- slots, let new = rename slot])
      , frameFunctionBlocks = map rewrite blocks
      , frameFunctionDrops = [(rename slot, glue) | (slot, glue) <- frameFunctionDrops function]
      }
  where
    slots = frameFunctionSlots function
    blocks = frameFunctionBlocks function
    parameters = frameFunctionParameters function
    located = concatMap (\block -> map (frameBlockLabel block,) (frameBlockInstructions block)) blocks
    terminators = concatMap (getConst . terminatorSlots (\slot -> Const [slot]) . frameBlockTerminator) blocks
    -- A slot a stop may drop keeps its own place for the whole frame.
    fixed = Set.fromList (map frameSlotId (parameters <> terminators <> concatMap foreignSlots located <> map fst (frameFunctionDrops function)))
    allReferences = parameters <> terminators <> concatMap (references . snd) located
    types = Map.fromList [(frameSlotId slot, frameSlotType slot) | slot <- slots]
    ordinal (FrameSlotId number) = number
    canonical = map (ordinal . frameSlotId) slots == [0 .. length slots - 1]
      && all (\slot -> Map.lookup (frameSlotId slot) types == Just (frameSlotType slot)) allReferences
    lifetimes = foldl' observe Map.empty (zip [0 ..] located)
    lifetime slot = Map.lookup (frameSlotId slot) lifetimes
    reusable slot interval = Set.notMember (frameSlotId slot) fixed && oneBlock interval
      && beginsStored interval && (not (ownedType (frameSlotType slot)) || endsEmpty interval)
    candidates = [(slot, interval) | slot <- slots, Just interval <- [lifetime slot], reusable slot interval]
    candidateIds = Set.fromList (map (frameSlotId . fst) candidates)
    pinned = filter (\slot -> Set.notMember (frameSlotId slot) candidateIds) slots
    start = Allocation (length pinned) Map.empty (Map.fromList (zip (map frameSlotId pinned) (map FrameSlotId [0 ..])))
    allocated = foldl' assign start (sortOn (first . snd) candidates)
    rename slot = slot{frameSlotId = Map.findWithDefault (frameSlotId slot) (frameSlotId slot) (physicalIds allocated)}
    rewrite block = block
      { frameBlockInstructions = map (runIdentity . instructionSlots (Identity . rename)) (frameBlockInstructions block)
      , frameBlockTerminator = runIdentity (terminatorSlots (Identity . rename) (frameBlockTerminator block))
      }

references :: FrameInstruction -> [FrameSlot]
references = getConst . instructionSlots (\slot -> Const [slot])

foreignSlots :: (FrameLabel, FrameInstruction) -> [FrameSlot]
foreignSlots (_, FrameStore _ FrameValue{frameValueShape = FrameForeign _ arguments}) = arguments
foreignSlots _ = []

observe :: Map FrameSlotId Lifetime -> (Int, (FrameLabel, FrameInstruction)) -> Map FrameSlotId Lifetime
observe seen (point, (block, operation)) = foldl' record seen (Map.keys counts)
  where
    counts = Map.fromListWith (+) [(frameSlotId slot, 1 :: Int) | slot <- references operation]
    starts identity = case operation of
      FrameStore target _ -> frameSlotId target == identity && Map.lookup identity counts == Just 1
      _ -> False
    emptied identity = case operation of
      FrameMove target source -> frameSlotId source == identity && frameSlotId target /= identity
      _ -> False
    record state identity = Map.alter (Just . update) identity state
      where
        update Nothing = Lifetime point point block (starts identity) True (emptied identity)
        update (Just interval) = interval
          { lastUse = point
          , oneBlock = oneBlock interval && homeBlock interval == block
          , endsEmpty = emptied identity
          }

assign :: Allocation -> (FrameSlot, Lifetime) -> Allocation
assign state (slot, interval) =
  let kind = frameSlotType slot
      old = Map.findWithDefault (Pool Map.empty Set.empty) kind (pools state)
      (expired, remaining) = Map.spanAntitone ((< first interval) . fst) (active old)
      ready = Set.union (available old) (Set.fromList (map snd (Map.keys expired)))
      (chosen, free, next) = case Set.minView ready of
        Just (identity, rest) -> (identity, rest, nextId state)
        Nothing -> (FrameSlotId (nextId state), Set.empty, nextId state + 1)
      pool = Pool (Map.insert (lastUse interval, chosen) () remaining) free
  in Allocation next (Map.insert kind pool (pools state))
       (Map.insert (frameSlotId slot) chosen (physicalIds state))
