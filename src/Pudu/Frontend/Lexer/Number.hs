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
  ( TokenKind (FloatLiteral, IntegerLiteral, Invalid) )
import Pudu.FloatLiteral (floatSuffix)
import Pudu.IntegerLiteral (integerSuffix, splitIntegerSuffix)

data NumberScan = NumberScan
  { scannedCursor :: !LexerCursor
  , scannedValid :: !Bool
  , scannedFloat :: !Bool
  }

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
   in NumberScan advanced (prefixValid && digitsValid) False

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
      suffixScan = if isFloat
        then scanNumericSuffix (hasSuffix floatSuffix) afterExponent
        else scanNumericSuffix (hasSuffix integerSuffix) afterExponent
      finalCursor = maybe afterExponent fst suffixScan
      suffixValid = maybe True snd suffixScan
   in NumberScan finalCursor (integerValid && fractionValid && exponentValid && suffixValid) isFloat

scanFraction :: LexerCursor -> Maybe NumberScan
scanFraction cursor
  | cursorStartsWith "." cursor
  , let afterDot = consumeScalars 1 cursor
  , maybe False isAsciiDigit (peekScalar afterDot) =
      let digitsMark = markCursor afterDot
          advanced = consumeWhile isDecimalCandidate afterDot
          valid = maybe False (validDigitRun isAsciiDigit . fst) (captureSince digitsMark advanced)
       in Just (NumberScan advanced valid True)
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
           in Just (NumberScan advanced valid True)
    _ -> Nothing

scanNumericSuffix :: (Text -> Bool) -> LexerCursor -> Maybe (LexerCursor, Bool)
scanNumericSuffix classify cursor = case peekScalar cursor of
  Just scalar
    | isAsciiLetter scalar ->
        let mark = markCursor cursor
            advanced = consumeWhile isAsciiAlphaNumeric cursor
            valid = maybe False (classify . fst) (captureSince mark advanced)
         in Just (advanced, valid)
  _ -> Nothing

hasSuffix :: (Text -> Maybe value) -> Text -> Bool
hasSuffix classify = maybe False (const True) . classify

finishNumber :: CursorMark -> NumberScan -> Maybe LexerCursor
finishNumber mark NumberScan{scannedCursor, scannedValid, scannedFloat} = do
  (lexeme, spanValue) <- captureSince mark scannedCursor
  if scannedValid
    then emitToken mark (if scannedFloat then FloatLiteral lexeme else IntegerLiteral lexeme) scannedCursor
    else do
      emitted <- emitToken mark (Invalid lexeme) scannedCursor
      case mkDiagnosticCode "E0004" >>= \code -> diagnostic code Error spanValue "malformed numeric literal" of
        Just value -> recordDiagnostic value emitted
        Nothing -> Just emitted

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
