{-# LANGUAGE MagicHash #-}

{-| @Program.Eval.Builtin.String — text method dispatch and scalar manipulation -}
module Pudu.Eval.Builtin.String
  ( callStringMethod
  , callStringMethodFast
  , drop1Text
  , dropText
  , indexOfText
  ) where

import Data.Bits ((.&.))
import Data.IORef (IORef, atomicWriteIORef, newIORef, readIORef)
import qualified Data.Sequence as Seq
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as Builder
import qualified Data.Text.Array as Array
import Data.Text.Internal (Text (..))
import Data.Text.Internal.Encoding.Utf8 (utf8LengthByLeader)
import Data.Text.Unsafe (Iter (..), iterArray)
import GHC.Exts (isTrue#, sameByteArray#)

import Pudu.Eval.Builtin.TextNumber (readDecimal, readFloat, readWhole)
import Pudu.Eval.Bytes (bytesFromText)
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Pudu.Eval.Env (Eval (..), Evaluator (..), abortAt)
import Pudu.Eval.Value (StringMethod (..), Value (..), boolValue, intOf, stringMethodName)
import Pudu.Source (Span)
import System.IO.Unsafe (unsafePerformIO)

{-| Apply a built-in text method.
    Every one answers with a new value: text is a value, and a method that
    changed its receiver would make two names for one string disagree. Indices
    count Unicode scalars, not bytes, so `charAt` and `slice` agree with what a
    reader counting characters expects — the same choice indexing already makes.

    An index outside the text is `E7004` rather than a clamped or empty answer.
    A silent clamp turns a logic error into wrong output that looks correct. -}
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
callStringMethod spanValue method receiver arguments = case receiver of
  StrValue text -> apply text
  _ -> abortAt (Just spanValue) "E7001" "not text" Nothing
 where
  apply text = case (method, arguments) of
    (StringLength, []) -> intOf . fromIntegral <$> liftCursor (scalarCount text)
    (StringIsEmpty, []) -> pure (boolValue (Text.null text))
    (StringCharAt, [IntValue _ index]) -> charAtFast spanValue text index
    (StringIndexOf, [StrValue needle]) -> pure (intOf (indexOfText text needle))
    (StringContains, [StrValue needle]) -> pure (boolValue (Text.isInfixOf needle text))
    (StringStartsWith, [StrValue needle]) -> pure (boolValue (Text.isPrefixOf needle text))
    (StringEndsWith, [StrValue needle]) -> pure (boolValue (Text.isSuffixOf needle text))
    (StringDrop, [IntValue _ count])
      | count < 0 -> outOfRange "a drop count cannot be negative"
      | count == 1 -> pure (StrValue (drop1Text text))
      | otherwise -> pure (StrValue (dropText (textCount text count) text))
    (StringTake, [IntValue _ count])
      | count < 0 -> outOfRange "a take count cannot be negative"
      | otherwise -> pure (StrValue (Text.take (textCount text count) text))
    (StringSpanOf, [StrValue accepted]) -> pure (spanLength (characterMember accepted) text)
    (StringSpanNotOf, [StrValue rejected]) ->
      pure (spanLength (not . characterMember rejected) text)
    (StringSlice, [IntValue _ from, IntValue _ to]) -> slice text from to
    (StringEscapeHtml, []) -> pure (StrValue (escapeHtmlText text))
    (StringTrim, []) -> pure (StrValue (Text.strip text))
    (StringToUpper, []) -> pure (StrValue (Text.toUpper text))
    (StringToLower, []) -> pure (StrValue (Text.toLower text))
    (StringReplace, [StrValue needle, StrValue replacement])
      | Text.null needle -> pure (StrValue text)
      | otherwise -> pure (StrValue (Text.replace needle replacement text))
    (StringRepeat, [IntValue _ count])
      | count < 0 -> outOfRange "a repeat count cannot be negative"
      | count == 0 || Text.null text -> pure (StrValue Text.empty)
      | count * textBytes text > toInteger (maxBound :: Int) ->
          outOfRange "repeated text exceeds the runtime size limit"
      | otherwise -> pure (StrValue (Text.replicate (fromInteger count) text))
    (StringSplit, [StrValue separator])
      | Text.null separator -> pure (textArray (Text.chunksOf 1 text))
      | otherwise -> pure (textArray (Text.splitOn separator text))
    (StringToBytes, []) -> pure (bytesFromText text)
    (StringChars, []) -> pure (ArrayValue (Seq.fromList (map CharValue (Text.unpack text))))
    (StringLines, []) -> pure (textArray (Text.lines text))
    (StringReverse, []) -> pure (StrValue (Text.reverse text))
    (StringToInt, []) -> pure (optional (intOf <$> readWhole text))
    (StringToFloat, []) -> pure (optional (FloatValue Float64Width <$> readFloat text))
    (StringToDecimal, []) -> pure (optional (DecimalValue <$> readDecimal text))
    _ -> wrongStringArity (stringMethodName method)

  textArray = ArrayValue . Seq.fromList . map StrValue

  optional = maybe (VariantValue "None" []) (\held -> VariantValue "Some" [held])

  spanLength holds = intOf . fromIntegral . countPrefix holds

  {-| The part of the text the bounds ask for, and nothing where they ask for
      nothing.

      Bounds outside the text name the part of it that is inside, and bounds
      that end before they start name nothing — the answers `Array.slice`
      already gave. Text refused both instead, so the same expression over the
      two kinds of sequence behaved differently: `List.rest` of an empty array
      answered an empty array, and `Text.rest` of empty text stopped the
      program. -}
  slice text@(Text array offset _) from to = do
    size <- toInteger <$> liftCursor (scalarCount text)
    let start = max 0 (min from size)
        end = max start (min to size)
    startByte <- liftCursor (scalarOffset text (fromInteger start))
    endByte <- liftCursor (scalarOffset text (fromInteger end))
    pure (StrValue (Text array (offset + startByte) (endByte - startByte)))

  outOfRange message = abortAt (Just spanValue) "E7004" message Nothing

  wrongStringArity name =
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> name) Nothing

{-| Low-level O(1) character drop for Text.
    Directly inspects the underlying UTF-8 byte array to advance by the
    exact scalar byte width without decoding character streams or copying buffers. -}
{-# INLINE drop1Text #-}
drop1Text :: Text -> Text
drop1Text (Text arr off len)
  | len <= 0 = Text arr off 0
  | otherwise =
      let !w = Array.unsafeIndex arr off
          !delta
            | w < 0x80 = 1
            | w < 0xE0 = 2
            | w < 0xF0 = 3
            | otherwise = 4
          !d = min len delta
      in Text arr (off + d) (len - d)

characterMember :: Text -> Char -> Bool
characterMember alphabet = case Text.uncons alphabet of
  Nothing -> const False
  Just (first, rest)
    | Text.null rest -> (== first)
    | otherwise -> let members = Set.fromList (Text.unpack alphabet)
                    in (`Set.member` members)

countPrefix :: (Char -> Bool) -> Text -> Int
countPrefix holds = go 0
 where
  go !count remaining = case Text.uncons remaining of
    Just (character, rest) | holds character -> go (count + 1) rest
    _ -> count

textBytes :: Text -> Integer
textBytes (Text _ _ byteLength) = toInteger byteLength

textCount :: Text -> Integer -> Int
textCount text count = fromInteger (min count (textBytes text))

{-# INLINE dropText #-}
dropText :: Int -> Text -> Text
dropText !n !t
  | n <= 0 = t
  | n == 1 = drop1Text t
  | otherwise = Text.drop n t

{-| Fast direct dispatch for built-in text methods without intermediate
    StringMethodValue closure allocation or dynamic environment queries. -}
callStringMethodFast :: Span -> Text -> Text -> [Value] -> Maybe (Evaluator Value)
callStringMethodFast spanValue member text arguments = case member of
  "drop" -> Just $ case arguments of
    [IntValue _ count]
      | count < 0 -> abortAt (Just spanValue) "E7004" "a drop count cannot be negative" Nothing
      | count == 1 -> pure (StrValue (drop1Text text))
      | otherwise -> pure (StrValue (dropText (textCount text count) text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for drop" Nothing
  "isEmpty" -> Just $ case arguments of
    [] -> pure (boolValue (Text.null text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for isEmpty" Nothing
  "length" -> Just $ case arguments of
    [] -> intOf . fromIntegral <$> liftCursor (scalarCount text)
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for length" Nothing
  "charAt" -> Just $ case arguments of
    [IntValue _ index] -> charAtFast spanValue text index
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for charAt" Nothing
  "take" -> Just $ case arguments of
    [IntValue _ count]
      | count < 0 -> abortAt (Just spanValue) "E7004" "a take count cannot be negative" Nothing
      | otherwise -> pure (StrValue (Text.take (textCount text count) text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for take" Nothing
  "contains" -> Just $ case arguments of
    [StrValue needle] -> pure (boolValue (Text.isInfixOf needle text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for contains" Nothing
  "startsWith" -> Just $ case arguments of
    [StrValue needle] -> pure (boolValue (Text.isPrefixOf needle text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for startsWith" Nothing
  "endsWith" -> Just $ case arguments of
    [StrValue needle] -> pure (boolValue (Text.isSuffixOf needle text))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for endsWith" Nothing
  "indexOf" -> Just $ case arguments of
    [StrValue needle] -> pure (intOf (indexOfText text needle))
    _ -> abortAt (Just spanValue) "E7012" "wrong arguments for indexOf" Nothing
  "spanOf" -> direct StringSpanOf
  "spanNotOf" -> direct StringSpanNotOf
  "slice" -> direct StringSlice
  "escapeHtml" -> direct StringEscapeHtml
  "trim" -> direct StringTrim
  "toUpper" -> direct StringToUpper
  "toLower" -> direct StringToLower
  "replace" -> direct StringReplace
  "repeat" -> direct StringRepeat
  "split" -> direct StringSplit
  "toBytes" -> direct StringToBytes
  "chars" -> direct StringChars
  "lines" -> direct StringLines
  "reverse" -> direct StringReverse
  "toInt" -> direct StringToInt
  "toFloat" -> direct StringToFloat
  "toDecimal" -> direct StringToDecimal
  _ -> Nothing
 where
  direct method = Just (callStringMethod spanValue method (StrValue text) arguments)

charAtFast :: Span -> Text -> Integer -> Evaluator Value
charAtFast spanValue text@(Text array offset byteLength) index
  | index < 0 || index >= fromIntegral byteLength = outOfRange
  | otherwise = do
      position <- liftCursor (scalarOffset text (fromInteger index))
      if position < 0 || position >= byteLength
        then outOfRange
        else let Iter character _ = iterArray array (offset + position) in pure (CharValue character)
 where
  outOfRange = abortAt (Just spanValue) "E7004" "index out of range" Nothing

{-| Where the last positional reads of long texts landed.

    Indices count scalars and UTF-8 gives a scalar no fixed width, so reaching
    index n from the start of a text walks n scalars, and so does counting its
    length. A program scanning text by position asks for n, then n + 1, and its
    loop asks for the length each turn; answering every one from the start made
    the scan grow with the square of the text, and 640,000 ASCII characters
    took 11.0 s at -O2. Remembering the last scalar index, its byte offset, and
    the counted length turns each step into a walk of the distance moved.

    Two entries, most recent first, so a loop comparing two texts position by
    position keeps both. Each entry is an immutable record and the pair is
    replaced whole, so a read on another thread sees an old pair or a new one,
    each correct for its own text. An entry is keyed by the text's buffer,
    offset, and byte length: a different string, including a slice sharing the
    buffer, never answers from another's entry. -}
data TextCursor = TextCursor
  { cursorArray :: !Array.Array
  , cursorOffset :: !Int
  , cursorBytes :: !Int
  , cursorScalar :: !Int
  , cursorByte :: !Int
  , cursorLength :: !Int
  }

data TextCursors = TextCursors !TextCursor !TextCursor

textCursors :: IORef TextCursors
textCursors = unsafePerformIO (newIORef (TextCursors unused unused))
 where
  unused = TextCursor Array.empty 0 (-1) 0 0 (-1)
{-# NOINLINE textCursors #-}

{-| Texts shorter than this many bytes are walked from their start: the walk
    is shorter than consulting and replacing the cursors. -}
cursorThreshold :: Int
cursorThreshold = 256

liftCursor :: IO a -> Evaluator a
liftCursor action = Evaluator $ \env -> (`Done` env) <$> action

sameText :: Text -> TextCursor -> Bool
sameText (Text (Array.ByteArray array) offset bytes) cursor =
  cursorBytes cursor == bytes
    && cursorOffset cursor == offset
    && case cursorArray cursor of
      Array.ByteArray known -> isTrue# (sameByteArray# known array)

{-| The entry this text already has, or a fresh one, with the entry to keep
    beside it. -}
findCursor :: Text -> IO (TextCursor, TextCursor)
findCursor text@(Text array offset bytes) = do
  TextCursors first second <- readIORef textCursors
  pure $
    if sameText text first
      then (first, second)
      else
        if sameText text second
          then (second, first)
          else (TextCursor array offset bytes 0 0 (-1), first)

{-| The number of scalars in a text, counted once per long text. -}
scalarCount :: Text -> IO Int
scalarCount text@(Text _ _ bytes)
  | bytes < cursorThreshold = pure (Text.length text)
  | otherwise = do
      (cursor, other) <- findCursor text
      if cursorLength cursor >= 0
        then pure (cursorLength cursor)
        else do
          let counted = Text.length text
          atomicWriteIORef textCursors (TextCursors cursor{cursorLength = counted} other)
          pure counted

{-| The byte offset, from the text's start, of scalar `index`: the byte length
    when `index` is the scalar length, and -1 past that. A long text walks from
    its remembered position, backwards when that is nearer than the start. -}
scalarOffset :: Text -> Int -> IO Int
scalarOffset text@(Text array offset bytes) index
  | index < 0 = pure (-1)
  | bytes < cursorThreshold = pure (relative (forward offset index))
  | otherwise = do
      (cursor, other) <- findCursor text
      let known = cursorScalar cursor
          position
            | cursorLength cursor >= 0 && index > cursorLength cursor = -1
            | index >= known = forward (offset + cursorByte cursor) (index - known)
            | index * 2 >= known = backward (offset + cursorByte cursor) (known - index)
            | otherwise = forward offset index
      if position < 0
        then pure (-1)
        else do
          atomicWriteIORef textCursors
            (TextCursors cursor{cursorScalar = index, cursorByte = position - offset} other)
          pure (position - offset)
 where
  end = offset + bytes
  relative position = if position < 0 then -1 else position - offset
  forward !position !remaining
    | remaining == 0 = position
    | position >= end = -1
    | otherwise =
        forward (position + utf8LengthByLeader (Array.unsafeIndex array position)) (remaining - 1)
  backward !position !remaining
    | remaining == 0 = position
    | otherwise = backward (leader (position - 1)) (remaining - 1)
  leader position
    | Array.unsafeIndex array position .&. 0xC0 == 0x80 = leader (position - 1)
    | otherwise = position

indexOfText :: Text -> Text -> Integer
indexOfText text needle = case Text.breakOn needle text of
  (before, rest)
    | Text.null rest, not (Text.null needle) -> -1
    | otherwise -> fromIntegral (Text.length before)

escapeHtmlText :: Text -> Text
escapeHtmlText text = case Text.break needsEscape text of
  (_, rest) | Text.null rest -> text
  (prefix, rest) -> LazyText.toStrict (Builder.toLazyText (Builder.fromText prefix <> escapedRest rest))
 where
  needsEscape character = character == '&' || character == '<' || character == '>'
    || character == '"' || character == '\''
  escapedRest remaining = case Text.uncons remaining of
    Nothing -> mempty
    Just (character, rest) ->
      let (plain, next) = Text.break needsEscape rest
       in entity character <> Builder.fromText plain <> escapedRest next
  entity character = Builder.fromText $ case character of
    '&' -> "&amp;"
    '<' -> "&lt;"
    '>' -> "&gt;"
    '"' -> "&quot;"
    '\'' -> "&#39;"
    _ -> Text.singleton character
