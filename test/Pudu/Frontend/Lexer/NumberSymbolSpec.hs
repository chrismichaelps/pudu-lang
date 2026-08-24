module Pudu.Frontend.Lexer.NumberSymbolSpec (numberSymbolProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Severity (Error), diagnosticCode, diagnosticCodeText, diagnosticMessage
  , diagnosticSeverity, diagnosticSpan
  )
import Pudu.Frontend.Lexer.Cursor
  ( LexerOutput, completeCursor, newCursor, outputDiagnostics, outputTokens )
import Pudu.Frontend.Lexer.Identifier (scanIdentifier)
import Pudu.Frontend.Lexer.Number (scanNumber)
import Pudu.Frontend.Lexer.Symbol (scanSymbol)
import Pudu.Frontend.Token
  ( SymbolKind (SymDot, SymMinus, SymRangeExclusive, SymRangeInclusive)
  , TokenKind (EndOfFile, FloatLiteral, Identifier, IntegerLiteral, Invalid, Symbol)
  , symbolText, tokenKind, tokenLexeme
  )
import Pudu.Source
  ( SourceName (SourceName), newSource, spanEnd, spanStart, unOffset )
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

numberSymbolProperties :: [(String, IO Property)]
numberSymbolProperties =
  [ ("valid integer literals remain textual", testValidIntegers)
  , ("valid decimal floats remain textual", testValidFloats)
  , ("malformed numeric candidates emit exact E0004", testMalformedNumbers)
  , ("numeric scanning preserves dot and range boundaries", testNumericBoundaries)
  , ("every closed symbol uses exact longest matching", testAllSymbols)
  ]

testValidIntegers :: IO Property
testValidIntegers = do
  let stress = Text.replicate 10000 "9"
      literals =
        [ "0", "1_000", "127i8", "255u8", "0b10_01i16"
        , "0o7u32", "0xdead_BEEF", "0xffu8", stress
        ]
  outcomes <- traverse scanNumberOutput literals
  pure $ case sequence outcomes of
    Just outputs -> conjoin (zipWith (validNumber IntegerLiteral) literals outputs)
    Nothing -> counterexample "valid integer did not complete" False

testValidFloats :: IO Property
testValidFloats = do
  let literals = ["1.0", "1_2.3_4", "1e9", "1E+9", "1.0E-9"]
  outcomes <- traverse scanNumberOutput literals
  pure $ case sequence outcomes of
    Just outputs -> conjoin (zipWith (validNumber FloatLiteral) literals outputs)
    Nothing -> counterexample "valid float did not complete" False

testMalformedNumbers :: IO Property
testMalformedNumbers = do
  let literals =
        [ "0x", "0XFF", "0b2", "0o8", "0xG", "1_", "1__2"
        , "1e", "1e+", "1e_2", "1foo", "1I8", "1u7", "0x1u7"
        ]
  outcomes <- traverse scanNumberOutput literals
  pure $ case sequence outcomes of
    Just outputs -> conjoin (zipWith malformedNumber literals outputs)
    Nothing -> counterexample "malformed number did not complete" False

testNumericBoundaries :: IO Property
testNumericBoundaries = do
  exclusive <- scanRange "1..2"
  inclusive <- scanRange "1..=2"
  trailingDot <- scanNumberSymbol "1."
  dotted <- scanDotted "1.foo"
  signed <- scanSigned "-1"
  pure
    ( conjoin
        [ outputKinds exclusive
            === Just [IntegerLiteral "1", Symbol SymRangeExclusive, IntegerLiteral "2", EndOfFile]
        , outputKinds inclusive
            === Just [IntegerLiteral "1", Symbol SymRangeInclusive, IntegerLiteral "2", EndOfFile]
        , outputKinds trailingDot
            === Just [IntegerLiteral "1", Symbol SymDot, EndOfFile]
        , outputKinds dotted
            === Just [IntegerLiteral "1", Symbol SymDot, Identifier "foo", EndOfFile]
        , outputKinds signed
            === Just [Symbol SymMinus, IntegerLiteral "1", EndOfFile]
        ]
    )

