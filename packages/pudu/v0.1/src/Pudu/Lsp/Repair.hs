{-| @Program.Lsp.Repair — answers about a program while it is half written.

    A program being typed rarely compiles: `total.` does not parse, and a
    call whose parenthesis is still open does not either. A program that does
    not parse has no names and no types, so the questions an editor asks most
    — what may follow this dot, what does this call expect — would be answered
    with nothing exactly when they are asked.

    The answer is read instead from a nearby text that compiles further: the
    same program with the unfinished piece left out. Each candidate is the
    written text with one range removed, so every offset before that range is
    the same in both, and a name or type found there is the one the reader is
    looking at. Nothing repaired is ever stored or reported; diagnostics always
    describe the text as written. -}
module Pudu.Lsp.Repair
  ( Repair (..)
  , lineBounds
  , mostComplete
  , withoutRange
  ) where

import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Documents (Analysis (..))

{-| One candidate: the text to compile, and the offset up to which it agrees
    with the text as written. -}
data Repair = Repair
  { repairText :: !Text
  , repairAgreesUntil :: !Int
  }

{-| The written text with `[start, end)` left out. -}
withoutRange :: Text -> Int -> Int -> Repair
withoutRange content start end =
  Repair (Text.take start content <> Text.drop end content) start

{-| The offsets where the line holding `offset` starts and ends, its line break
    excluded. -}
lineBounds :: Text -> Int -> (Int, Int)
lineBounds content offset =
  let before = Text.take offset content
      after = Text.drop offset content
   in ( offset - Text.length (Text.takeWhileEnd (/= '\n') before)
      , offset + Text.length (Text.takeWhile (/= '\n') after)
      )

{-| The analysis of the first candidate that type-checks, or failing that of
    the first that at least resolved its names, with the offset it agrees
    until. `written` is kept when no candidate compiles further than it.

    Candidates are compiled one at a time and only until one type-checks, so the
    usual case — the first repair works — costs one extra compile. -}
mostComplete :: (Text -> IO Analysis) -> Analysis -> Int -> [Repair] -> IO (Analysis, Int)
mostComplete analyse written offset = go Nothing
 where
  go resolvedOnly candidates = case candidates of
    [] -> pure (maybe (written, offset) id resolvedOnly)
    Repair text agrees : rest -> do
      value <- analyse text
      if isJust (analysisTypes value)
        then pure (value, agrees)
        else
          go
            (case resolvedOnly of
               Nothing | isJust (analysisResolution value) -> Just (value, agrees)
               kept -> kept)
            rest
