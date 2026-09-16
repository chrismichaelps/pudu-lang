{-| @Source.Lexer.Quoted.Module — decodes bounded quoted literals -}
module Pudu.Frontend.Lexer.Quoted (scanQuoted) where

import Data.Char (chr)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Severity (Error), diagnostic, mkDiagnosticCode, withHelp)
import Pudu.Frontend.Lexer.Cursor
  ( CursorMark, LexerCursor, captureSince, consumeScalars, consumeWhile
  , commitHere, cursorAtEnd, cursorOffset, emitToken, emittedTokens, markCursor, peekScalar
  , recordDiagnostic, withoutEmitted
  )
import Pudu.Source (Offset)
import Pudu.Frontend.Token
  ( TemplatePart (..)
  , Token
  , TokenKind (CharLiteral, Invalid, StringLiteral, TemplateLiteral)
  )

data QuoteKind = StringQuote | CharacterQuote
  deriving stock (Eq)

data QuoteState = QuoteState
  { quoteCursor :: !LexerCursor
  , decodedChunks :: ![Text]
  , quoteInvalid :: !Bool
  , quoteParts :: ![TemplatePart]
  }

{-| Scan a quoted literal.

    The scanner for one token is injected rather than imported, because an
    interpolation's expression is lexed by the same scanner as everything else
    and importing it here would tie the whole lexer to one of its own pieces.
    It is the same shape the parser uses for blocks, and for the same reason. -}
scanQuoted :: TokenScanner -> LexerCursor -> Maybe LexerCursor
scanQuoted scanner cursor =
  case peekScalar cursor of
    Just '"' -> beginQuote scanner StringQuote cursor
    Just '\'' -> beginQuote scanner CharacterQuote cursor
    _ -> Nothing

{-| A scanner for one token, which is what an interpolation needs to read its
    expression. -}
type TokenScanner = LexerCursor -> Maybe LexerCursor

beginQuote :: TokenScanner -> QuoteKind -> LexerCursor -> Maybe LexerCursor
beginQuote scanner kind cursor =
  scanBody scanner kind (markCursor cursor) initialState
  where
    initialState = QuoteState (consumeScalars 1 cursor) [] False []

scanBody :: TokenScanner -> QuoteKind -> CursorMark -> QuoteState -> Maybe LexerCursor
scanBody scanner kind opening state@QuoteState{quoteCursor}
  {-| A literal already reported as invalid ends without a second complaint: an
      unterminated interpolation is why the string never closed, and saying so
      twice explains one mistake as two. -}
  | cursorAtEnd quoteCursor || maybe False isLineBreak (peekScalar quoteCursor) =
      if quoteInvalid state
        then emitInvalid opening quoteCursor
        else finishUnterminated kind opening quoteCursor
  | peekScalar quoteCursor == Just (closingDelimiter kind) = finishClosed kind opening state
  | peekScalar quoteCursor == Just '\\' = do
      nextState <- scanEscape kind state
      scanBody scanner kind opening nextState
  | kind == StringQuote
  , peekScalar quoteCursor == Just '{' = do
      nextState <- scanHole scanner state
      scanBody scanner kind opening nextState
  | kind == StringQuote
  , peekScalar quoteCursor == Just '}' = do
      nextState <- rejectBrace state
      scanBody scanner kind opening nextState
  | otherwise =
      let chunkMark = markCursor quoteCursor
          advanced = consumeWhile (isOrdinary kind) quoteCursor
       in do
            (chunk, _) <- captureSince chunkMark advanced
            scanBody scanner kind opening state
              { quoteCursor = advanced, decodedChunks = chunk : decodedChunks state }

{-| Fold the text gathered since the last hole into the parts, so a template
    ends with its trailing text rather than losing it. -}
settle :: QuoteState -> [TemplatePart]
settle state =
  let pending = Text.concat (reverse (decodedChunks state))
   in if Text.null pending then quoteParts state else TemplateText pending : quoteParts state

{-| Scan `{ expression }` inside a string.

    The expression's source is captured rather than lexed here: lexing it needs
    the whole scanner, and calling back into it from a piece of it would tie the
    two together for one construct. The parser reads it instead, which is where
    an expression is read everywhere else.

    Braces nest and a nested string is respected, so `"{ f("}") }"` scans the
    way a reader expects rather than ending at the first `}` it meets. -}
