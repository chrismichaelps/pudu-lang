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
  , closedPrefix
  , closedPrefixWith
  , elsewhereBlanked
  , lineBounds
  , mostComplete
  , withoutRange
  ) where

import qualified Data.Set as Set
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Severity (Error), diagnosticSeverity, diagnosticSpan)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Module (..))
import Pudu.Frontend.Token (SymbolKind (..), Token (..), TokenKind (..))
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Source (spanEnd, spanStart, unOffset)

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

{-| The written text up to `offset`, with every bracket still open there
    closed after it.

    An editor is usually typing inside a function whose closing brace it has
    not written yet, or in a `match` whose arms are unfinished. Leaving out a
    word or a line cannot make that text parse; ending it where the cursor is
    and closing what is open does, and everything the reader wrote before the
    cursor — the bindings, the subject of the match, the receiver — keeps its
    offsets. What follows the cursor is left out, which the answer does not
    need. -}
closedPrefix :: [Token] -> Text -> Int -> Repair
closedPrefix = closedPrefixWith ""

{-| `closedPrefix` with `filler` written at the cursor before the brackets
    close: what makes an unfinished construct whole, such as the rest of a
    match arm after `case `. -}
closedPrefixWith :: Text -> [Token] -> Text -> Int -> Repair
closedPrefixWith filler tokens content offset =
  Repair (Text.take offset content <> filler <> Text.concat (map closing (open [] before))) offset
 where
  before = [tokenKind token | token <- tokens, unOffset (spanStart (tokenSpan token)) < offset]
  open stack kinds = case kinds of
    [] -> stack
    Symbol SymLeftParen : rest -> open (SymRightParen : stack) rest
    Symbol SymLeftBracket : rest -> open (SymRightBracket : stack) rest
    Symbol SymLeftBrace : rest -> open (SymRightBrace : stack) rest
    Symbol closer : rest
      | closer `elem` [SymRightParen, SymRightBracket, SymRightBrace] -> open (drop 1 stack) rest
    _ : rest -> open stack rest
  closing symbol = case symbol of
    SymRightParen -> "\n)"
    SymRightBracket -> "\n]"
    _ -> "\n}"

{-| The written text with every top-level declaration that holds an error —
    other than the one holding `offset` — replaced by spaces, line breaks kept.

    A syntax error in one function makes the whole file unparseable, and no
    repair near the cursor reaches it. Blanking the broken declarations leaves
    every offset where it was, so the answer read from the repaired text is at
    exactly the reader's positions. Nothing when no other declaration is
    broken, or the file has no recovered tree to find declarations in. -}
elsewhereBlanked :: Analysis -> Int -> Maybe Text
elsewhereBlanked written offset = case analysisModule written of
  Nothing -> Nothing
  Just recovered -> case filter broken (moduleDeclarations recovered) of
    [] -> Nothing
    blanked -> Just (foldl blank (analysisText written) [range (locatedSpan declaration) | declaration <- blanked])
 where
  errors = [unOffset (spanStart (diagnosticSpan d)) | d <- analysisDiagnostics written, diagnosticSeverity d == Error]
  range spanValue = (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))
  broken (Located spanValue _) =
    let (from, to) = range spanValue
     in not (from <= offset && offset <= to) && any (\at -> from <= at && at < to) errors
  blank content (from, to) =
    Text.take from content
      <> Text.map (\scalar -> if scalar == '\n' then '\n' else ' ') (Text.take (to - from) (Text.drop from content))
      <> Text.drop to content

{-| The offsets where the line holding `offset` starts and ends, its line break
    excluded. -}
lineBounds :: Text -> Int -> (Int, Int)
lineBounds content offset =
  let before = Text.take offset content
      after = Text.drop offset content
   in ( offset - Text.length (Text.takeWhileEnd (/= '\n') before)
      , offset + Text.length (Text.takeWhile (/= '\n') after)
      )

{-| The analysis of the first candidate that answers what was asked —
    `answers` says whether it does, such as whether the receiver before a dot
    was typed — or failing that of the first that at least resolved its names,
    with the offset it agrees until. `written` is kept when no candidate
    compiles further than it.

    Candidates are compiled one at a time and only until one answers, so the
    usual case — the first repair works — costs one extra compile, and a
    candidate whose text an earlier one already had is not compiled again. A
    candidate that type-checks without answering is not taken: some types are
    not the type the request needs. -}
mostComplete :: (Text -> IO Analysis) -> (Analysis -> Bool) -> Analysis -> Int -> [Repair] -> IO (Analysis, Int)
mostComplete analyse answers written offset = go Set.empty Nothing
 where
  go seen resolvedOnly candidates = case candidates of
    [] -> pure (maybe (written, offset) id resolvedOnly)
    Repair text agrees : rest
      | Set.member text seen -> go seen resolvedOnly rest
      | otherwise -> do
          value <- analyse text
          if answers value
            then pure (value, agrees)
            else
              go (Set.insert text seen)
                (case resolvedOnly of
                   Nothing | isJust (analysisResolution value) -> Just (value, agrees)
                   kept -> kept)
                rest
