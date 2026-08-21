{-| @Source.Lexer.Cursor.Module — owns linear lossless source traversal -}
module Pudu.Frontend.Lexer.Cursor
  ( CursorMark
  , LexerCursor
  , LexerOutput
  , captureSince
  , completeCursor
  , consumeScalars
  , cursorAtEnd
  , cursorOffset
  , cursorStartsWith
  , emitToken
  , emitTrivia
  , markCursor
  , newCursor
  , outputDiagnostics
  , outputTokens
  , peekScalar
  , pendingTriviaCount
  , recordDiagnostic
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticSpan, sortDiagnostics)
import Pudu.Frontend.Token
  ( Token (Token, tokenKind, tokenLeadingTrivia, tokenLexeme, tokenSpan)
  , TokenKind (EndOfFile, Invalid)
  , Trivia (Trivia, triviaKind, triviaSpan, triviaText)
  , TriviaKind
  )
import Pudu.Source
  ( Offset
  , Source
  , Span
  , advanceOffset
  , emptySpan
  , mergeSpans
  , sourceLength
  , sourceText
  , spanEnd
  , spanStart
  , unOffset
  , zeroWidthSpan
  )

{-| @Source.Lexer.Cursor.State — preserves one strict traversal snapshot -}
data LexerCursor = LexerCursor
  { cursorSource :: !Source
  , cursorPoint :: !Span
  , cursorCommittedPoint :: !Span
  , cursorSuffix :: !Text
  , cursorTokenValues :: ![Token]
  , cursorDiagnosticValues :: ![Diagnostic]
  , cursorPendingTrivia :: ![Trivia]
  , cursorPendingCount :: !Int
  }

{-| @Source.Lexer.Cursor.Mark — binds a capture start to one source snapshot -}
data CursorMark = CursorMark
  { markPoint :: !Span
  , markSuffix :: !Text
  }

