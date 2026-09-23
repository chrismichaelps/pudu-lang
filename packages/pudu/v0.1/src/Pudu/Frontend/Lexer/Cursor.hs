{-| @Source.Lexer.Cursor.Module — owns linear lossless source traversal -}
module Pudu.Frontend.Lexer.Cursor
  ( CursorMark
  , LexerCursor
  , LexerOutput
  , captureSince
  , completeCursor
  , consumeScalars
  , consumeWhile
  , cursorAtEnd
  , cursorOffset
  , commitHere
  , cursorStartsWith
  , emitToken
  , emitTrivia
  , emittedTokens
  , withoutEmitted
  , markCursor
  , newCursor
  , outputDiagnostics
  , outputTokens
  , peekScalar
  , pendingTriviaCount
  , recordDiagnostic
  ) where

import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Unsafe as Unsafe
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
  , mergeSpans
  , mkSpan
  , offsetFromInt
  , sameSource
  , sourceLength
  , sourceText
  , spanEnd
  , spanStart
  , unOffset
  , zeroOffset
  , zeroWidthSpan
  )

{-| @Source.Lexer.Cursor.State — preserves one strict traversal snapshot

    A position is a byte index into the source's own text and the scalar index
    it corresponds to. Reading a character reads it in place, advancing moves
    two numbers, and a lexeme is a slice of the source rather than a copy of
    it: nothing is allocated for a character the lexer passes over, and a span
    is made only when a token or a piece of trivia is emitted. -}
data LexerCursor = LexerCursor
  { cursorSource :: !Source
  , cursorText :: !Text
  , cursorByte :: !Int
  , cursorScalar :: !Int
  , cursorCommittedScalar :: !Int
  , cursorTokenValues :: ![Token]
  , cursorDiagnosticValues :: ![Diagnostic]
  , cursorPendingTrivia :: ![Trivia]
  , cursorPendingCount :: !Int
  }

{-| @Source.Lexer.Cursor.Mark — binds a capture start to one source snapshot -}
data CursorMark = CursorMark
  { markSource :: !Source
  , markByte :: !Int
  , markScalar :: !Int
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
    , cursorText = sourceText source
    , cursorByte = 0
    , cursorScalar = 0
    , cursorCommittedScalar = 0
    , cursorTokenValues = []
    , cursorDiagnosticValues = []
    , cursorPendingTrivia = []
    , cursorPendingCount = 0
    }

cursorOffset :: LexerCursor -> Offset
cursorOffset = offsetAt . cursorScalar

offsetAt :: Int -> Offset
offsetAt = fromMaybe zeroOffset . offsetFromInt

