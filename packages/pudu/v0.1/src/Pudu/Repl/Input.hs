{-| @Program.Repl.Input — decides when an entry at the prompt is finished -}
module Pudu.Repl.Input
  ( continuationPrompt
  , isComplete
  , isTriviaOnly
  , readContinuation
  , readEntry
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Token
  ( Keyword (..)
  , Token (..)
  , TokenKind (..)
  , TriviaKind (DocComment)
  , symbolText
  , tokenLeadingTrivia
  , triviaKind
  )
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
          closed <- liftIO (closesBlock next)
          broken <- liftIO (hasTerminalError extended)
          if broken || (complete && closed) then pure extended else continueEntry extended

{-| A line whose last token is `}` finishes a braced construct, so the reader
    does not have to add a blank line after every function or match. -}
closesBlock :: Text -> IO Bool
closesBlock line = do
  source <- newSource (SourceName "<interactive>") line
  let LexResult{lexTokens} = lexSource source
      significant = filter (\token -> tokenKind token /= EndOfFile) lexTokens
  pure $ case reverse significant of
    token : _ -> case tokenKind token of
      Symbol symbol -> symbolText symbol `elem` ["}", ")", "]"]
      _ -> False
    [] -> False

readEntry :: Text -> InputT IO (Maybe Text)
readEntry shown = fmap Text.pack <$> getInputLine (Text.unpack shown)

{-| An entry is complete when every bracket it opened is closed. The check runs
    over real tokens, so a brace inside a string or a comment can never leave
    the session waiting for input that will not come. -}
isComplete :: Text -> IO Bool
isComplete text = do
  source <- newSource (SourceName "<interactive>") text
  let LexResult{lexTokens, lexDiagnostics} = lexSource source
      significant = filter (\token -> tokenKind token /= EndOfFile) lexTokens
      hasDoc = any (any ((== DocComment) . triviaKind) . tokenLeadingTrivia) lexTokens
      hasUnclosedBlock = any ((== "E0003") . diagnosticCodeText . diagnosticCode) lexDiagnostics
      hasOtherError = any ((/= "E0003") . diagnosticCodeText . diagnosticCode) lexDiagnostics
  pure $ case delimiterState significant of
    Left () -> True
    Right pending
      | hasOtherError -> True
      | hasUnclosedBlock -> False
      | null significant -> not hasDoc
      | otherwise -> null pending && not (awaitsOperand significant)

{-| Invalid prefixes are submitted for diagnostics instead of collecting more lines. -}
hasTerminalError :: Text -> IO Bool
hasTerminalError text = do
  source <- newSource (SourceName "<interactive>") text
  let LexResult{lexTokens, lexDiagnostics} = lexSource source
      malformed = any ((/= "E0003") . diagnosticCodeText . diagnosticCode) lexDiagnostics
  pure (malformed || delimiterState lexTokens == Left ())

{-| Whether an entry contains only whitespace and comments, with no code. -}
isTriviaOnly :: Text -> IO Bool
isTriviaOnly text = do
  source <- newSource (SourceName "<interactive>") text
  let LexResult{lexTokens, lexDiagnostics} = lexSource source
      significant = filter (\token -> tokenKind token /= EndOfFile) lexTokens
      hasDoc = any (any ((== DocComment) . triviaKind) . tokenLeadingTrivia) lexTokens
  pure (null significant && null lexDiagnostics && not hasDoc)

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
    Keyword keyword -> keyword `elem` [KwElse, KwIn, KwWhere, KwAs, KwMatch, KwWhile, KwFor, KwIf]
    _ -> False

continuationSymbols :: [Text]
continuationSymbols =
  [ "=", "=>", "->", ",", "|", "+", "-", "*", "/", "%", "&", "&&", "||"
  , "==", "!=", "<", "<=", ">", ">=", "..", "..=", ":", "."
  , "&+", "&-", "&*", "+|", "-|", "*|", "!"
  , "<<", ">>", "^"
  ]

{-| Keep the expected closer on a strict stack. A mismatched closer is terminal
    input, leaving the parser to report the actual diagnostic. -}
delimiterState :: [Token] -> Either () [Text]
delimiterState = foldl' step (Right [])
 where
  step failed@(Left ()) _ = failed
  step (Right pending) token = case tokenKind token of
    Symbol symbol -> case symbolText symbol of
      "(" -> Right (")" : pending)
      "[" -> Right ("]" : pending)
      "{" -> Right ("}" : pending)
      closer | closer `elem` [")", "]", "}"] -> case pending of
        expected : rest | expected == closer -> Right rest
        _ -> Left ()
      _ -> Right pending
    _ -> Right pending
