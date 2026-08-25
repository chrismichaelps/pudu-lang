module Pudu.Frontend.Lexer.QuotedSpec (quotedProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticMessage)
import Pudu.Frontend.Lexer.Cursor
  ( completeCursor, newCursor, outputDiagnostics, outputTokens )
import Pudu.Frontend.Lexer.Identifier (scanIdentifier)
import Pudu.Frontend.Lexer (scanOne)
import Pudu.Frontend.Lexer.Quoted (scanQuoted)
import Pudu.Frontend.Lexer.Trivia (scanTrivia)
import Pudu.Frontend.Token
  ( Token, TokenKind (CharLiteral, EndOfFile, Identifier, Invalid, StringLiteral)
  , tokenKind, tokenLeadingTrivia, tokenLexeme, triviaText
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

quotedProperties :: [(String, IO Property)]
quotedProperties =
  [ ("quoted literals decode admitted escapes", conjoin <$> traverse validCase validFixtures)
  , ("quoted failures retain exact diagnostics", conjoin <$> traverse invalidCase invalidFixtures)
  , ("unterminated quoted input stops before newline", testNewlineBoundary)
  , ("long quoted input stays exact and non-matches stay inert", testStructuralBoundaries)
  ]

validFixtures :: [(Text, TokenKind)]
validFixtures =
  [ ("\"hi\"", StringLiteral "hi"), ("\"a\\nb\"", StringLiteral "a\nb")
  , ("\"quote: \\\"\"", StringLiteral "quote: \""), ("\"nul:\\0\"", StringLiteral "nul:\0")
  , ("\"light:\\u{1F4A1}\"", StringLiteral "light:💡"), ("'x'", CharLiteral 'x')
  , ("'\\n'", CharLiteral '\n'), ("'\\''", CharLiteral '\'')
  , ("'\\u{0}'", CharLiteral '\0'), ("'\\u{10FFFF}'", CharLiteral '\x10FFFF')
  , ("\"a\\{b\\}c\"", StringLiteral "a{b}c")
  , ("'\\{'", CharLiteral '{')
  ]

invalidFixtures :: [(Text, Text, Text)]
invalidFixtures =
  [ ("\"\\u{}\"", "E0006", "invalid Unicode escape")
  , ("\"\\u{1234567}\"", "E0006", "invalid Unicode escape")
  , ("\"\\u{D800}\"", "E0006", "invalid Unicode escape")
  , ("\"\\u{110000}\"", "E0006", "invalid Unicode escape")
  , ("\"\\u{12G}\"", "E0006", "invalid Unicode escape")
  , ("\"\\q\"", "E0005", "invalid escape sequence"), ("'\\q'", "E0005", "invalid escape sequence")
  , ("''", "E0007", "character literal must contain exactly one Unicode scalar value")
  , ("'ab'", "E0007", "character literal must contain exactly one Unicode scalar value")
  , ("\"a{b\"", "E0010", "an interpolation is not closed")
  , ("\"a}b\"", "E0008", "a closing brace has no interpolation to close")
  , ("'x", "E0002", "unterminated character literal")
  ]

validCase :: (Text, TokenKind) -> IO Property
validCase (input, expected) = do
  source <- newSource (SourceName "valid-quoted.pudu") input
  pure $ case scanQuoted scanOne (newCursor source) >>= completeCursor of
    Just output -> case outputTokens output of
      [token, eof] -> conjoin [tokenKind token === expected, tokenKind eof === EndOfFile,
        tokenLexeme token === input, outputDiagnostics output === [], reconstruct [token, eof] === input]
      _ -> counterexample ("unexpected tokens for " <> show input) False
    Nothing -> counterexample ("quoted input did not complete: " <> show input) False

invalidCase :: (Text, Text, Text) -> IO Property
invalidCase (input, code, message) = do
  source <- newSource (SourceName "invalid-quoted.pudu") input
  pure $ case scanQuoted scanOne (newCursor source) >>= completeCursor of
    Just output -> case (outputTokens output, outputDiagnostics output) of
      ([token, eof], [finding]) -> conjoin
        [ tokenKind token === Invalid input, tokenLexeme token === input, tokenKind eof === EndOfFile
        , diagnosticCodeText (diagnosticCode finding) === code
        , diagnosticMessage finding === message, reconstruct [token, eof] === input
        ]
      _ -> counterexample ("unexpected invalid result for " <> show input) False
    Nothing -> counterexample ("invalid input did not complete: " <> show input) False

testNewlineBoundary :: IO Property
testNewlineBoundary = do
  source <- newSource (SourceName "unterminated.pudu") "\"abc\nnext"
  pure $ case scanQuoted scanOne (newCursor source) >>= scanTrivia >>= scanIdentifier >>= completeCursor of
    Just output -> case (outputTokens output, outputDiagnostics output) of
      ([invalid, name, eof], [finding]) -> conjoin
        [ tokenKind invalid === Invalid "\"abc", tokenKind name === Identifier "next"
        , tokenKind eof === EndOfFile, map triviaText (tokenLeadingTrivia name) === ["\n"]
        , diagnosticCodeText (diagnosticCode finding) === "E0002"
        , reconstruct [invalid, name, eof] === "\"abc\nnext"
        ]
      _ -> counterexample "newline recovery returned unexpected output" False
    Nothing -> counterexample "newline recovery did not complete" False

testStructuralBoundaries :: IO Property
testStructuralBoundaries = do
  let payload = Text.replicate 10000 "a"; input = "\"" <> payload <> "\""
  longSource <- newSource (SourceName "long.pudu") input
  plainSource <- newSource (SourceName "plain.pudu") "name"
  pure $ case scanQuoted scanOne (newCursor longSource) >>= completeCursor of
    Just output -> case outputTokens output of
      [token, eof] -> conjoin [tokenKind token === StringLiteral payload,
        reconstruct [token, eof] === input, property (rejects (scanQuoted scanOne (newCursor plainSource)))]
      _ -> counterexample "long input returned unexpected tokens" False
    Nothing -> counterexample "long input did not complete" False

reconstruct :: [Token] -> Text
reconstruct = Text.concat . map (\token -> Text.concat (map triviaText (tokenLeadingTrivia token)) <> tokenLexeme token)

rejects :: Maybe value -> Bool
rejects result = case result of Nothing -> True; Just _ -> False
