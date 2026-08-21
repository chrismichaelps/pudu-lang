module Pudu.Frontend.Lexer.CursorSpec (cursorProperties) where

import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Diagnostic, Related (Related), Severity (Error), diagnostic
  , diagnosticCode, diagnosticCodeText, mkDiagnosticCode, withRelated
  )
import Pudu.Frontend.Lexer.Cursor
  ( LexerCursor, captureSince, completeCursor, consumeScalars, cursorAtEnd
  , cursorOffset, cursorStartsWith, emitToken, emitTrivia, markCursor, newCursor
  , outputDiagnostics, outputTokens, peekScalar, pendingTriviaCount, recordDiagnostic
  )
import Pudu.Frontend.Token
  ( Token, TokenKind (EndOfFile, Identifier, Invalid), TriviaKind (LineComment, Whitespace)
  , tokenKind, tokenLeadingTrivia, tokenLexeme, triviaText
  )
import Pudu.Source
  ( Source, SourceName (SourceName), Span, emptySpan, mkSpan, newSource
  , offsetFromInt, spanEnd, spanStart, unOffset
  )
import Test.QuickCheck
  ( Property, conjoin, counterexample, elements, forAll, ioProperty, listOf
  , property, (===)
  )

cursorProperties :: [(String, IO Property)]
cursorProperties =
  [ ("cursor consumes Unicode scalars without overshoot", testScalarConsumption)
  , ("cursor captures only forward same-snapshot text", testCaptureIdentity)
  , ("emission rejects gaps overlap and invalid payload drift", testEmissionGuards)
  , ("lossless tokens and trivia reconstruct source", testLosslessCompletion)
  , ("empty and incomplete cursors finalize safely", testCompletionBoundaries)
  , ("diagnostics validate snapshots and sort at completion", testDiagnostics)
  , ("generated consumption clamps at EOF", propertyConsumptionClamps)
  , ("large source traversal remains structurally linear", testLargeTraversal)
  ]

testScalarConsumption :: IO Property
testScalarConsumption = do
  source <- newSource (SourceName "unicode.pudu") "a💡e\x0301"
  let initial = newCursor source
      middle = consumeScalars 2 initial
      finished = consumeScalars maxBound middle
  pure
    ( conjoin
        [ unOffset (cursorOffset (consumeScalars 0 initial)) === 0
        , unOffset (cursorOffset (consumeScalars (-1) initial)) === 0
        , peekScalar initial === Just 'a'
        , cursorStartsWith "a💡" initial === True
        , unOffset (cursorOffset middle) === 2
        , peekScalar middle === Just 'e'
        , unOffset (cursorOffset finished) === 4
        , cursorAtEnd finished === True
        ]
    )

testCaptureIdentity :: IO Property
testCaptureIdentity = do
  source <- newSource (SourceName "capture.pudu") "abc"
  duplicate <- newSource (SourceName "capture.pudu") "abc"
  let initial = newCursor source
      start = markCursor initial
      advanced = consumeScalars 2 initial
      later = markCursor advanced
      foreignMark = markCursor (newCursor duplicate)
  pure $ case captureSince start advanced of
    Just (textValue, spanValue) ->
      conjoin
        [ textValue === "ab"
        , unOffset (spanStart spanValue) === 0
        , unOffset (spanEnd spanValue) === 2
        , captureSince later initial === Nothing
        , captureSince foreignMark advanced === Nothing
        ]
    Nothing -> counterexample "same-snapshot capture failed" False

testEmissionGuards :: IO Property
testEmissionGuards = do
  source <- newSource (SourceName "guards.pudu") "ab"
  invalidSource <- newSource (SourceName "invalid.pudu") "@"
  let initial = newCursor source
      start = markCursor initial
      afterA = consumeScalars 1 initial
      gap = markCursor afterA
      afterB = consumeScalars 1 afterA
      invalidInitial = newCursor invalidSource
      invalidMark = markCursor invalidInitial
      invalidEnd = consumeScalars 1 invalidInitial
  pure
    ( conjoin
        [ rejects (emitToken start (Identifier "") initial)
        , rejects (emitToken gap (Identifier "b") afterB)
        , case emitTrivia start Whitespace afterA of
            Just afterTrivia ->
              let finished = consumeScalars 1 afterTrivia
               in conjoin
                    [ pendingTriviaCount afterTrivia === 1
                    , rejects (emitToken start (Identifier "ab") finished)
                    , case emitToken (markCursor afterTrivia) (Identifier "b") finished of
                        Just afterToken -> pendingTriviaCount afterToken === 0
                        Nothing -> counterexample "valid token emission failed" False
                    ]
            Nothing -> counterexample "valid trivia emission failed" False
        , rejects (emitToken invalidMark EndOfFile invalidEnd)
        , rejects (emitToken invalidMark (Invalid "!") invalidEnd)
        , property (isJust (emitToken invalidMark (Invalid "@") invalidEnd))
        ]
    )

