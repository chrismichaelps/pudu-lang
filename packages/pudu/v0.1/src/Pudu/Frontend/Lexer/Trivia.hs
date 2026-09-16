{-| @Source.Lexer.Trivia.Module — preserves whitespace and comments -}
module Pudu.Frontend.Lexer.Trivia (scanTrivia) where

import Data.Char (isSpace)
import Pudu.Diagnostic (Severity (Error), diagnostic, mkDiagnosticCode)
import Pudu.Frontend.Lexer.Cursor
  ( CursorMark, LexerCursor, captureSince, consumeScalars, consumeWhile
  , cursorAtEnd, cursorOffset, cursorStartsWith, emitTrivia, markCursor
  , peekScalar, recordDiagnostic
  )
import Pudu.Frontend.Token (TriviaKind (BlockComment, DocComment, LineComment, Whitespace))

scanTrivia :: LexerCursor -> Maybe LexerCursor
scanTrivia cursor
  | maybe False isSpace (peekScalar cursor) = scanWhitespace cursor
  | cursorStartsWith "////" cursor = scanLineComment cursor
  | cursorStartsWith "///" cursor = scanDocLine cursor
  | cursorStartsWith "//" cursor = scanLineComment cursor
  | cursorStartsWith "/**/" cursor = scanBlockComment cursor
  | cursorStartsWith "/**" cursor = scanBlockComment' DocComment cursor
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

{-| A `///` line documents what follows it. A `////` ruler does not: a row of
    slashes is a visual separator, and treating it as documentation would attach
    a line of noise to the next declaration. -}
scanDocLine :: LexerCursor -> Maybe LexerCursor
scanDocLine cursor =
  let mark = markCursor cursor
      body = consumeWhile (not . isLineBreak) (consumeScalars 3 cursor)
   in emitTrivia mark DocComment body

scanBlockComment :: LexerCursor -> Maybe LexerCursor
scanBlockComment = scanBlockComment' BlockComment

scanBlockComment' :: TriviaKind -> LexerCursor -> Maybe LexerCursor
scanBlockComment' kind cursor =
  let mark = markCursor cursor
   in scanBlockDepth' kind mark 1 (consumeScalars 2 cursor)

scanBlockDepth' :: TriviaKind -> CursorMark -> Int -> LexerCursor -> Maybe LexerCursor
scanBlockDepth' kind mark depth cursor
  | cursorAtEnd cursor = emitUnterminated mark cursor
  | cursorStartsWith "/*" cursor =
      let nextDepth = depth + 1
       in nextDepth `seq` scanBlockDepth' kind mark nextDepth (consumeScalars 2 cursor)
  | cursorStartsWith "*/" cursor =
      let advanced = consumeScalars 2 cursor
       in if depth == 1
            then emitTrivia mark kind advanced
            else scanBlockDepth' kind mark (depth - 1) advanced
  | otherwise =
      let chunk = consumeWhile isBlockBodyScalar cursor
          advanced =
            if cursorOffset chunk == cursorOffset cursor
              then consumeScalars 1 cursor
              else chunk
       in scanBlockDepth' kind mark depth advanced

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
