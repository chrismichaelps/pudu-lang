{-| @Source.Lexer.Number.Module — validates textual numeric literals -}
module Pudu.Frontend.Lexer.Number (scanNumber) where

import Data.Char (isAsciiLower, isAsciiUpper)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Severity (Error), diagnostic, mkDiagnosticCode)
import Pudu.Frontend.Lexer.Cursor
  ( CursorMark, LexerCursor, captureSince, consumeScalars, consumeWhile
  , cursorStartsWith, emitToken, markCursor, peekScalar, recordDiagnostic
  )
import Pudu.Frontend.Token
  ( TokenKind (DecimalLiteral, FloatLiteral, IntegerLiteral, Invalid) )
import Pudu.DecimalLiteral (decimalSuffix)
import Pudu.FloatLiteral (floatSuffix)
import Pudu.IntegerLiteral (integerSuffix, splitIntegerSuffix)

data NumberScan = NumberScan
  { scannedCursor :: !LexerCursor
  , scannedValid :: !Bool
  , scannedForm :: !NumberForm
  }

{-| What a numeric literal turned out to be.

    The shape of the digits decides between an integer and a float, and a
    suffix can override the result: `d` selects `Decimal` whether or not the
    digits carry a fraction, because `1d` and `1.5d` are the same type and only
    one of them has a point in it. -}
data NumberForm = IntegerForm | FloatForm | DecimalForm
  deriving stock (Eq)

scanNumber :: LexerCursor -> Maybe LexerCursor
scanNumber cursor =
  case peekScalar cursor of
    Just scalar
      | isAsciiDigit scalar ->
          let mark = markCursor cursor
              result = maybe (scanDecimal cursor) (scanBase cursor) (basePrefix cursor)
           in finishNumber mark result
    _ -> Nothing

scanBase :: LexerCursor -> (Bool, Char -> Bool) -> NumberScan
scanBase cursor (prefixValid, isBaseDigit) =
  let afterPrefix = consumeScalars 2 cursor
      digitsMark = markCursor afterPrefix
      advanced = consumeWhile isBaseCandidate afterPrefix
      digitsValid = maybe False (validBaseRun isBaseDigit . fst) (captureSince digitsMark advanced)
   in NumberScan advanced (prefixValid && digitsValid) IntegerForm

scanDecimal :: LexerCursor -> NumberScan
scanDecimal cursor =
  let integerMark = markCursor cursor
      afterInteger = consumeWhile isDecimalCandidate cursor
      integerValid = maybe False (validDigitRun isAsciiDigit . fst) (captureSince integerMark afterInteger)
      fraction = scanFraction afterInteger
      afterFraction = maybe afterInteger scannedCursor fraction
      fractionValid = maybe True scannedValid fraction
      exponentScan = scanExponent afterFraction
      afterExponent = maybe afterFraction scannedCursor exponentScan
      exponentValid = maybe True scannedValid exponentScan
      isFloat = maybe False (const True) fraction || maybe False (const True) exponentScan
      plainForm = if isFloat then FloatForm else IntegerForm
      suffixScan = scanNumericSuffix (classifySuffix plainForm) afterExponent
      finalCursor = maybe afterExponent fst suffixScan
      suffixValid = maybe True (maybe False (const True) . snd) suffixScan
      form = maybe plainForm (maybe plainForm id . snd) suffixScan
   in NumberScan finalCursor (integerValid && fractionValid && exponentValid && suffixValid) form

{-| Classify a suffix against the digits it followed.

    `d` is admitted after either shape. Every other suffix has to match the
    shape it was written on, so `1f32` and `1.5u8` stay malformed. -}
classifySuffix :: NumberForm -> Text -> Maybe NumberForm
classifySuffix plainForm text
  | text == decimalSuffix = Just DecimalForm
  | plainForm == FloatForm, hasSuffix floatSuffix text = Just FloatForm
  | plainForm == IntegerForm, hasSuffix integerSuffix text = Just IntegerForm
  | otherwise = Nothing

scanFraction :: LexerCursor -> Maybe NumberScan
scanFraction cursor
  | cursorStartsWith "." cursor
  , let afterDot = consumeScalars 1 cursor
  , maybe False isAsciiDigit (peekScalar afterDot) =
      let digitsMark = markCursor afterDot
          advanced = consumeWhile isDecimalCandidate afterDot
          valid = maybe False (validDigitRun isAsciiDigit . fst) (captureSince digitsMark advanced)
       in Just (NumberScan advanced valid FloatForm)
  | otherwise = Nothing

