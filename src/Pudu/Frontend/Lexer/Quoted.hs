{-| @Source.Lexer.Quoted.Module — decodes bounded quoted literals -}
module Pudu.Frontend.Lexer.Quoted (scanQuoted) where

import Data.Char (chr)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Severity (Error), diagnostic, mkDiagnosticCode, withHelp)
import Pudu.Frontend.Lexer.Cursor
  ( CursorMark, LexerCursor, captureSince, consumeScalars, consumeWhile
  , cursorAtEnd, emitToken, markCursor, peekScalar, recordDiagnostic
  )
import Pudu.Frontend.Token
  ( TokenKind (CharLiteral, Invalid, StringLiteral) )

data QuoteKind = StringQuote | CharacterQuote
  deriving stock (Eq)

data QuoteState = QuoteState
  { quoteCursor :: !LexerCursor, decodedChunks :: ![Text], quoteInvalid :: !Bool }

scanQuoted :: LexerCursor -> Maybe LexerCursor
scanQuoted cursor =
  case peekScalar cursor of
    Just '"' -> beginQuote StringQuote cursor
    Just '\'' -> beginQuote CharacterQuote cursor
    _ -> Nothing

beginQuote :: QuoteKind -> LexerCursor -> Maybe LexerCursor
beginQuote kind cursor =
  scanBody kind (markCursor cursor) initialState
  where
    initialState = QuoteState (consumeScalars 1 cursor) [] False

scanBody :: QuoteKind -> CursorMark -> QuoteState -> Maybe LexerCursor
scanBody kind opening state@QuoteState{quoteCursor}
  | cursorAtEnd quoteCursor = finishUnterminated kind opening quoteCursor
  | maybe False isLineBreak (peekScalar quoteCursor) = finishUnterminated kind opening quoteCursor
  | peekScalar quoteCursor == Just (closingDelimiter kind) = finishClosed kind opening state
  | peekScalar quoteCursor == Just '\\' = do
      nextState <- scanEscape kind state
      scanBody kind opening nextState
  | kind == StringQuote
  , maybe False isBrace (peekScalar quoteCursor) = do
      nextState <- rejectBrace state
      scanBody kind opening nextState
  | otherwise =
      let chunkMark = markCursor quoteCursor
          advanced = consumeWhile (isOrdinary kind) quoteCursor
       in do
            (chunk, _) <- captureSince chunkMark advanced
            scanBody kind opening state
              { quoteCursor = advanced, decodedChunks = chunk : decodedChunks state }

scanEscape :: QuoteKind -> QuoteState -> Maybe QuoteState
scanEscape kind state@QuoteState{quoteCursor} =
  let escapeMark = markCursor quoteCursor
      afterSlash = consumeScalars 1 quoteCursor
   in case peekScalar afterSlash of
        Just 'u' ->
          if peekScalar (consumeScalars 1 afterSlash) == Just '{'
            then scanUnicodeEscape kind escapeMark state afterSlash
            else rejectEscape escapeMark state (consumeScalars 1 afterSlash) "E0005" "invalid escape sequence"
        Just scalar ->
          case simpleEscape kind scalar of
            Just decoded -> Just state
              { quoteCursor = consumeScalars 1 afterSlash
              , decodedChunks = Text.singleton decoded : decodedChunks state }
            Nothing
              | isLineBreak scalar || scalar == closingDelimiter kind ->
                  rejectEscape escapeMark state afterSlash "E0005" "invalid escape sequence"
              | otherwise ->
                  rejectEscape escapeMark state (consumeScalars 1 afterSlash) "E0005" "invalid escape sequence"
        Nothing ->
          rejectEscape escapeMark state afterSlash "E0005" "invalid escape sequence"

scanUnicodeEscape :: QuoteKind -> CursorMark -> QuoteState -> LexerCursor -> Maybe QuoteState
scanUnicodeEscape kind escapeMark state afterU = do
  let afterOpenBrace = consumeScalars 2 afterU
      digitsMark = markCursor afterOpenBrace
      afterDigits = consumeWhile (isUnicodeEscapeBody kind) afterOpenBrace
      closed = peekScalar afterDigits == Just '}'
      advanced = if closed then consumeScalars 1 afterDigits else afterDigits
  (digits, _) <- captureSince digitsMark afterDigits
  case if closed then decodeUnicode digits else Nothing of
    Just scalar -> Just state
      { quoteCursor = advanced, decodedChunks = Text.singleton scalar : decodedChunks state }
    Nothing -> rejectEscape escapeMark state advanced "E0006" "invalid Unicode escape"

rejectEscape :: CursorMark -> QuoteState -> LexerCursor -> Text -> Text -> Maybe QuoteState
rejectEscape diagnosticMark state advanced code message = do
  diagnosed <- recordAt diagnosticMark advanced code message
  pure state{quoteCursor = diagnosed, quoteInvalid = True}