{-| @Source.Lexer.Cursor.Output — exposes one finalized lexical result -}
data LexerOutput = LexerOutput
  { outputTokenValues :: ![Token]
  , outputDiagnosticValues :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

newCursor :: Source -> LexerCursor
newCursor source =
  LexerCursor
    { cursorSource = source
    , cursorPoint = emptySpan source
    , cursorCommittedPoint = emptySpan source
    , cursorSuffix = sourceText source
    , cursorTokenValues = []
    , cursorDiagnosticValues = []
    , cursorPendingTrivia = []
    , cursorPendingCount = 0
    }

cursorOffset :: LexerCursor -> Offset
cursorOffset = spanEnd . cursorPoint

cursorAtEnd :: LexerCursor -> Bool
cursorAtEnd = Text.null . cursorSuffix

peekScalar :: LexerCursor -> Maybe Char
peekScalar = fmap fst . Text.uncons . cursorSuffix

cursorStartsWith :: Text -> LexerCursor -> Bool
cursorStartsWith prefix = Text.isPrefixOf prefix . cursorSuffix

consumeScalars :: Int -> LexerCursor -> LexerCursor
consumeScalars requested cursor
  | requested <= 0 = cursor
  | otherwise =
      let (advanced, remainingText) =
            consumePrefix requested 0 (cursorSuffix cursor)
       in case advancePoint advanced cursor of
            Nothing -> cursor
            Just nextPoint ->
              cursor
                { cursorPoint = nextPoint
                , cursorSuffix = remainingText
                }

markCursor :: LexerCursor -> CursorMark
markCursor LexerCursor{cursorPoint, cursorSuffix} =
  CursorMark{markPoint = cursorPoint, markSuffix = cursorSuffix}

captureSince :: CursorMark -> LexerCursor -> Maybe (Text, Span)
captureSince CursorMark{markPoint, markSuffix} LexerCursor{cursorPoint}
  | spanStart markPoint > spanEnd cursorPoint = Nothing
  | otherwise = do
      capturedSpan <- mergeSpans markPoint cursorPoint
      let width = unOffset (spanEnd cursorPoint) - unOffset (spanStart markPoint)
      pure (Text.take width markSuffix, capturedSpan)

emitTrivia :: CursorMark -> TriviaKind -> LexerCursor -> Maybe LexerCursor
emitTrivia mark kind cursor = do
  (captured, capturedSpan) <- captureCommitted mark cursor
  let trivia = Trivia{triviaKind = kind, triviaText = captured, triviaSpan = capturedSpan}
  pure
    cursor
      { cursorCommittedPoint = cursorPoint cursor
      , cursorPendingTrivia = trivia : cursorPendingTrivia cursor
      , cursorPendingCount = cursorPendingCount cursor + 1
      }

emitToken :: CursorMark -> TokenKind -> LexerCursor -> Maybe LexerCursor
emitToken mark kind cursor = do
  (captured, capturedSpan) <- captureCommitted mark cursor
  if tokenKindAccepts kind captured
    then
      let token =
            Token
              { tokenKind = kind
              , tokenLexeme = captured
              , tokenSpan = capturedSpan
              , tokenLeadingTrivia = reverse (cursorPendingTrivia cursor)
              }
       in Just
            cursor
              { cursorCommittedPoint = cursorPoint cursor
              , cursorTokenValues = token : cursorTokenValues cursor
              , cursorPendingTrivia = []
              , cursorPendingCount = 0
              }
    else Nothing

recordDiagnostic :: Diagnostic -> LexerCursor -> Maybe LexerCursor
recordDiagnostic value cursor
  | spanEnd primary > cursorOffset cursor = Nothing
  | otherwise = do
      _ <- mergeSpans primary (cursorPoint cursor)
      pure cursor{cursorDiagnosticValues = value : cursorDiagnosticValues cursor}
  where
    primary = diagnosticSpan value

pendingTriviaCount :: LexerCursor -> Int
pendingTriviaCount = cursorPendingCount

completeCursor :: LexerCursor -> Maybe LexerOutput
completeCursor cursor
  | not (cursorAtEnd cursor) = Nothing
  | cursorOffset cursor /= sourceLength (cursorSource cursor) = Nothing
  | cursorCommittedPoint cursor /= cursorPoint cursor = Nothing
  | otherwise =
      let eofToken =
            Token
              { tokenKind = EndOfFile
              , tokenLexeme = Text.empty
              , tokenSpan = cursorPoint cursor
              , tokenLeadingTrivia = reverse (cursorPendingTrivia cursor)
              }
       in Just
            LexerOutput
              { outputTokenValues = reverse (eofToken : cursorTokenValues cursor)
              , outputDiagnosticValues =
                  sortDiagnostics (reverse (cursorDiagnosticValues cursor))
              }

outputTokens :: LexerOutput -> [Token]
outputTokens = outputTokenValues

outputDiagnostics :: LexerOutput -> [Diagnostic]
outputDiagnostics = outputDiagnosticValues

consumePrefix :: Int -> Int -> Text -> (Int, Text)
consumePrefix remaining advanced suffix
  | remaining <= 0 = (advanced, suffix)
  | otherwise =
      case Text.uncons suffix of
        Nothing -> (advanced, suffix)
        Just (_, remainingText) ->
          let nextAdvanced = advanced + 1
           in nextAdvanced
                `seq` consumePrefix (remaining - 1) nextAdvanced remainingText

advancePoint :: Int -> LexerCursor -> Maybe Span
advancePoint amount LexerCursor{cursorSource, cursorPoint} = do
  nextOffset <- advanceOffset amount (spanEnd cursorPoint)
  zeroWidthSpan cursorSource nextOffset

captureCommitted :: CursorMark -> LexerCursor -> Maybe (Text, Span)
captureCommitted mark cursor
  | markPoint mark /= cursorCommittedPoint cursor = Nothing
  | otherwise = do
      captured@(_, capturedSpan) <- captureSince mark cursor
      if spanStart capturedSpan < spanEnd capturedSpan
        then Just captured
        else Nothing

tokenKindAccepts :: TokenKind -> Text -> Bool
tokenKindAccepts kind captured =
  case kind of
    EndOfFile -> False
    Invalid rejected -> rejected == captured
    _ -> True
