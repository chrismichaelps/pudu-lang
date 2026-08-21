module Pudu.Frontend.Lexer.ScannerSpec (scannerProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Severity (Error), diagnosticCode, diagnosticCodeText, diagnosticMessage
  , diagnosticSeverity, diagnosticSpan
  )
import Pudu.Frontend.Lexer.Cursor
  ( LexerCursor, completeCursor, consumeWhile, cursorOffset, newCursor
  , outputDiagnostics, outputTokens, peekScalar
  )
import Pudu.Frontend.Lexer.Identifier (scanIdentifier)
import Pudu.Frontend.Lexer.Trivia (scanTrivia)
import Pudu.Frontend.Token
  ( Keyword (KwModule), Token, TokenKind (EndOfFile, Identifier, Keyword)
  , TriviaKind (BlockComment, LineComment, Whitespace), tokenKind
  , tokenLeadingTrivia, tokenLexeme, triviaKind, triviaText
  )
import Pudu.Source
  ( Source, SourceName (SourceName), newSource, sourceText, spanEnd, spanStart, unOffset )
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

scannerProperties :: [(String, IO Property)]
scannerProperties =
  [ ("cursor consumes maximal predicate prefix", testConsumeWhile)
  , ("whitespace and line comments remain exact", testLineTrivia)
  , ("nested block comments remain exact", testNestedBlockComment)
  , ("unterminated blocks emit E0003 and preserve text", testUnterminatedBlock)
  , ("Unicode identifiers and decimal continuation classify", testUnicodeIdentifier)
  , ("keywords remain exact and case-sensitive", testKeywordClassification)
  , ("scanner non-matches never consume", testNonMatches)
  ]

testConsumeWhile :: IO Property
testConsumeWhile = do
  source <- newSource (SourceName "prefix.pudu") "aaab"
  let initial = newCursor source
      unchanged = consumeWhile (== 'z') initial
      advanced = consumeWhile (== 'a') initial
  pure
    ( conjoin
        [ unOffset (cursorOffset unchanged) === 0
        , unOffset (cursorOffset advanced) === 3
        , peekScalar advanced === Just 'b'
        ]
    )

testLineTrivia :: IO Property
testLineTrivia = do
  source <- newSource (SourceName "line.pudu") " \t//x\r\nname"
  pure $ case scanTrivia (newCursor source) >>= scanTrivia >>= scanTrivia >>= scanIdentifier >>= completeCursor of
    Just output -> case outputTokens output of
      [name, eof] ->
        conjoin
          [ tokenKind name === Identifier "name"
          , tokenKind eof === EndOfFile
          , map triviaKind (tokenLeadingTrivia name) === [Whitespace, LineComment, Whitespace]
          , map triviaText (tokenLeadingTrivia name) === [" \t", "//x", "\r\n"]
          , reconstruct [name, eof] === " \t//x\r\nname"
          ]
      _ -> counterexample "line fixture returned unexpected tokens" False
    Nothing -> counterexample "line fixture did not complete" False

testNestedBlockComment :: IO Property
testNestedBlockComment = do
  source <- newSource (SourceName "nested.pudu") "/*a/*b*/c*/module"
  stress <- newSource (SourceName "nested-stress.pudu") (Text.replicate 1000 "/*" <> Text.replicate 1000 "*/")
  pure $ case scanTrivia (newCursor source) >>= scanIdentifier >>= completeCursor of
    Just output -> case outputTokens output of
      [keyword, eof] ->
        conjoin
          [ tokenKind keyword === Keyword KwModule
          , map triviaKind (tokenLeadingTrivia keyword) === [BlockComment]
          , map triviaText (tokenLeadingTrivia keyword) === ["/*a/*b*/c*/"]
          , reconstruct [keyword, eof] === "/*a/*b*/c*/module"
          , outputDiagnostics output === []
          , property (isCompleteTrivia stress)
          ]
      _ -> counterexample "nested fixture returned unexpected tokens" False
    Nothing -> counterexample "nested fixture did not complete" False