testAllSymbols :: IO Property
testAllSymbols = do
  outcomes <- traverse scanSymbolOutput allSymbols
  unknownSource <- newSource (SourceName "unknown-symbol.pudu") "_"
  nonNumberSource <- newSource (SourceName "not-number.pudu") "name"
  pure $ case sequence outcomes of
    Just outputs ->
      conjoin
        [ conjoin (zipWith validSymbol allSymbols outputs)
        , rejects (scanSymbol (newCursor unknownSource))
        , rejects (scanNumber (newCursor nonNumberSource))
        ]
    Nothing -> counterexample "closed symbol did not complete" False

scanNumberOutput :: Text -> IO (Maybe LexerOutput)
scanNumberOutput sourceValue = do
  source <- newSource (SourceName "number.pudu") sourceValue
  pure (scanNumber (newCursor source) >>= completeCursor)

scanSymbolOutput :: SymbolKind -> IO (Maybe LexerOutput)
scanSymbolOutput kind = do
  source <- newSource (SourceName "symbol.pudu") (symbolText kind)
  pure (scanSymbol (newCursor source) >>= completeCursor)

scanRange :: Text -> IO (Maybe LexerOutput)
scanRange sourceValue = do
  source <- newSource (SourceName "range.pudu") sourceValue
  pure (scanNumber (newCursor source) >>= scanSymbol >>= scanNumber >>= completeCursor)

scanNumberSymbol :: Text -> IO (Maybe LexerOutput)
scanNumberSymbol sourceValue = do
  source <- newSource (SourceName "number-symbol.pudu") sourceValue
  pure (scanNumber (newCursor source) >>= scanSymbol >>= completeCursor)

scanDotted :: Text -> IO (Maybe LexerOutput)
scanDotted sourceValue = do
  source <- newSource (SourceName "dot.pudu") sourceValue
  pure (scanNumber (newCursor source) >>= scanSymbol >>= scanIdentifier >>= completeCursor)

scanSigned :: Text -> IO (Maybe LexerOutput)
scanSigned sourceValue = do
  source <- newSource (SourceName "signed.pudu") sourceValue
  pure (scanSymbol (newCursor source) >>= scanNumber >>= completeCursor)

validNumber :: (Text -> TokenKind) -> Text -> LexerOutput -> Property
validNumber constructor lexeme output =
  conjoin
    [ map tokenKind (outputTokens output) === [constructor lexeme, EndOfFile]
    , map tokenLexeme (outputTokens output) === [lexeme, Text.empty]
    , outputDiagnostics output === []
    ]

malformedNumber :: Text -> LexerOutput -> Property
malformedNumber lexeme output = case (outputTokens output, outputDiagnostics output) of
  ([token, eof], [finding]) ->
    conjoin
      [ tokenKind token === Invalid lexeme
      , tokenLexeme token === lexeme
      , tokenKind eof === EndOfFile
      , diagnosticCodeText (diagnosticCode finding) === "E0004"
      , diagnosticSeverity finding === Error
      , diagnosticMessage finding === "malformed numeric literal"
      , unOffset (spanStart (diagnosticSpan finding)) === 0
      , unOffset (spanEnd (diagnosticSpan finding)) === Text.length lexeme
      ]
  _ -> counterexample "malformed number returned unexpected output" False

validSymbol :: SymbolKind -> LexerOutput -> Property
validSymbol kind output =
  conjoin
    [ map tokenKind (outputTokens output) === [Symbol kind, EndOfFile]
    , map tokenLexeme (outputTokens output) === [symbolText kind, Text.empty]
    , outputDiagnostics output === []
    ]

outputKinds :: Maybe LexerOutput -> Maybe [TokenKind]
outputKinds = fmap (map tokenKind . outputTokens)

allSymbols :: [SymbolKind]
allSymbols = [minBound .. maxBound]

rejects :: Maybe value -> Property
rejects result = property $ case result of
  Nothing -> True
  Just _ -> False
