module Pudu.Frontend.Lexer.QuotedSpec (quotedProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( diagnosticCode, diagnosticCodeText, diagnosticMessage, diagnosticSpan )
import Pudu.Frontend.Lexer.Cursor
  ( completeCursor, newCursor, outputDiagnostics, outputTokens )
import Pudu.Frontend.Lexer.Identifier (scanIdentifier)
import Pudu.Frontend.Lexer.Quoted (scanQuoted)
import Pudu.Frontend.Lexer.Trivia (scanTrivia)
import Pudu.Frontend.Token
  ( Token, TokenKind (CharLiteral, EndOfFile, Identifier, Invalid, StringLiteral)
  , tokenKind, tokenLeadingTrivia, tokenLexeme, triviaText
  )
import Pudu.Source
  ( SourceName (SourceName), newSource, spanEnd, spanStart, unOffset )
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

quotedProperties :: [(String, IO Property)]
quotedProperties =
  [ ("quoted literals decode admitted escapes", testValidQuoted)
  , ("Unicode escapes reject malformed scalar values", testInvalidUnicode)
  , ("unknown escapes emit exact E0005", testInvalidEscape)
  , ("character cardinality emits exact E0007", testCharacterCardinality)
  , ("raw string braces emit exact E0008", testReservedBraces)
  , ("unterminated literals stop before newline with E0002", testUnterminated)
  , ("long quoted payloads remain exact", testLongString)
  , ("quoted scanner non-matches do not consume", testNonMatch)
  ]

testValidQuoted :: IO Property
testValidQuoted = do
  outcomes <-
    traverse
      runValid
      [ ("\"hi\"", StringLiteral "hi")
      , ("\"a\\nb\"", StringLiteral "a\nb")
      , ("\"quote: \\\"\"", StringLiteral "quote: \"")
      , ("\"nul:\\0\"", StringLiteral "nul:\0")
      , ("\"light:\\u{1F4A1}\"", StringLiteral "light:💡")
      , ("'x'", CharLiteral 'x')
      , ("'\\n'", CharLiteral '\n')
      , ("'\\''", CharLiteral '\'')
      , ("'\\u{0}'", CharLiteral '\0')
      , ("'\\u{10FFFF}'", CharLiteral '\x10FFFF')
      ]
  pure (conjoin outcomes)

testInvalidUnicode :: IO Property
testInvalidUnicode = do
  outcomes <-
    traverse
      (runInvalid "E0006" "invalid Unicode escape")
      [ "\"\\u{}\""
      , "\"\\u{1234567}\""
      , "\"\\u{D800}\""
      , "\"\\u{110000}\""
      , "\"\\u{12G}\""
      ]
  pure (conjoin outcomes)

testInvalidEscape :: IO Property
testInvalidEscape = do
  stringOutcome <- runInvalid "E0005" "invalid escape sequence" "\"\\q\""
  charOutcome <- runInvalid "E0005" "invalid escape sequence" "'\\q'"
  pure (conjoin [stringOutcome, charOutcome])

testCharacterCardinality :: IO Property
testCharacterCardinality = do
  emptyOutcome <-
    runInvalid
      "E0007"
      "character literal must contain exactly one Unicode scalar value"
      "''"
  multipleOutcome <-
    runInvalid
      "E0007"
      "character literal must contain exactly one Unicode scalar value"
      "'ab'"
  pure (conjoin [emptyOutcome, multipleOutcome])

testReservedBraces :: IO Property
testReservedBraces = do
  leftOutcome <- runInvalid "E0008" "string interpolation is reserved" "\"a{b\""
  rightOutcome <- runInvalid "E0008" "string interpolation is reserved" "\"a}b\""
  pure (conjoin [leftOutcome, rightOutcome])

testUnterminated :: IO Property
testUnterminated = do
  source <- newSource (SourceName "unterminated-quoted.pudu") "\"abc\nnext"
  pure $
    case scanQuoted (newCursor source) >>= scanTrivia >>= scanIdentifier >>= completeCursor of
      Just output ->
        case (outputTokens output, outputDiagnostics output) of
          ([invalid, name, eof], [finding]) ->
            conjoin
              [ tokenKind invalid === Invalid "\"abc"
              , tokenKind name === Identifier "next"
              , tokenKind eof === EndOfFile
              , map triviaText (tokenLeadingTrivia name) === ["\n"]
              , diagnosticCodeText (diagnosticCode finding) === "E0002"
              , diagnosticMessage finding === "unterminated string literal"
              , unOffset (spanStart (diagnosticSpan finding)) === 0
              , unOffset (spanEnd (diagnosticSpan finding)) === 4
              , reconstruct [invalid, name, eof] === "\"abc\nnext"
              ]
          _ -> counterexample "unterminated fixture returned unexpected output" False
      Nothing -> counterexample "unterminated fixture did not complete" False

testLongString :: IO Property
testLongString = do
  let payload = Text.replicate 10000 "a"
      sourceText = "\"" <> payload <> "\""
  source <- newSource (SourceName "long-string.pudu") sourceText
  pure $
    case scanQuoted (newCursor source) >>= completeCursor of
      Just output ->
        case outputTokens output of
          [token, eof] ->
            conjoin
              [ tokenKind token === StringLiteral payload
              , tokenKind eof === EndOfFile
              , tokenLexeme token === sourceText
              , reconstruct [token, eof] === sourceText
              ]
          _ -> counterexample "long string returned unexpected tokens" False
      Nothing -> counterexample "long string did not complete" False

testNonMatch :: IO Property
testNonMatch = do
  source <- newSource (SourceName "non-quote.pudu") "name"
  pure (property (isNothing (scanQuoted (newCursor source))))

runValid :: (Text, TokenKind) -> IO Property
runValid (sourceText, expectedKind) = do
  source <- newSource (SourceName "valid-quoted.pudu") sourceText
  pure $
    case scanQuoted (newCursor source) >>= completeCursor of
      Just output ->
        case outputTokens output of
          [token, eof] ->
            conjoin
              [ tokenKind token === expectedKind
              , tokenKind eof === EndOfFile
              , tokenLexeme token === sourceText
              , outputDiagnostics output === []
              , reconstruct [token, eof] === sourceText
              ]
          _ -> counterexample ("unexpected valid tokens for " <> show sourceText) False
      Nothing -> counterexample ("valid quoted input did not complete: " <> show sourceText) False

runInvalid :: Text -> Text -> Text -> IO Property
runInvalid expectedCode expectedMessage sourceText = do
  source <- newSource (SourceName "invalid-quoted.pudu") sourceText
  pure $
    case scanQuoted (newCursor source) >>= completeCursor of
      Just output ->
        case (outputTokens output, outputDiagnostics output) of
          ([token, eof], [finding]) ->
            conjoin
              [ tokenKind token === Invalid sourceText
              , tokenLexeme token === sourceText
              , tokenKind eof === EndOfFile
              , diagnosticCodeText (diagnosticCode finding) === expectedCode
              , diagnosticMessage finding === expectedMessage
              , property (unOffset (spanStart (diagnosticSpan finding)) >= 0)
              , property (unOffset (spanEnd (diagnosticSpan finding)) <= Text.length sourceText)
              , reconstruct [token, eof] === sourceText
              ]
          _ -> counterexample ("unexpected invalid output for " <> show sourceText) False
      Nothing -> counterexample ("invalid quoted input did not complete: " <> show sourceText) False

reconstruct :: [Token] -> Text
reconstruct = Text.concat . map tokenText

tokenText :: Token -> Text
tokenText token = Text.concat (map triviaText (tokenLeadingTrivia token)) <> tokenLexeme token

isNothing :: Maybe value -> Bool
isNothing result = case result of
  Nothing -> True
  Just _ -> False
