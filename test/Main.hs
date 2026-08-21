module Main (main) where

import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Source
  ( Position (Position)
  , Source
  , SourceName (SourceName)
  , Span
  , advanceOffset
  , emptySpan
  , mergeSpans
  , mkSource
  , mkSpan
  , offsetFromInt
  , offsetPosition
  , sourceLength
  , sourceName
  , sourceText
  , spanEnd
  , spanSource
  , spanStart
  , unOffset
  , zeroOffset
  , zeroWidthSpan
  )
import System.Exit (exitFailure)
import Test.QuickCheck
  ( Gen
  , Property
  , Testable
  , conjoin
  , counterexample
  , forAll
  , property
  , quickCheckResult
  , withMaxSuccess
  , (===)
  )
import Test.QuickCheck.Gen (chooseInt)
import Test.QuickCheck.Test (isSuccess)

main :: IO ()
main = do
  outcomes <-
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
  unless (and outcomes) exitFailure

check :: Testable propertyValue => String -> propertyValue -> IO Bool
check label propertyValue = do
  putStrLn ("[test] " <> label)
  result <- quickCheckResult (withMaxSuccess 200 propertyValue)
  pure (isSuccess result)

testEmptySourcePosition :: Property
testEmptySourcePosition =
  offsetPosition (mkSource (SourceName "empty") Text.empty) zeroOffset
    === Just (Position 1 1)

testCrLfPosition :: Property
testCrLfPosition =
  let source = mkSource (SourceName "crlf") "a\r\nb"
   in conjoin
        [ positionAt source 2 === Just (Position 2 1)
        , positionAt source 3 === Just (Position 2 1)
        , positionAt source 4 === Just (Position 2 2)
        ]

testMixedNewlinePosition :: Property
testMixedNewlinePosition =
  let source = mkSource (SourceName "mixed") "a\rb\nc\r"
   in conjoin
        [ positionAt source 2 === Just (Position 2 1)
        , positionAt source 4 === Just (Position 3 1)
        , positionAt source 6 === Just (Position 4 1)
        ]

testUnicodeScalarPosition :: Property
testUnicodeScalarPosition =
  let source = mkSource (SourceName "unicode") "💡e\x0301"
   in conjoin
        [ unOffset (sourceLength source) === 3
        , positionAt source 1 === Just (Position 1 2)
        , positionAt source 3 === Just (Position 1 4)
        ]

testOffsetArithmetic :: Property
testOffsetArithmetic =
  case offsetFromInt maxBound of
    Nothing -> counterexample "maxBound offset construction failed" False
    Just largest ->
      conjoin
        [ advanceOffset (-1) zeroOffset === Nothing
        , advanceOffset 1 largest === Nothing
        , advanceOffset 2 zeroOffset === offsetFromInt 2
        ]

testSpanBounds :: Property
testSpanBounds =
  let source = mkSource (SourceName "span") "abc"
   in case (offsetFromInt 0, offsetFromInt 2, offsetFromInt 3, offsetFromInt 4) of
        (Just zero, Just two, Just three, Just four) ->
          conjoin
            [ property (mkSpan source zero three /= Nothing)
            , mkSpan source two zero === Nothing
            , mkSpan source zero four === Nothing
            ]
        _ -> counterexample "valid offset construction failed" False

testSpanMerging :: Property
testSpanMerging =
  let source = mkSource (SourceName "source") "abcd"
      otherSource = mkSource (SourceName "other") "abcd"
      revisedSource = mkSource (SourceName "source") "abcdefgh"
   in case (spanAt source 0 2, spanAt source 1 4, spanAt otherSource 0 1, spanAt revisedSource 4 8) of
        (Just left, Just right, Just other, Just revised) ->
          conjoin
            [ case mergeSpans left right of
                Just merged ->
                  conjoin
                    [ unOffset (spanStart merged) === 0
                    , unOffset (spanEnd merged) === 4
                    ]
                Nothing -> counterexample "same-source spans did not merge" False
            , mergeSpans left other === Nothing
            , mergeSpans left revised === Nothing
            ]
        _ -> counterexample "test span construction failed" False

testZeroWidthSpans :: Property
testZeroWidthSpans =
  let source = mkSource (SourceName "zero") "abc"
   in case (offsetFromInt 3, zeroWidthSpan source =<< offsetFromInt 3) of
        (Just endOffset, Just atEnd) ->
          let atStart = emptySpan source
           in conjoin
                [ spanSource atStart === SourceName "zero"
                , spanStart atStart === zeroOffset
                , spanEnd atStart === zeroOffset
                , spanStart atEnd === endOffset
                , spanEnd atEnd === endOffset
                ]
        _ -> counterexample "zero-width span construction failed" False

testSourceAccessors :: Property
testSourceAccessors =
  let source = mkSource (SourceName "accessor") "💡"
   in conjoin
        [ sourceName source === SourceName "accessor"
        , sourceText source === "💡"
        ]

propertySourceLength :: Property
propertySourceLength =
  forAll shortText $ \value ->
    unOffset (sourceLength (mkSource (SourceName "property") value)) === Text.length value

propertyValidOffsetsHavePositions :: Property
propertyValidOffsetsHavePositions =
  forAll shortText $ \value ->
    let source = mkSource (SourceName "property") value
     in counterexample (show value) (property (all (hasPosition source) [0 .. Text.length value]))

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
