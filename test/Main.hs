module Main (main) where

import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.DiagnosticSpec (diagnosticProperties)
import Pudu.Diagnostic.RenderSpec (renderProperties)
import Pudu.Frontend.Lexer.CursorSpec (cursorProperties)
import Pudu.Frontend.LexerSpec (lexerProperties)
import Pudu.Frontend.Lexer.NumberSymbolSpec (numberSymbolProperties)
import Pudu.Frontend.Lexer.QuotedSpec (quotedProperties)
import Pudu.Frontend.Lexer.ScannerSpec (scannerProperties)
import Pudu.Frontend.ParserStateNameSpec (parserStateNameProperties)
import Pudu.Frontend.ParserImportSpec (parserImportProperties)
import Pudu.Frontend.ParserBindingSpec (parserBindingProperties)
import Pudu.Frontend.ParserBlockSpec (parserBlockProperties)
import Pudu.Frontend.ParserFunctionSpec (parserFunctionProperties)
import Pudu.Frontend.ParserModuleSpec (parserModuleProperties)
import Pudu.Frontend.ParserPatternSpec (parserPatternProperties)
import Pudu.Frontend.ParserTypeDeclarationSpec (parserTypeDeclarationProperties)
import Pudu.Frontend.ParserExpressionSpec (parserExpressionProperties)
import Pudu.Frontend.ParserTypeSpec (parserTypeProperties)
import Pudu.Frontend.SyntaxSpec (syntaxProperties)
import Pudu.Frontend.TokenSpec (tokenProperties)
import Pudu.EvalSpec (evalProperties)
import Pudu.Repl.SessionSpec (replProperties)
import Pudu.Semantic.ResolveSpec (resolveProperties)
import Pudu.Type.CheckSpec (typeProperties)
import Pudu.Type.InterfaceSpec (interfaceProperties)
import Pudu.Source (Position (Position), Source, SourceName (SourceName), Span, advanceOffset, emptySpan,
  mergeSpans, mkSpan, newSource, offsetFromInt, offsetPosition, sourceLength, sourceName, sourceText,
  spanEnd, spanSource, spanStart, unOffset, zeroOffset, zeroWidthSpan)
import System.Exit (exitFailure)
import Test.QuickCheck (Gen, Property, chooseInt, conjoin, counterexample, forAll, ioProperty, isSuccess,
  property, quickCheckResult, withMaxSuccess, (===))
main :: IO ()
main = do
  sourceOutcomes <-
    sequence
      [ check "empty source position" testEmptySourcePosition
      , check "CRLF position" testCrLfPosition
      , check "mixed newline positions" testMixedNewlinePosition
      , check "Unicode scalars define offsets and columns" testUnicodeScalarPosition
      , check "offset arithmetic rejects invalid advances" testOffsetArithmetic
      , check "span construction validates bounds" testSpanBounds
      , check "zero-width spans retain snapshot identity" testZeroWidthSpans
      , check "span merging respects snapshot identity" testSpanMerging
      , check "source accessors preserve input" testSourceAccessors
      , check "cached source length matches text" propertySourceLength
      , check "every in-bounds offset has a position" propertyValidOffsetsHavePositions
      ]
  diagnosticOutcomes <- traverse (uncurry check) diagnosticProperties
  renderOutcomes <- traverse (uncurry check) renderProperties
  tokenOutcomes <- traverse (uncurry check) tokenProperties
  cursorOutcomes <- traverse (uncurry check) cursorProperties
  scannerOutcomes <- traverse (uncurry check) scannerProperties
  numberSymbolOutcomes <- traverse (uncurry check) numberSymbolProperties
  quotedOutcomes <- traverse (uncurry check) quotedProperties
  lexerOutcomes <- traverse (uncurry check) lexerProperties
  syntaxOutcomes <- traverse (uncurry check) syntaxProperties
  parserStateNameOutcomes <- traverse (uncurry check) parserStateNameProperties
  parserImportOutcomes <- traverse (uncurry check) parserImportProperties
  parserBindingOutcomes <- traverse (uncurry check) parserBindingProperties
  parserBlockOutcomes <- traverse (uncurry check) parserBlockProperties
  parserFunctionOutcomes <- traverse (uncurry check) parserFunctionProperties
  parserModuleOutcomes <- traverse (uncurry check) parserModuleProperties
  parserPatternOutcomes <- traverse (uncurry check) parserPatternProperties
  parserTypeDeclarationOutcomes <- traverse (uncurry check) parserTypeDeclarationProperties
  resolveOutcomes <- traverse (uncurry check) resolveProperties
  evalOutcomes <- traverse (uncurry check) evalProperties
  typeOutcomes <- traverse (uncurry check) typeProperties
  interfaceOutcomes <- traverse (uncurry check) interfaceProperties
  replOutcomes <- traverse (uncurry check) replProperties
  parserTypeOutcomes <- traverse (uncurry check) parserTypeProperties
  parserExpressionOutcomes <- traverse (uncurry check) parserExpressionProperties
  unless (and (sourceOutcomes <> diagnosticOutcomes <> renderOutcomes <> tokenOutcomes <> cursorOutcomes <> scannerOutcomes <> numberSymbolOutcomes <> quotedOutcomes <> lexerOutcomes <> syntaxOutcomes <> parserStateNameOutcomes <> parserImportOutcomes <> parserBindingOutcomes <> parserBlockOutcomes <> parserFunctionOutcomes <> parserModuleOutcomes <> parserPatternOutcomes <> parserTypeDeclarationOutcomes <> resolveOutcomes <> evalOutcomes <> typeOutcomes <> interfaceOutcomes <> replOutcomes <> parserTypeOutcomes <> parserExpressionOutcomes)) exitFailure
