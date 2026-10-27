{-| @Pudu.Backend.Emit — checked frame IR to a deterministic C11 executable. -}
module Pudu.Backend.Emit (emitProgram) where

import Data.Text (Text)
import Pudu.Backend.Emit.Frame (emitFrameProgram)
import Pudu.Core.Frame (FrameFault, FrameModule)
import Pudu.Source (Source)

emitProgram :: Text -> [Source] -> FrameModule -> Either FrameFault Text
emitProgram = emitFrameProgram