scanHole :: TokenScanner -> QuoteState -> Maybe QuoteState
scanHole scanner state@QuoteState{quoteCursor} = do
  let afterBrace = consumeScalars 1 quoteCursor
      bodyMark = markCursor afterBrace
      alreadyEmitted = emittedTokens afterBrace
  case scanHoleBody 0 False afterBrace of
    Nothing -> unterminatedHole state bodyMark afterBrace
    Just ended -> closeHole scanner state bodyMark afterBrace alreadyEmitted ended

{-| An interpolation that never closes.

    Reported where it opened and consumed to the end of the line, so the string
    it was in is one invalid literal rather than a cascade of tokens made from
    its own text. -}
unterminatedHole :: QuoteState -> CursorMark -> LexerCursor -> Maybe QuoteState
unterminatedHole state bodyMark afterBrace = do
  let ended = consumeWhile (not . isLineBreak) afterBrace
  diagnosed <-
    recordAtWithHelp bodyMark ended "E0010" "an interpolation is not closed"
      (Just "close it with }, or write \\{ for a literal brace")
  pure state{quoteCursor = diagnosed, quoteInvalid = True}

closeHole
  :: TokenScanner
  -> QuoteState
  -> CursorMark
  -> LexerCursor
  -> [Token]
  -> LexerCursor
  -> Maybe QuoteState
closeHole scanner state bodyMark bodyStart alreadyEmitted ended = do
  (body, bodySpan) <- captureSince bodyMark ended
  if Text.null (Text.strip body)
    then do
      diagnosed <-
        recordAtWithHelp bodyMark ended "E0010" "an interpolation has no expression"
          (Just "write an expression between the braces, or \\{ for a literal brace")
      pure state{quoteCursor = consumeScalars 1 diagnosed, quoteInvalid = True}
    else do
      lexed <- scanHoleTokens scanner (cursorOffset ended) (commitHere bodyStart)
      let held = drop (length alreadyEmitted) (emittedTokens lexed)
          resumed = withoutEmitted (quoteCursor state) lexed
      pure
        state
          { quoteCursor = consumeScalars 1 resumed
          , decodedChunks = []
          , quoteParts = TemplateHole bodySpan held : settle state
          }


{-| Lex an interpolation's expression with the ordinary scanner, stopping at the
    brace that closes it.

    The tokens come from the real source at their real positions, so a
    diagnostic about the expression points at the expression rather than at a
    copy of it. -}
scanHoleTokens :: TokenScanner -> Offset -> LexerCursor -> Maybe LexerCursor
scanHoleTokens scanner limit cursor
  | cursorOffset cursor >= limit = Just cursor
  | otherwise = scanner cursor >>= scanHoleTokens scanner limit

{-| Advance to the `}` that closes an interpolation, counting nested braces and
    stepping over a nested string so a brace inside one does not close it. -}
scanHoleBody :: Int -> Bool -> LexerCursor -> Maybe LexerCursor
scanHoleBody depth inString cursor
  | cursorAtEnd cursor = Nothing
  | otherwise = case peekScalar cursor of
      Nothing -> Nothing
      Just scalar
        | inString, scalar == '\\' -> scanHoleBody depth inString (consumeScalars 2 cursor)
        | scalar == '"' -> scanHoleBody depth (not inString) (consumeScalars 1 cursor)
        | inString -> scanHoleBody depth inString (consumeScalars 1 cursor)
        | scalar == '{' -> scanHoleBody (depth + 1) inString (consumeScalars 1 cursor)
        | scalar == '}' ->
            if depth == 0 then Just cursor else scanHoleBody (depth - 1) inString (consumeScalars 1 cursor)
        | isLineBreak scalar -> Nothing
        | otherwise -> scanHoleBody depth inString (consumeScalars 1 cursor)

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
    recordAtWithHelp braceMark advanced "E0008" "a closing brace has no interpolation to close"
      (Just "write \\} for a literal brace")
  pure state{quoteCursor = diagnosed, quoteInvalid = True}

finishClosed :: QuoteKind -> CursorMark -> QuoteState -> Maybe LexerCursor
finishClosed kind opening state =
  let closed = consumeScalars 1 (quoteCursor state)
      decoded = Text.concat (reverse (decodedChunks state))
      parts = reverse (settle state)
   in if quoteInvalid state
        then emitInvalid opening closed
        else case kind of
          StringQuote
            | null (quoteParts state) -> emitToken opening (StringLiteral decoded) closed
            | otherwise -> emitToken opening (TemplateLiteral parts) closed
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
