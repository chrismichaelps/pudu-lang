{-| @Pudu.Backend.Emit.Frame.Direct — the frame functions whose call depth the
    call graph bounds. They run in a frame on the C stack and are called as
    plain C functions; every other function keeps the heap path. -}
module Pudu.Backend.Emit.Frame.Direct
  ( directFunctions, enteredDirect, argumentCount, frameCells
  , directCellLimit, directStackBudget, directFrameOverhead
  ) where

import Data.Graph (SCC (..), stronglyConnComp)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Core.Frame (FrameBlock (..), FrameFunction (..), FrameModule (..), FrameTerminator (..))

{-| The most cells a direct frame may hold. -}
directCellLimit :: Int
directCellLimit = 512

{-| Host stack, in bytes, the deepest chain of direct frames may use. -}
directStackBudget :: Int
directStackBudget = 65536

{-| Bytes a direct frame takes beyond its cells: the frame header and the
    C function's own spill. -}
directFrameOverhead :: Int
directFrameOverhead = 128

cellBytes :: Int
cellBytes = 16

{-| The names of the direct functions of a module. Components are visited
    callees first, so each decision reads only decisions already made. -}
directFunctions :: FrameModule -> Set Text
directFunctions source = Map.keysSet (foldl' decide Map.empty components)
 where
  functions = frameModuleFunctions source
  components = stronglyConnComp [(function, frameFunctionName function, callees function) | function <- functions]
  decide decided (AcyclicSCC function)
    | Just depth <- admitted decided function = Map.insert (frameFunctionName function) depth decided
  decide decided _ = decided
  -- The stack a function's chain of direct frames takes, when it is direct.
  admitted decided function = do
    let name = frameFunctionName function
    guardThat (name /= frameModuleEntry source)
    guardThat (not (Map.member name (frameModuleClosures source)))
    guardThat (not (callsValue function))
    guardThat (frameCells function <= directCellLimit)
    below <- traverse (`Map.lookup` decided) (callees function)
    let depth = frameCells function * cellBytes + directFrameOverhead + maximum (0 : below)
    guardThat (depth <= directStackBudget)
    pure depth
  guardThat condition = if condition then Just () else Nothing

{-| The direct functions something enters by name: a call in any body, or an
    export. Only these need a stack-frame entry. -}
enteredDirect :: FrameModule -> Set Text -> Set Text
enteredDirect source direct =
  Set.intersection direct (Set.fromList (concatMap callees (frameModuleFunctions source) <> frameModuleExports source))

callees :: FrameFunction -> [Text]
callees function = [name | block <- frameFunctionBlocks function, FrameCall _ name _ _ _ <- [frameBlockTerminator block]]

callsValue :: FrameFunction -> Bool
callsValue function = or [True | block <- frameFunctionBlocks function, FrameCallValue {} <- [frameBlockTerminator block]]

{-| The widest call's argument count: the size of a frame's argument scratch. -}
argumentCount :: FrameFunction -> Int
argumentCount function = maximum (0 :
  [ length arguments
  | block <- frameFunctionBlocks function
  , arguments <- case frameBlockTerminator block of
      FrameCall _ _ given _ _ -> [given]
      FrameCallValue _ closure given _ _ -> [closure : given]
      _ -> [] ])

{-| A frame's cells: its slots and its argument scratch, at least one. -}
frameCells :: FrameFunction -> Int
frameCells function = max 1 (length (frameFunctionSlots function) + argumentCount function)