testUnterminatedBlock :: IO Property
testUnterminatedBlock = do
  source <- newSource (SourceName "unterminated.pudu") "/*a/*b*/"
  pure $ case scanTrivia (newCursor source) >>= completeCursor of
    Just output -> case (outputTokens output, outputDiagnostics output) of
      ([eof], [finding]) ->
        conjoin
          [ tokenKind eof === EndOfFile
          , map triviaText (tokenLeadingTrivia eof) === ["/*a/*b*/"]
          , diagnosticCodeText (diagnosticCode finding) === "E0003"
          , diagnosticSeverity finding === Error
          , diagnosticMessage finding === "unterminated block comment"
          , unOffset (spanStart (diagnosticSpan finding)) === 0
          , unOffset (spanEnd (diagnosticSpan finding)) === 8
          , reconstruct [eof] === "/*a/*b*/"
          ]
      _ -> counterexample "unterminated fixture returned unexpected output" False
    Nothing -> counterexample "unterminated fixture did not complete" False

testUnicodeIdentifier :: IO Property
testUnicodeIdentifier = do
  source <- newSource (SourceName "unicode-name.pudu") "变量٣ 𐐀_2"
  pure $ case scanIdentifier (newCursor source) >>= scanTrivia >>= scanIdentifier >>= completeCursor of
    Just output ->
      conjoin
        [ map tokenKind (outputTokens output)
            === [Identifier "变量٣", Identifier "𐐀_2", EndOfFile]
        , reconstruct (outputTokens output) === "变量٣ 𐐀_2"
        ]
    Nothing -> counterexample "Unicode identifier fixture did not complete" False

testKeywordClassification :: IO Property
testKeywordClassification = do
  source <- newSource (SourceName "keywords.pudu") "module Module module2 _"
  pure $ case scanWords (newCursor source) >>= completeCursor of
    Just output ->
      conjoin
        [ map tokenKind (outputTokens output)
            === [Keyword KwModule, Identifier "Module", Identifier "module2", Identifier "_", EndOfFile]
        , reconstruct (outputTokens output) === "module Module module2 _"
        ]
    Nothing -> counterexample "keyword fixture did not complete" False

testNonMatches :: IO Property
testNonMatches = do
  nameSource <- newSource (SourceName "name.pudu") "name"
  digitSource <- newSource (SourceName "digit.pudu") "٣"
  combiningSource <- newSource (SourceName "combining.pudu") "\x0301"
  combiningTail <- newSource (SourceName "combining-tail.pudu") "e\x0301"
  pure
    ( conjoin
        [ rejects (scanTrivia (newCursor nameSource))
        , rejects (scanIdentifier (newCursor digitSource))
        , rejects (scanIdentifier (newCursor combiningSource))
        , case scanIdentifier (newCursor combiningTail) of
            Just advanced -> unOffset (cursorOffset advanced) === 1
            Nothing -> counterexample "letter before combining mark did not scan" False
        ]
    )

scanWords :: LexerCursor -> Maybe LexerCursor
scanWords cursor = do
  first <- scanIdentifier cursor
  firstSpace <- scanTrivia first
  second <- scanIdentifier firstSpace
  secondSpace <- scanTrivia second
  third <- scanIdentifier secondSpace
  thirdSpace <- scanTrivia third
  scanIdentifier thirdSpace

isCompleteTrivia :: Source -> Bool
isCompleteTrivia source = case scanTrivia (newCursor source) >>= completeCursor of
  Just output -> case outputTokens output of
    [eof] ->
      map triviaText (tokenLeadingTrivia eof) == [sourceText source]
        && null (outputDiagnostics output)
    _ -> False
  Nothing -> False

reconstruct :: [Token] -> Text
reconstruct = Text.concat . map tokenText

tokenText :: Token -> Text
tokenText token = Text.concat (map triviaText (tokenLeadingTrivia token)) <> tokenLexeme token

rejects :: Maybe value -> Property
rejects result = property $ case result of
  Nothing -> True
  Just _ -> False