scanExponent :: LexerCursor -> Maybe NumberScan
scanExponent cursor =
  case peekScalar cursor of
    Just marker
      | marker == 'e' || marker == 'E' ->
          let afterMarker = consumeScalars 1 cursor
              afterSign = case peekScalar afterMarker of
                Just sign | sign == '+' || sign == '-' -> consumeScalars 1 afterMarker
                _ -> afterMarker
              digitsMark = markCursor afterSign
              advanced = consumeWhile isDecimalCandidate afterSign
              valid = maybe False (validDigitRun isAsciiDigit . fst) (captureSince digitsMark advanced)
           in Just (NumberScan advanced valid FloatForm)
    _ -> Nothing

scanNumericSuffix :: (Text -> Maybe NumberForm) -> LexerCursor -> Maybe (LexerCursor, Maybe NumberForm)
scanNumericSuffix classify cursor = case peekScalar cursor of
  Just scalar
    | isAsciiLetter scalar ->
        let mark = markCursor cursor
            advanced = consumeWhile isAsciiAlphaNumeric cursor
            form = captureSince mark advanced >>= classify . fst
         in Just (advanced, form)
  _ -> Nothing

hasSuffix :: (Text -> Maybe value) -> Text -> Bool
hasSuffix classify = maybe False (const True) . classify

finishNumber :: CursorMark -> NumberScan -> Maybe LexerCursor
finishNumber mark NumberScan{scannedCursor, scannedValid, scannedForm} = do
  (lexeme, spanValue) <- captureSince mark scannedCursor
  if scannedValid
    then emitToken mark (literalKind scannedForm lexeme) scannedCursor
    else do
      emitted <- emitToken mark (Invalid lexeme) scannedCursor
      case mkDiagnosticCode "E0004" >>= \code -> diagnostic code Error spanValue "malformed numeric literal" of
        Just value -> recordDiagnostic value emitted
        Nothing -> Just emitted

literalKind :: NumberForm -> Text -> TokenKind
literalKind form lexeme = case form of
  IntegerForm -> IntegerLiteral lexeme
  FloatForm -> FloatLiteral lexeme
  DecimalForm -> DecimalLiteral lexeme

basePrefix :: LexerCursor -> Maybe (Bool, Char -> Bool)
basePrefix cursor
  | cursorStartsWith "0b" cursor = Just (True, isBinaryDigit)
  | cursorStartsWith "0o" cursor = Just (True, isOctalDigit)
  | cursorStartsWith "0x" cursor = Just (True, isHexDigit)
  | cursorStartsWith "0B" cursor = Just (False, isBinaryDigit)
  | cursorStartsWith "0O" cursor = Just (False, isOctalDigit)
  | cursorStartsWith "0X" cursor = Just (False, isHexDigit)
  | otherwise = Nothing

validDigitRun :: (Char -> Bool) -> Text -> Bool
validDigitRun isDigit textValue =
  case Text.foldl' step (True, False, 0 :: Int) textValue of
    (valid, endedWithDigit, count) -> valid && endedWithDigit && count > 0
  where
    step (valid, previousDigit, count) scalar
      | isDigit scalar = (valid, True, count + 1)
      | scalar == '_' = (valid && previousDigit, False, count)
      | otherwise = (False, False, count)

validBaseRun :: (Char -> Bool) -> Text -> Bool
validBaseRun isDigit candidate =
  let (digits, _) = splitIntegerSuffix candidate
   in validDigitRun isDigit digits

isDecimalCandidate :: Char -> Bool
isDecimalCandidate scalar = isAsciiDigit scalar || scalar == '_'

isBaseCandidate :: Char -> Bool
isBaseCandidate scalar = isAsciiDigit scalar || isAsciiLower scalar || isAsciiUpper scalar || scalar == '_'

isAsciiLetter :: Char -> Bool
isAsciiLetter scalar = isAsciiLower scalar || isAsciiUpper scalar

isAsciiAlphaNumeric :: Char -> Bool
isAsciiAlphaNumeric scalar = isAsciiDigit scalar || isAsciiLetter scalar

isAsciiDigit :: Char -> Bool
isAsciiDigit scalar = scalar >= '0' && scalar <= '9'

isBinaryDigit :: Char -> Bool
isBinaryDigit scalar = scalar == '0' || scalar == '1'

isOctalDigit :: Char -> Bool
isOctalDigit scalar = scalar >= '0' && scalar <= '7'

isHexDigit :: Char -> Bool
isHexDigit scalar =
  isAsciiDigit scalar
    || (scalar >= 'a' && scalar <= 'f')
    || (scalar >= 'A' && scalar <= 'F')
