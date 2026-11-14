{-| @Pudu.Backend.Emit — checked frame IR to a deterministic C11 translation
    unit, entered as an executable or by a host application. -}
module Pudu.Backend.Emit (EmittedUnit (..), EntryForm (..), emitProgram, emitUnit) where

import Data.Text (Text)
import Pudu.Backend.Emit.Entry (EmittedUnit (..), EntryForm (..))
import Pudu.Backend.Emit.Frame (emitFrameProgram, emitFrameUnit)
import Pudu.Core.Frame (FrameFault, FrameModule)
import Pudu.Source (Source)

emitProgram :: Text -> [Source] -> FrameModule -> Either FrameFault Text
emitProgram = emitFrameProgram

emitUnit :: EntryForm -> Text -> [Source] -> FrameModule -> Either FrameFault EmittedUnit
emitUnit = emitFrameUnit
