{-| @Eval.Json — decodes JSON text into `Std.Json` values and writes them back natively. -}
module Pudu.Eval.Json
  ( callJsonDecode
  , callJsonEncode
  , decodeDocument
  , encodeValue
  ) where

import Control.Monad (guard)
import Data.Bits (shiftL, (.|.))
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as Char8
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.ByteString.Unsafe as Unsafe
import Data.Foldable (toList)
import qualified Data.Sequence as Seq
import Data.Char (chr)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)

import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.Source (Span)

{-| `jsonDecode(source)`: the value a JSON text holds, or `None` when this
    reader does not accept it.

    `None` is not a verdict that the text is invalid. It is answered for every
    text this reader cannot decode exactly as `Std.Json.decode` would, and that
    function then reads the text itself, so a refusal keeps the position and
    wording its callers already see. -}
callJsonDecode :: Span -> [Value] -> Evaluator Value
callJsonDecode spanValue arguments = case arguments of
  [StrValue source] -> pure $ case decodeDocument (Encoding.encodeUtf8 source) of
    Just value -> VariantValue "Some" [value]
    Nothing -> VariantValue "None" []
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for jsonDecode" Nothing

{-| `jsonEncode(value, pretty)`: a `Std.Json` value written as text, compact or
    across indented lines, exactly as the library's own encoder wrote it. -}
callJsonEncode :: Span -> [Value] -> Evaluator Value
callJsonEncode spanValue arguments = case arguments of
  [value, BoolValue pretty] -> case encodeValue pretty value of
    Just built ->
      pure (StrValue (Encoding.decodeUtf8Lenient (LazyByteString.toStrict (Builder.toLazyByteString built))))
    Nothing -> abortAt (Just spanValue) "E7001" "jsonEncode expects a Json value" Nothing
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for jsonEncode" Nothing

{-| A value's text as UTF-8 bytes, or nothing when it is not a `Std.Json` value.

    Compact text has no spaces between parts. The pretty form puts each member
    of a non-empty list or object on its own line, indented two spaces per level
    below its container, writes `": "` after a key, and closes the container on
    a line at its own indentation. An empty container is `[]` or `{}` in both. -}
encodeValue :: Bool -> Value -> Maybe Builder.Builder
encodeValue pretty = valueAt 0
 where
  valueAt depth value = case value of
    VariantValue "Null" [] -> Just (Builder.string7 "null")
    VariantValue "Boolean" [BoolValue flag] -> Just (Builder.string7 (if flag then "true" else "false"))
    VariantValue "Number" [IntValue _ number] -> Just (Builder.integerDec number)
    VariantValue "Fractional" [StrValue digits] -> Just (Encoding.encodeUtf8Builder digits)
    VariantValue "Text" [StrValue content] -> Just (quoted content)
    VariantValue "List" [ArrayValue members]
      | Seq.null members -> Just (Builder.string7 "[]")
      | otherwise -> container depth '[' ']' <$> traverse (valueAt (depth + 1)) (toList members)
    VariantValue "Object" [ArrayValue entries]
      | Seq.null entries -> Just (Builder.string7 "{}")
      | otherwise -> container depth '{' '}' <$> traverse (entryAt (depth + 1)) (toList entries)
    _ -> Nothing

  entryAt depth entry = case entry of
    TupleValue [StrValue key, held] -> do
      body <- valueAt depth held
      Just (quoted key <> Builder.string7 (if pretty then ": " else ":") <> body)
    _ -> Nothing

  container depth open close parts =
    Builder.char7 open
      <> mconcat (zipWith member [0 :: Int ..] parts)
      <> (if pretty then lineAt depth else mempty)
      <> Builder.char7 close
   where
    member index part =
      (if index > 0 then Builder.char7 ',' else mempty)
        <> (if pretty then lineAt (depth + 1) else mempty)
        <> part

  lineAt depth = Builder.char7 '\n' <> mconcat (replicate depth (Builder.string7 "  "))

{-| Text written as a JSON string. The characters that need no escape are
    written as one run up to the next that does. -}
quoted :: Text -> Builder.Builder
quoted content = Builder.char7 '"' <> runs content <> Builder.char7 '"'
 where
  runs remaining = case Text.break needsEscape remaining of
    (plain, rest) ->
      Encoding.encodeUtf8Builder plain <> case Text.uncons rest of
        Nothing -> mempty
        Just (character, after) -> escaped character <> runs after

  needsEscape character = character < ' ' || character == '"' || character == '\\'

  escaped character = case character of
    '\b' -> Builder.string7 "\\b"
    '\f' -> Builder.string7 "\\f"
    '\n' -> Builder.string7 "\\n"
    '\r' -> Builder.string7 "\\r"
    '\t' -> Builder.string7 "\\t"
    '"' -> Builder.string7 "\\\""
    '\\' -> Builder.string7 "\\\\"
    _ -> Builder.string7 "\\u00" <> Builder.word8HexFixed (fromIntegral (fromEnum character))

{-| The most lists and objects one value may nest, as `Std.Json` bounds them. -}
maxDepth :: Int
maxDepth = 512

{-| One JSON value filling the whole of a text, apart from whitespace.

    Strings are found by searching for the next quote, backslash, or control
    byte rather than by stepping through characters, and a run without escapes
    is decoded as one slice. Every other token is at most a few bytes. -}
decodeDocument :: ByteString.ByteString -> Maybe Value
decodeDocument input = do
  (value, next) <- valueAt 0 (skipSpace 0)
  if skipSpace next == size then Just value else Nothing
 where
  size = ByteString.length input

  byteAt :: Int -> Word8
  byteAt = Unsafe.unsafeIndex input

  skipSpace position
    | position < size && isSpace (byteAt position) = skipSpace (position + 1)
    | otherwise = position

  valueAt :: Int -> Int -> Maybe (Value, Int)
  valueAt depth position
    | position >= size = Nothing
    | otherwise = case byteAt position of
        34 -> do
          (text, next) <- stringAt position
          Just (VariantValue "Text" [StrValue text], next)
        91 | depth < maxDepth -> listAt (depth + 1) position
        123 | depth < maxDepth -> objectAt (depth + 1) position
        116 -> keyword (Char8.pack "true") (VariantValue "Boolean" [BoolValue True]) position
        102 -> keyword (Char8.pack "false") (VariantValue "Boolean" [BoolValue False]) position
        110 -> keyword (Char8.pack "null") (VariantValue "Null" []) position
        byte
          | byte == 45 || isDigit byte -> numberAt position
          | otherwise -> Nothing

  keyword word value position
    | ByteString.isPrefixOf word (ByteString.drop position input) =
        Just (value, position + ByteString.length word)
    | otherwise = Nothing

  {-| `-?digits(.digits)?([eE][+-]?digits)?`, every run of digits non-empty
      and the whole part without a leading zero. A whole number's magnitude
      must fit the language's `Int`, as the library's reading of its digits
      requires before it applies the sign. -}
  numberAt start = do
    let signed = if byteAt start == 45 then start + 1 else start
    whole <- digitsFrom signed
    guard (not (whole - signed > 1 && byteAt signed == 48))
    let (fractional, afterFraction) =
          if whole < size && byteAt whole == 46 then (True, digitsFrom (whole + 1)) else (False, Just whole)
    afterPoint <- afterFraction
    let hasExponent = afterPoint < size && (byteAt afterPoint == 101 || byteAt afterPoint == 69)
    end <-
      if hasExponent
        then
          let signAt = afterPoint + 1
              digitsAt = if signAt < size && (byteAt signAt == 43 || byteAt signAt == 45) then signAt + 1 else signAt
           in digitsFrom digitsAt
        else Just afterPoint
    let numeral = ByteString.take (end - start) (ByteString.drop start input)
    if fractional || hasExponent
      then Just (VariantValue "Fractional" [StrValue (Encoding.decodeLatin1 numeral)], end)
      else do
        let magnitude = ByteString.foldl' (\total byte -> total * 10 + toInteger (byte - 48)) 0 (ByteString.drop (signed - start) numeral)
            number = if signed > start then negate magnitude else magnitude
        if magnitude > toInteger (maxBound :: Int)
          then Nothing
          else Just (VariantValue "Number" [intOf number], end)

  {-| The end of a non-empty run of digits beginning at `position`. -}
  digitsFrom position =
    let end = position + ByteString.length (ByteString.takeWhile isDigit (ByteString.drop position input))
     in if end > position then Just end else Nothing

  stringAt open = go (open + 1) []
   where
    go from pieces = case ByteString.findIndex stops (ByteString.drop from input) of
      Nothing -> Nothing
      Just offset ->
        let at = from + offset
            held = slice from at : pieces
         in case byteAt at of
              34 -> Just (Text.concat (reverse held), at + 1)
              92 -> do
                (piece, next) <- escapeAt (at + 1)
                go next (piece : held)
              _ -> Nothing
    stops byte = byte == 34 || byte == 92 || byte < 32

  slice from to = Encoding.decodeUtf8Lenient (ByteString.take (to - from) (ByteString.drop from input))

  escapeAt position
    | position >= size = Nothing
    | otherwise = case byteAt position of
        34 -> Just (Text.singleton '"', position + 1)
        92 -> Just (Text.singleton '\\', position + 1)
        47 -> Just (Text.singleton '/', position + 1)
        98 -> Just (Text.singleton '\b', position + 1)
        102 -> Just (Text.singleton '\f', position + 1)
        110 -> Just (Text.singleton '\n', position + 1)
        114 -> Just (Text.singleton '\r', position + 1)
        116 -> Just (Text.singleton '\t', position + 1)
        117 -> unicodeAt (position + 1)
        _ -> Nothing

  {-| Four hex digits after `\u`, composing a surrogate pair when the first is
      a high surrogate. A lone surrogate is refused. -}
  unicodeAt position = do
    first <- hexAt position
    if first >= 0xDC00 && first <= 0xDFFF
      then Nothing
      else
        if first < 0xD800 || first > 0xDBFF
          then Just (Text.singleton (chr first), position + 4)
          else do
            let low = position + 4
            if low + 1 < size && byteAt low == 92 && byteAt (low + 1) == 117
              then do
                second <- hexAt (low + 2)
                if second < 0xDC00 || second > 0xDFFF
                  then Nothing
                  else
                    let scalar = 0x10000 + ((first - 0xD800) `shiftL` 10) + (second - 0xDC00)
                     in Just (Text.singleton (chr scalar), low + 6)
              else Nothing

  hexAt position
    | position + 4 > size = Nothing
    | otherwise = foldl step (Just 0) [position .. position + 3]
   where
    step total index = do
      sofar <- total
      digit <- hexDigit (byteAt index)
      Just ((sofar `shiftL` 4) .|. digit)

  listAt depth open = do
    let first = skipSpace (open + 1)
    if first < size && byteAt first == 93
      then Just (VariantValue "List" [ArrayValue Seq.empty], first + 1)
      else members first Seq.empty
   where
    members position held = do
      (value, next) <- valueAt depth position
      let collected = held Seq.|> value
          after = skipSpace next
      if after >= size
        then Nothing
        else case byteAt after of
          44 -> collected `seq` members (skipSpace (after + 1)) collected
          93 -> Just (VariantValue "List" [ArrayValue collected], after + 1)
          _ -> Nothing

  objectAt depth open = do
    let first = skipSpace (open + 1)
    if first < size && byteAt first == 125
      then Just (VariantValue "Object" [ArrayValue Seq.empty], first + 1)
      else entries first Seq.empty
   where
    entries position held
      | position >= size || byteAt position /= 34 = Nothing
      | otherwise = do
          (key, afterKey) <- stringAt position
          let colon = skipSpace afterKey
          if colon >= size || byteAt colon /= 58
            then Nothing
            else do
              (value, next) <- valueAt depth (skipSpace (colon + 1))
              let collected = held Seq.|> TupleValue [StrValue key, value]
                  after = skipSpace next
              if after >= size
                then Nothing
                else case byteAt after of
                  44 -> collected `seq` entries (skipSpace (after + 1)) collected
                  125 -> Just (VariantValue "Object" [ArrayValue collected], after + 1)
                  _ -> Nothing

isSpace :: Word8 -> Bool
isSpace byte = byte == 32 || byte == 9 || byte == 13 || byte == 10

isDigit :: Word8 -> Bool
isDigit byte = byte >= 48 && byte <= 57

hexDigit :: Word8 -> Maybe Int
hexDigit byte
  | byte >= 48 && byte <= 57 = Just (fromIntegral byte - 48)
  | lower >= 97 && lower <= 102 = Just (fromIntegral lower - 87)
  | otherwise = Nothing
 where
  lower = byte .|. 0x20
