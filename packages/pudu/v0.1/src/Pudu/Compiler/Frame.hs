{-| @Pudu.Compiler.Frame — structured Core to resumable typed blocks. -}
module Pudu.Compiler.Frame (lowerFrames) where

import qualified Data.Map.Strict as Map
import Pudu.Compiler.Frame.Body (lowerBlock)
import Pudu.Compiler.Frame.State
  ( Build, BuildState (..), Flow (..), bindLocal, finish, initialState, runBuild )
import Pudu.Core
  ( CoreFunction (..), CoreModule (..), CoreParameter (..), CoreType (..) )
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameFunction (..), FrameLabel (..), FrameModule (..)
  , FrameSlot, FrameTerminator (..) )

lowerFrames :: CoreModule -> Either FrameFault FrameModule
lowerFrames source = do
  let functions = coreModuleFunctions source
      table = Map.fromList [(coreFunctionName function, function) | function <- functions]
  if Map.size table /= length functions
    then Left (FrameFault Nothing "duplicate Core function identities")
    else if not (Map.member (coreModuleEntry source) table)
      then Left (FrameFault Nothing "missing Core entry function")
      else do
        lowered <- traverse (lowerFunction table) functions
        pure (FrameModule (coreModuleName source) (coreModuleEntry source) lowered (coreModuleLayouts source) (coreModuleClosures source))
  where
    lowerFunction table function = do
      (parameters, state) <- runBuild (body function) (initialState table (coreModuleLayouts source))
      case buildCurrent state of
        Just _ -> Left (FrameFault Nothing "an unfinished frame block")
        Nothing -> do
          let blocks = buildBlocks state
              targets terminator = case terminator of
                FrameJump _ target -> [target]
                FrameBranch _ _ yes no -> [yes, no]
                FrameCall _ _ _ _ resume -> [resume]
                FrameCallValue _ _ _ _ resume -> [resume]
                FrameReturn _ _ -> []
                FrameOperatorFailure _ _ -> []
                FrameFailText{} -> []
                FrameFailCaller{} -> []
              referenced = FrameLabel 0 : concatMap (targets . frameBlockTerminator) (Map.elems blocks)
          if all (`Map.member` blocks) referenced
            then Right FrameFunction
              { frameFunctionName = coreFunctionName function
              , frameFunctionParameters = parameters
              , frameFunctionResult = coreFunctionResult function
              , frameFunctionSlots = Map.elems (buildSlots state)
              , frameFunctionEntry = FrameLabel 0
              , frameFunctionBlocks = Map.elems blocks
              }
            else Left (FrameFault Nothing "a frame transfer without a closed destination")

body :: CoreFunction -> Build [FrameSlot]
body function = do
  parameters <- traverse bindParameter (coreFunctionParameters function)
  flow <- lowerBlock (coreFunctionBody function)
  case flow of
    Stopped -> pure ()
    Completed payload -> finish (FrameReturn Nothing
      (if coreFunctionResult function == CoreUnitType then Nothing else payload))
  pure parameters
  where
    bindParameter parameter = bindLocal (coreParameterSpan parameter) (coreParameterLocal parameter)