testLosslessCompletion :: IO Property
testLosslessCompletion = do
  source <- newSource (SourceName "lossless.pudu") " //x\nname@"
  pure $ case buildLossless (newCursor source) >>= completeCursor of
    Just output -> case outputTokens output of
      [nameToken, invalidToken, eof] ->
        conjoin
          [ map tokenKind [nameToken, invalidToken, eof] === [Identifier "name", Invalid "@", EndOfFile]
          , Text.concat (map reconstruct [nameToken, invalidToken, eof]) === " //x\nname@"
          , map triviaText (tokenLeadingTrivia nameToken) === [" ", "//x", "\n"]
          ]
      _ -> counterexample "completion returned unexpected tokens" False
    Nothing -> counterexample "lossless fixture did not complete" False

testCompletionBoundaries :: IO Property
testCompletionBoundaries = do
  empty <- newSource (SourceName "empty.pudu") Text.empty
  source <- newSource (SourceName "incomplete.pudu") "x"
  trailingSource <- newSource (SourceName "trailing.pudu") " "
  let emptyCursor = newCursor empty
      incomplete = newCursor source
      consumed = consumeScalars 1 incomplete
      trailingOutput = takeTrivia 1 Whitespace (newCursor trailingSource) >>= completeCursor
  pure $ case (completeCursor emptyCursor, trailingOutput) of
    (Just output, Just trailing) ->
      conjoin
        [ map tokenKind (outputTokens output) === [EndOfFile]
        , map triviaText (concatMap tokenLeadingTrivia (outputTokens trailing)) === [" "]
        , rejects (completeCursor incomplete)
        , rejects (completeCursor consumed)
        ]
    _ -> counterexample "empty or trailing-trivia cursor did not complete" False

testDiagnostics :: IO Property
testDiagnostics = do
  source <- newSource (SourceName "diagnostics.pudu") Text.empty
  foreignSource <- newSource (SourceName "foreign.pudu") Text.empty
  futureSource <- newSource (SourceName "future.pudu") "x"
  let cursor = newCursor source
      foreignPoint = emptySpan foreignSource
      futureCursor = newCursor futureSource
      secondResult = makeDiagnostic "E0002" (emptySpan source)
      firstResult = makeDiagnostic "E0001" (emptySpan source)
      foreignResult = makeDiagnostic "E0001" foreignPoint
  pure $ case (secondResult, firstResult, foreignResult, spanAt futureSource 0 1) of
    (Just second, Just first, Just foreignDiagnostic, Just futureSpan) ->
      let contextual = withRelated (Related foreignPoint "foreign context") second
          completed = recordDiagnostic contextual cursor >>= recordDiagnostic first >>= completeCursor
          futureDiagnostic = makeDiagnostic "E0001" futureSpan
       in case completed of
            Just output ->
              conjoin
                [ map (diagnosticCodeText . diagnosticCode) (outputDiagnostics output) === ["E0001", "E0002"]
                , rejects (recordDiagnostic foreignDiagnostic cursor)
                , case futureDiagnostic of
                    Just value -> rejects (recordDiagnostic value futureCursor)
                    Nothing -> counterexample "future diagnostic construction failed" False
                ]
            Nothing -> counterexample "diagnostic cursor did not complete" False
    _ -> counterexample "diagnostic fixture construction failed" False

propertyConsumptionClamps :: IO Property
propertyConsumptionClamps =
  pure $ forAll (listOf (elements ['a', '💡', '\x0301', '\n'])) $ \scalars ->
    ioProperty $ do
      source <- newSource (SourceName "generated.pudu") (Text.pack scalars)
      let finished = consumeScalars maxBound (newCursor source)
      pure
        ( conjoin
            [ unOffset (cursorOffset finished) === length scalars
            , cursorAtEnd finished === True
            ]
        )

testLargeTraversal :: IO Property
testLargeTraversal = do
  source <- newSource (SourceName "large.pudu") (Text.replicate 10000 "a")
  let finished = consumeScalars maxBound (newCursor source)
  pure (conjoin [unOffset (cursorOffset finished) === 10000, cursorAtEnd finished === True])

buildLossless :: LexerCursor -> Maybe LexerCursor
buildLossless cursor = do
  afterSpace <- takeTrivia 1 Whitespace cursor
  afterComment <- takeTrivia 3 LineComment afterSpace
  afterNewline <- takeTrivia 1 Whitespace afterComment
  afterName <- takeToken 4 (Identifier "name") afterNewline
  takeToken 1 (Invalid "@") afterName
takeTrivia :: Int -> TriviaKind -> LexerCursor -> Maybe LexerCursor
takeTrivia amount kind cursor = emitTrivia (markCursor cursor) kind (consumeScalars amount cursor)
takeToken :: Int -> TokenKind -> LexerCursor -> Maybe LexerCursor
takeToken amount kind cursor = emitToken (markCursor cursor) kind (consumeScalars amount cursor)
makeDiagnostic :: Text -> Span -> Maybe Diagnostic
makeDiagnostic code spanValue = mkDiagnosticCode code >>= \valid -> diagnostic valid Error spanValue "lexical failure"
spanAt :: Source -> Int -> Int -> Maybe Span
spanAt source start end = do
  startOffset <- offsetFromInt start
  endOffset <- offsetFromInt end
  mkSpan source startOffset endOffset
reconstruct :: Token -> Text
reconstruct token = Text.concat (map triviaText (tokenLeadingTrivia token)) <> tokenLexeme token

rejects :: Maybe value -> Property
rejects = property . not . isJust
