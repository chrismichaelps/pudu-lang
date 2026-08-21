{-| @Source.Lexer.Trivia.Module — preserves whitespace and comments -}
module Pudu.Frontend.Lexer.Trivia (scanTrivia) where

import Data.Char (isSpace)
import Pudu.Diagnostic (Severity (Error), diagnostic, mkDiagnosticCode)
import Pudu.Frontend.Lexer.Cursor
  ( CursorMark, LexerCursor, captureSince, consumeScalars, consumeWhile
  , cursorAtEnd, cursorOffset, cursorStartsWith, emitTrivia, markCursor
  , peekScalar, recordDiagnostic
  )
import Pudu.Frontend.Token (TriviaKind (BlockComment, LineComment, Whitespace))

scanTrivia :: LexerCursor -> Maybe LexerCursor
scanTrivia cursor
  | maybe False isSpace (peekScalar cursor) = scanWhitespace cursor
  | cursorStartsWith "//" cursor = scanLineComment cursor
  | cursorStartsWith "/*" cursor = scanBlockComment cursor
  | otherwise = Nothing

scanWhitespace :: LexerCursor -> Maybe LexerCursor
scanWhitespace cursor =
  emitTrivia (markCursor cursor) Whitespace (consumeWhile isSpace cursor)

scanLineComment :: LexerCursor -> Maybe LexerCursor
scanLineComment cursor =
  let mark = markCursor cursor
      body = consumeWhile (not . isLineBreak) (consumeScalars 2 cursor)
   in emitTrivia mark LineComment body

scanBlockComment :: LexerCursor -> Maybe LexerCursor
scanBlockComment cursor =
  let mark = markCursor cursor
   in scanBlockDepth mark 1 (consumeScalars 2 cursor)

scanBlockDepth :: CursorMark -> Int -> LexerCursor -> Maybe LexerCursor
scanBlockDepth mark depth cursor
  | cursorAtEnd cursor = emitUnterminated mark cursor
  | cursorStartsWith "/*" cursor =
      let nextDepth = depth + 1
       in nextDepth `seq` scanBlockDepth mark nextDepth (consumeScalars 2 cursor)
  | cursorStartsWith "*/" cursor =
      let advanced = consumeScalars 2 cursor
       in if depth == 1
            then emitTrivia mark BlockComment advanced
            else scanBlockDepth mark (depth - 1) advanced
  | otherwise =
      let chunk = consumeWhile isBlockBodyScalar cursor
          advanced =
            if cursorOffset chunk == cursorOffset cursor
              then consumeScalars 1 cursor
              else chunk
       in scanBlockDepth mark depth advanced

emitUnterminated :: CursorMark -> LexerCursor -> Maybe LexerCursor
emitUnterminated mark cursor = do
  emitted <- emitTrivia mark BlockComment cursor
  case captureSince mark emitted of
    Just (_, spanValue) ->
      case mkDiagnosticCode "E0003" >>= \code -> diagnostic code Error spanValue "unterminated block comment" of
        Just value -> recordDiagnostic value emitted
        Nothing -> Just emitted
    Nothing -> Just emitted

isLineBreak :: Char -> Bool
isLineBreak scalar = scalar == '\r' || scalar == '\n'

isBlockBodyScalar :: Char -> Bool
isBlockBodyScalar scalar = scalar /= '/' && scalar /= '*'