check :: String -> IO Property -> IO Bool
check label loadProperty = do
  putStrLn ("[test] " <> label)
  propertyValue <- loadProperty
  result <- quickCheckResult (withMaxSuccess 200 propertyValue)
  pure (isSuccess result)
testEmptySourcePosition :: IO Property
testEmptySourcePosition = do
  source <- newSource (SourceName "empty") Text.empty
  pure (offsetPosition source zeroOffset === Just (Position 1 1))
testCrLfPosition :: IO Property
testCrLfPosition = do
  source <- newSource (SourceName "crlf") "a\r\nb"
  pure
    ( conjoin
        [ positionAt source 2 === Just (Position 2 1)
        , positionAt source 3 === Just (Position 2 1)
        , positionAt source 4 === Just (Position 2 2)
        ]
    )

testMixedNewlinePosition :: IO Property
testMixedNewlinePosition = do
  source <- newSource (SourceName "mixed") "a\rb\nc\r"
  pure
    ( conjoin
        [ positionAt source 2 === Just (Position 2 1)
        , positionAt source 4 === Just (Position 3 1)
        , positionAt source 6 === Just (Position 4 1)
        ]
    )

testUnicodeScalarPosition :: IO Property
testUnicodeScalarPosition = do
  source <- newSource (SourceName "unicode") "💡e\x0301"
  pure
    ( conjoin
        [ unOffset (sourceLength source) === 3
        , positionAt source 1 === Just (Position 1 2)
        , positionAt source 3 === Just (Position 1 4)
        ]
    )

testOffsetArithmetic :: IO Property
testOffsetArithmetic =
  pure $
    case offsetFromInt maxBound of
      Nothing -> counterexample "maxBound offset construction failed" False
      Just largest ->
        conjoin
          [ advanceOffset (-1) zeroOffset === Nothing
          , advanceOffset 1 largest === Nothing
          , advanceOffset 2 zeroOffset === offsetFromInt 2
          ]

testSpanBounds :: IO Property
testSpanBounds = do
  source <- newSource (SourceName "span") "abc"
  pure $
    case (offsetFromInt 0, offsetFromInt 2, offsetFromInt 3, offsetFromInt 4) of
      (Just zero, Just two, Just three, Just four) ->
        conjoin
          [ property (mkSpan source zero three /= Nothing)
          , mkSpan source two zero === Nothing
          , mkSpan source zero four === Nothing
          ]
      _ -> counterexample "valid offset construction failed" False

testSpanMerging :: IO Property
testSpanMerging = do
  source <- newSource (SourceName "source") "abcd"
  otherName <- newSource (SourceName "other") "abcd"
  revised <- newSource (SourceName "source") "wxyz"
  duplicate <- newSource (SourceName "source") "abcd"
  pure $
    case (spanAt source 0 2, spanAt source 1 4, spanAt otherName 0 1, spanAt revised 0 4, spanAt duplicate 0 1) of
      (Just left, Just right, Just other, Just revision, Just duplicateSpan) ->
        conjoin
          [ case mergeSpans left right of
              Just merged ->
                conjoin
                  [ unOffset (spanStart merged) === 0
                  , unOffset (spanEnd merged) === 4
                  ]
              Nothing -> counterexample "same-snapshot spans did not merge" False
          , mergeSpans left other === Nothing
          , mergeSpans left revision === Nothing
          , mergeSpans left duplicateSpan === Nothing
          ]
      _ -> counterexample "test span construction failed" False

testZeroWidthSpans :: IO Property
testZeroWidthSpans = do
  source <- newSource (SourceName "zero") "abc"
  pure $
    case (offsetFromInt 3, zeroWidthSpan source =<< offsetFromInt 3) of
      (Just endOffset, Just atEnd) ->
        let atStart = emptySpan source
         in conjoin
              [ spanSource atStart === SourceName "zero"
              , spanStart atStart === zeroOffset
              , spanEnd atStart === zeroOffset
              , spanStart atEnd === endOffset
              , spanEnd atEnd === endOffset
              , property (not ("abc" `Text.isInfixOf` Text.pack (show atEnd)))
              ]
      _ -> counterexample "zero-width span construction failed" False

testSourceAccessors :: IO Property
testSourceAccessors = do
  source <- newSource (SourceName "accessor") "💡"
  pure
    ( conjoin
        [ sourceName source === SourceName "accessor"
        , sourceText source === "💡"
        , property (not ("💡" `Text.isInfixOf` Text.pack (show source)))
        ]
    )

propertySourceLength :: IO Property
propertySourceLength =
  pure $
    forAll shortText $ \value ->
      ioProperty $ do
        source <- newSource (SourceName "property") value
        pure (unOffset (sourceLength source) === Text.length value)

propertyValidOffsetsHavePositions :: IO Property
propertyValidOffsetsHavePositions =
  pure $
    forAll shortText $ \value ->
      ioProperty $ do
        source <- newSource (SourceName "property") value
        pure (counterexample (show value) (property (all (hasPosition source) [0 .. Text.length value])))

hasPosition :: Source -> Int -> Bool
hasPosition source value =
  case offsetFromInt value of
    Nothing -> False
    Just offset -> offsetPosition source offset /= Nothing

positionAt :: Source -> Int -> Maybe Position
positionAt source value = offsetFromInt value >>= offsetPosition source

spanAt :: Source -> Int -> Int -> Maybe Span
spanAt source start end = do
  startOffset <- offsetFromInt start
  endOffset <- offsetFromInt end
  mkSpan source startOffset endOffset

shortText :: Gen Text
shortText = do
  size <- chooseInt (0, 80)
  Text.pack <$> sequence (replicate size (toEnum <$> chooseInt (0, 127)))
