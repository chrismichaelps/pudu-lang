{-| @Repl.Options — what the caller decides before the loop starts, and what the
    reader turns on once it has.

    These are shared by the loop and by the commands that answer on screen, so
    they live apart from both rather than one importing the other. -}
module Pudu.Repl.Options
  ( ReplOptions (..)
  , ReplSettings (..)
  , defaultReplOptions
  , defaultReplSettings
  ) where

import Pudu.Diagnostic.Render (RenderStyle (PlainStyle))

{-| @Repl.Options.Options — everything the caller decides before the loop starts -}
data ReplOptions = ReplOptions
  { replStyle :: !RenderStyle
  , replInitialLoad :: !(Maybe FilePath)
  }
  deriving stock (Eq, Show)

defaultReplOptions :: ReplOptions
defaultReplOptions = ReplOptions{replStyle = PlainStyle, replInitialLoad = Nothing}

{-| @Repl.Options.Settings — what the reader turned on for this session.

    Settings are session state, not options the entry point chose, so they live
    beside the session rather than in the options record. -}
data ReplSettings = ReplSettings
  { settingShowTypes :: !Bool
  , settingShowTiming :: !Bool
  }
  deriving stock (Eq, Show)

defaultReplSettings :: ReplSettings
defaultReplSettings = ReplSettings{settingShowTypes = False, settingShowTiming = False}
