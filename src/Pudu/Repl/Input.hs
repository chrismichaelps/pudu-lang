{-| @Program.Repl.Input — decides when an entry at the prompt is finished -}
module Pudu.Repl.Input
  ( continuationPrompt
  , readContinuation
  , readEntry
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Token (Keyword (..), Token (..), TokenKind (..), symbolText)
import Pudu.Source (SourceName (SourceName), newSource)
import System.Console.Haskeline
  ( InputT
  , getInputLine
  )

{-| The prompt a continued entry shows, distinct from the first so a reader can
    see at a glance that the session is still waiting. -}
continuationPrompt :: Text
continuationPrompt = "puduci| "

{-| A construct that is still open keeps reading at the continuation prompt.

    Once continuation has begun, reading ends at a closing `}` that balances the
    entry or at a blank line. The blank line is what lets a form whose next line
    starts with `|`, `.`, or `?` — a sum type or a fluent chain — be entered
    without a lookahead the prompt cannot perform. -}
readContinuation :: Text -> InputT IO Text
readContinuation first = do
  complete <- liftIO (isComplete first)
  if complete then pure first else continueEntry first

continueEntry :: Text -> InputT IO Text
continueEntry accumulated = do
  more <- readEntry continuationPrompt
  case more of
    Nothing -> pure accumulated
    Just next
      | Text.null (Text.strip next) -> pure accumulated
      | otherwise -> do
          let extended = accumulated <> "\n" <> next
          complete <- liftIO (isComplete extended)
          if complete && closesBlock next then pure extended else continueEntry extended

{-| A line whose last token is `}` finishes a braced construct, so the reader
    does not have to add a blank line after every function or match. -}
closesBlock :: Text -> Bool
closesBlock line = Text.isSuffixOf "}" (Text.stripEnd line)

readEntry :: Text -> InputT IO (Maybe Text)
readEntry shown = fmap Text.pack <$> getInputLine (Text.unpack shown)

{-| An entry is complete when every bracket it opened is closed. The check runs
    over real tokens, so a brace inside a string or a comment can never leave
    the session waiting for input that will not come. -}
isComplete :: Text -> IO Bool
isComplete text = do
  source <- newSource (SourceName "<interactive>") text
  let LexResult{lexTokens} = lexSource source
      significant = filter (\token -> tokenKind token /= EndOfFile) lexTokens
  pure
    ( not (null significant)
        && openDepth significant <= 0
        && not (awaitsOperand significant)
    )

{-| A submission with no tokens of its own is documentation waiting for the
    declaration it documents, so the prompt keeps reading. Typing `/// ...` and
    pressing enter is the start of an entry, not an entry.

    A line that ends with an operator, a separator, or a `=` is still waiting
    for its right-hand side, which is the same continuation rule the language
    itself applies across line breaks. -}
awaitsOperand :: [Token] -> Bool
awaitsOperand tokens = case reverse tokens of
  [] -> False
  final : _ -> case tokenKind final of
    Symbol symbol -> symbolText symbol `elem` continuationSymbols
    Keyword keyword -> keyword `elem` [KwElse, KwIn, KwWhere, KwAs, KwReturn, KwMatch, KwWhile, KwFor, KwIf]
    _ -> False

continuationSymbols :: [Text]
continuationSymbols =
  [ "=", "=>", "->", ",", "|", "+", "-", "*", "/", "%", "&", "&&", "||"
  , "==", "!=", "<", "<=", ">", ">=", "..", "..=", ":", "."
  , "&+", "&-", "&*", "+|", "-|", "*|", "!"
  ]

openDepth :: [Token] -> Int
openDepth = foldl step 0
 where
  step total token = case tokenKind token of
    Symbol symbol
      | symbolText symbol `elem` ["(", "[", "{"] -> total + 1
      | symbolText symbol `elem` [")", "]", "}"] -> max 0 (total - 1)
    _ -> total
