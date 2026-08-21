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
  , mergeSpans
  , mkSource
  , mkSpan
  , offsetFromInt
  , offsetPosition
  , sourceLength
  , spanEnd
  , spanStart
  , unOffset
  , zeroOffset
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
      , check "offset arithmetic rejects invalid advances" testOffsetArithmetic
      , check "span construction validates bounds" testSpanBounds
      , check "span merging respects source identity" testSpanMerging
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
  positionAt (mkSource (SourceName "crlf") "a\r\nb") 3
    === Just (Position 2 1)

testMixedNewlinePosition :: Property
testMixedNewlinePosition =
  positionAt (mkSource (SourceName "mixed") "a\rb\nc") 4
    === Just (Position 3 1)

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
   in case (spanAt source 0 2, spanAt source 1 4, spanAt otherSource 0 1) of
        (Just left, Just right, Just other) ->
          conjoin
            [ case mergeSpans left right of
                Just merged ->
                  conjoin
                    [ unOffset (spanStart merged) === 0
                    , unOffset (spanEnd merged) === 4
                    ]
                Nothing -> counterexample "same-source spans did not merge" False
            , mergeSpans left other === Nothing
            ]
        _ -> counterexample "test span construction failed" False

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