cursorAtEnd :: LexerCursor -> Bool
cursorAtEnd cursor = cursorByte cursor >= Unsafe.lengthWord8 (cursorText cursor)
{-# INLINE cursorAtEnd #-}

peekScalar :: LexerCursor -> Maybe Char
peekScalar cursor
  | cursorAtEnd cursor = Nothing
  | otherwise = case Unsafe.iter (cursorText cursor) (cursorByte cursor) of
      Unsafe.Iter character _ -> Just character
{-# INLINE peekScalar #-}

cursorStartsWith :: Text -> LexerCursor -> Bool
cursorStartsWith prefix cursor =
  Text.isPrefixOf prefix (Unsafe.dropWord8 (cursorByte cursor) (cursorText cursor))

consumeScalars :: Int -> LexerCursor -> LexerCursor
consumeScalars requested cursor
  | requested <= 0 = cursor
  | otherwise = go requested (cursorByte cursor) (cursorScalar cursor)
 where
  text = cursorText cursor
  size = Unsafe.lengthWord8 text
  go remaining byte scalar
    | remaining <= 0 || byte >= size = moved cursor byte scalar
    | otherwise =
        let Unsafe.Iter _ width = Unsafe.iter text byte
         in go (remaining - 1) (byte + width) (scalar + 1)

consumeWhile :: (Char -> Bool) -> LexerCursor -> LexerCursor
consumeWhile predicate cursor = go (cursorByte cursor) (cursorScalar cursor)
 where
  text = cursorText cursor
  size = Unsafe.lengthWord8 text
  go byte scalar
    | byte >= size = moved cursor byte scalar
    | otherwise =
        let Unsafe.Iter character width = Unsafe.iter text byte
         in if predicate character
              then go (byte + width) (scalar + 1)
              else moved cursor byte scalar
{-# INLINE consumeWhile #-}

moved :: LexerCursor -> Int -> Int -> LexerCursor
moved cursor byte scalar
  | byte == cursorByte cursor = cursor
  | otherwise = cursor{cursorByte = byte, cursorScalar = scalar}
{-# INLINE moved #-}

markCursor :: LexerCursor -> CursorMark
markCursor cursor =
  CursorMark
    { markSource = cursorSource cursor
    , markByte = cursorByte cursor
    , markScalar = cursorScalar cursor
    }

captureSince :: CursorMark -> LexerCursor -> Maybe (Text, Span)
captureSince CursorMark{markSource, markByte, markScalar} cursor
  | not (sameSource markSource (cursorSource cursor)) = Nothing
  | markScalar > cursorScalar cursor = Nothing
  | otherwise = do
      capturedSpan <- spanBetween (cursorSource cursor) markScalar (cursorScalar cursor)
      let captured =
            Unsafe.takeWord8 (cursorByte cursor - markByte)
              (Unsafe.dropWord8 markByte (cursorText cursor))
      pure (captured, capturedSpan)

spanBetween :: Source -> Int -> Int -> Maybe Span
spanBetween source start end = do
  from <- offsetFromInt start
  to <- offsetFromInt end
  mkSpan source from to

emitTrivia :: CursorMark -> TriviaKind -> LexerCursor -> Maybe LexerCursor
emitTrivia mark kind cursor = do
  (captured, capturedSpan) <- captureCommitted mark cursor
  let trivia = Trivia{triviaKind = kind, triviaText = captured, triviaSpan = capturedSpan}
  pure
    cursor
      { cursorCommittedScalar = cursorScalar cursor
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
              { cursorCommittedScalar = cursorScalar cursor
              , cursorTokenValues = token : cursorTokenValues cursor
              , cursorPendingTrivia = []
              , cursorPendingCount = 0
              }
    else Nothing

recordDiagnostic :: Diagnostic -> LexerCursor -> Maybe LexerCursor
recordDiagnostic value cursor
  | spanEnd primary > cursorOffset cursor = Nothing
  | otherwise = do
      here <- zeroWidthSpan (cursorSource cursor) (cursorOffset cursor)
      _ <- mergeSpans primary here
      pure cursor{cursorDiagnosticValues = value : cursorDiagnosticValues cursor}
  where
    primary = diagnosticSpan value

pendingTriviaCount :: LexerCursor -> Int
pendingTriviaCount = cursorPendingCount

{-| The tokens a cursor has emitted, oldest first.

    An interpolation's expression is lexed by the same scanner as everything
    else, from the same source, so its tokens carry real spans. Reading them
    back out is how they reach the part that keeps them. -}
emittedTokens :: LexerCursor -> [Token]
emittedTokens = reverse . cursorTokenValues

{-| A cursor whose commit point is where it stands.

    Emitting a token captures the text since the last commit, so a scanner
    entering the middle of a literal — which is where an interpolation's
    expression begins — has to say that the text before it is already
    accounted for. -}
commitHere :: LexerCursor -> LexerCursor
commitHere cursor = cursor{cursorCommittedScalar = cursorScalar cursor}

{-| A cursor advanced to a new position, but with the token bookkeeping of an
    earlier one.

    An interpolation's tokens belong to the part, not to the stream: leaving
    them in it would make the string's own token be followed by the tokens of
    its inside. The commit point has to come back too, or the string literal
    that encloses them can no longer capture its own lexeme. Diagnostics stay,
    because a mistake inside an interpolation is a mistake in the program. -}
withoutEmitted :: LexerCursor -> LexerCursor -> LexerCursor
withoutEmitted before after =
  after
    { cursorTokenValues = cursorTokenValues before
    , cursorCommittedScalar = cursorCommittedScalar before
    , cursorPendingTrivia = cursorPendingTrivia before
    , cursorPendingCount = cursorPendingCount before
    }

completeCursor :: LexerCursor -> Maybe LexerOutput
completeCursor cursor
  | not (cursorAtEnd cursor) = Nothing
  | cursorOffset cursor /= sourceLength (cursorSource cursor) = Nothing
  | cursorCommittedScalar cursor /= cursorScalar cursor = Nothing
  | otherwise = do
      here <- zeroWidthSpan (cursorSource cursor) (cursorOffset cursor)
      let eofToken =
            Token
              { tokenKind = EndOfFile
              , tokenLexeme = Text.empty
              , tokenSpan = here
              , tokenLeadingTrivia = reverse (cursorPendingTrivia cursor)
              }
      Just
        LexerOutput
          { outputTokenValues = reverse (eofToken : cursorTokenValues cursor)
          , outputDiagnosticValues =
              sortDiagnostics (reverse (cursorDiagnosticValues cursor))
          }

outputTokens :: LexerOutput -> [Token]
outputTokens = outputTokenValues

outputDiagnostics :: LexerOutput -> [Diagnostic]
outputDiagnostics = outputDiagnosticValues

captureCommitted :: CursorMark -> LexerCursor -> Maybe (Text, Span)
captureCommitted mark cursor
  | not (sameSource (markSource mark) (cursorSource cursor)) = Nothing
  | markScalar mark /= cursorCommittedScalar cursor = Nothing
  | otherwise = do
      captured@(_, capturedSpan) <- captureSince mark cursor
      if unOffset (spanStart capturedSpan) < unOffset (spanEnd capturedSpan)
        then Just captured
        else Nothing

tokenKindAccepts :: TokenKind -> Text -> Bool
tokenKindAccepts kind captured =
  case kind of
    EndOfFile -> False
    Invalid rejected -> rejected == captured
    _ -> True
