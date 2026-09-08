{-| @Source.Lexer.Module — exposes total lossless tokenization -}
module Pudu.Frontend.Lexer (LexResult (..), lexSource, scanOne) where

import Control.Applicative ((<|>))
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, Severity (Error), diagnostic, mkDiagnosticCode)
import Pudu.Frontend.Lexer.Cursor
  ( LexerCursor, LexerOutput, captureSince, completeCursor, consumeScalars
  , cursorAtEnd, emitToken, markCursor, newCursor, outputDiagnostics
  , outputTokens, recordDiagnostic
  )
import Pudu.Frontend.Lexer.Identifier (scanIdentifier)
import Pudu.Frontend.Lexer.Number (scanNumber)
import Pudu.Frontend.Lexer.Quoted (scanQuoted)
import Pudu.Frontend.Lexer.Symbol (scanSymbol)
import Pudu.Frontend.Lexer.Trivia (scanTrivia)
import Pudu.Frontend.Token
  ( Token (Token), TokenKind (EndOfFile, Invalid) )
import Pudu.Source
  ( Source, emptySpan, mkSpan, offsetFromInt, sourceLength, sourceText
  , zeroWidthSpan
  )

{-| @Source.Lexer.Result — returns lossless tokens and ordered diagnostics -}
data LexResult = LexResult
  { lexTokens :: ![Token], lexDiagnostics :: ![Diagnostic] }
  deriving stock (Eq, Show)

lexSource :: Source -> LexResult
lexSource source =
  maybe (conservativeResult source) fromCursorOutput (drive (newCursor source))

drive :: LexerCursor -> Maybe LexerOutput
drive cursor
  | cursorAtEnd cursor = completeCursor cursor
  | otherwise = scanOne cursor >>= drive

{-| Scan one token.

    Exposed because an interpolation's expression is lexed by it, and because a
    test of the quoted scanner needs the same scanner the lexer uses rather than
    a stand-in that would agree with it only by accident. -}
scanOne :: LexerCursor -> Maybe LexerCursor
scanOne cursor =
  scanTrivia cursor
    <|> scanQuoted scanOne cursor
    <|> scanNumber cursor
    <|> scanIdentifier cursor
    <|> scanSymbol cursor
    <|> recoverUnknown cursor

recoverUnknown :: LexerCursor -> Maybe LexerCursor
recoverUnknown cursor = do
  let mark = markCursor cursor
      advanced = consumeScalars 1 cursor
  (lexeme, spanValue) <- captureSince mark advanced
  emitted <- emitToken mark (Invalid lexeme) advanced
  code <- mkDiagnosticCode "E0099"
  finding <- diagnostic code Error spanValue "unrecognized input"
  recordDiagnostic finding emitted

fromCursorOutput :: LexerOutput -> LexResult
fromCursorOutput output =
  LexResult (outputTokens output) (outputDiagnostics output)

conservativeResult :: Source -> LexResult
conservativeResult source =
  LexResult (invalidTokens <> [eof]) invalidDiagnostics
  where
    textValue = sourceText source
    wholeSpan = fromMaybe (emptySpan source) $ do
      start <- offsetFromInt 0
      mkSpan source start (sourceLength source)
    endSpan = fromMaybe (emptySpan source) (zeroWidthSpan source (sourceLength source))
    eof = Token EndOfFile Text.empty endSpan []
    invalidTokens
      | Text.null textValue = []
      | otherwise = [Token (Invalid textValue) textValue wholeSpan []]
    invalidDiagnostics
      | Text.null textValue = []
      | otherwise = mapMaybe makeFinding [wholeSpan]
    makeFinding spanValue = do
      code <- mkDiagnosticCode "E0099"
      diagnostic code Error spanValue "lexer recovery fallback"