rejectBrace :: QuoteState -> Maybe QuoteState
rejectBrace state@QuoteState{quoteCursor} = do
  let braceMark = markCursor quoteCursor
      advanced = consumeScalars 1 quoteCursor
  diagnosed <-
    recordAtWithHelp braceMark advanced "E0008" "string interpolation is reserved"
      (Just "write \\{ for a literal brace")
  pure state{quoteCursor = diagnosed, quoteInvalid = True}

finishClosed :: QuoteKind -> CursorMark -> QuoteState -> Maybe LexerCursor
finishClosed kind opening state =
  let closed = consumeScalars 1 (quoteCursor state)
      decoded = Text.concat (reverse (decodedChunks state))
   in if quoteInvalid state
        then emitInvalid opening closed
        else case kind of
          StringQuote -> emitToken opening (StringLiteral decoded) closed
          CharacterQuote ->
            case Text.uncons decoded of
              Just (scalar, remaining)
                | Text.null remaining -> emitToken opening (CharLiteral scalar) closed
              _ -> do
                diagnosed <- recordAt opening closed "E0007"
                  "character literal must contain exactly one Unicode scalar value"
                emitInvalid opening diagnosed

finishUnterminated :: QuoteKind -> CursorMark -> LexerCursor -> Maybe LexerCursor
finishUnterminated kind opening cursor = do
  emitted <- emitInvalid opening cursor
  recordAt opening emitted "E0002" (unterminatedMessage kind)

emitInvalid :: CursorMark -> LexerCursor -> Maybe LexerCursor
emitInvalid opening cursor = do
  (lexeme, _) <- captureSince opening cursor
  emitToken opening (Invalid lexeme) cursor

recordAt :: CursorMark -> LexerCursor -> Text -> Text -> Maybe LexerCursor
recordAt diagnosticMark cursor codeText message =
  recordAtWithHelp diagnosticMark cursor codeText message Nothing

recordAtWithHelp
  :: CursorMark -> LexerCursor -> Text -> Text -> Maybe Text -> Maybe LexerCursor
recordAtWithHelp diagnosticMark cursor codeText message help = do
  (_, spanValue) <- captureSince diagnosticMark cursor
  code <- mkDiagnosticCode codeText
  value <- diagnostic code Error spanValue message
  recordDiagnostic (maybe value (`withHelp` value) help) cursor

decodeUnicode :: Text -> Maybe Char
decodeUnicode digits
  | digitCount < 1 || digitCount > 6 = Nothing
  | otherwise = do
      value <- Text.foldl' accumulateHex (Just 0) digits
      if value > 0x10FFFF || (value >= 0xD800 && value <= 0xDFFF)
        then Nothing
        else Just (chr (fromInteger value))
  where
    digitCount = Text.length digits

accumulateHex :: Maybe Integer -> Char -> Maybe Integer
accumulateHex Nothing _ = Nothing
accumulateHex (Just total) scalar = do
  digit <- hexValue scalar
  let next = total * 16 + digit
  next `seq` Just next

hexValue :: Char -> Maybe Integer
hexValue scalar
  | scalar >= '0' && scalar <= '9' = Just (toInteger (fromEnum scalar - fromEnum '0'))
  | scalar >= 'a' && scalar <= 'f' = Just (toInteger (fromEnum scalar - fromEnum 'a' + 10))
  | scalar >= 'A' && scalar <= 'F' = Just (toInteger (fromEnum scalar - fromEnum 'A' + 10))
  | otherwise = Nothing

simpleEscape :: QuoteKind -> Char -> Maybe Char
simpleEscape kind scalar =
  case scalar of
    'n' -> Just '\n'
    'r' -> Just '\r'
    't' -> Just '\t'
    '\\' -> Just '\\'
    '"' -> Just '"'
    '\'' | kind == CharacterQuote -> Just '\''
    '0' -> Just '\0'
    {-| A brace is reserved inside a string so interpolation can be added
        without changing what existing programs mean. Escaping it is how a
        program writes one today: JSON, a shell snippet, and a code template
        all contain braces, and until the escape existed none of them could be
        written as a literal at all. -}
    '{' -> Just '{'
    '}' -> Just '}'
    _ -> Nothing

closingDelimiter :: QuoteKind -> Char
closingDelimiter StringQuote = '"'
closingDelimiter CharacterQuote = '\''

unterminatedMessage :: QuoteKind -> Text
unterminatedMessage StringQuote = "unterminated string literal"
unterminatedMessage CharacterQuote = "unterminated character literal"

isOrdinary :: QuoteKind -> Char -> Bool
isOrdinary kind scalar =
  scalar /= closingDelimiter kind
    && scalar /= '\\'
    && not (isLineBreak scalar)
    && (kind /= StringQuote || not (isBrace scalar))

isUnicodeEscapeBody :: QuoteKind -> Char -> Bool
isUnicodeEscapeBody kind scalar =
  scalar /= '}' && scalar /= closingDelimiter kind && not (isLineBreak scalar)

isLineBreak :: Char -> Bool
isLineBreak scalar = scalar == '\r' || scalar == '\n'

isBrace :: Char -> Bool
isBrace scalar = scalar == '{' || scalar == '}'
