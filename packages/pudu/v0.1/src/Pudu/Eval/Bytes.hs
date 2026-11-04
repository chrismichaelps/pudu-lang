{-# LANGUAGE BangPatterns #-}

{-| @Eval.Bytes.Module — a sequence of bytes as one runtime value -}
module Pudu.Eval.Bytes
  ( callBytesMethod
  , callBytesOf
  , bytesFromText
  , bytesMethods
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Internal as Internal
import qualified Data.ByteString.Unsafe as Unsafe
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)
import Foreign.Marshal.Utils (copyBytes)
import Foreign.Ptr (plusPtr)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value
  ( BytesMethod (..)
  , Value (..)
  , bytesMethodName
  , intOf
  )
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import Pudu.Source (Span)

{-| The kind every byte read out of a sequence carries.

    A byte is a `UInt8` and says so, for the reason an integer carries its kind
    at all: a value whose type says one thing and whose arithmetic does another
    is a value the type did not describe. Reading a byte and adding one to it
    wraps at 256 here, which is what the type promised. -}
byteKind :: IntegerKind
byteKind = UnsignedKind 8

byteValue :: Word8 -> Value
byteValue = IntValue byteKind . fromIntegral

{-| Build a byte sequence from an array of `UInt8`.

    Values outside a byte are refused rather than masked. A caller who wanted
    the low bits of a wider number says so with a mask before it gets here, the
    same rule conversion between integer widths already follows. -}
callBytesOf :: Span -> [Value] -> Evaluator Value
callBytesOf spanValue arguments = case arguments of
  [ArrayValue members] -> do
    bytes <- traverse oneByte members
    let (packed, _) = ByteString.unfoldrN (Seq.length bytes) nextByte bytes
    pure (BytesValue packed)
  _ -> abortAt (Just spanValue) "E7003" "bytesOf expects one array" Nothing
 where
  nextByte remaining = case Seq.viewl remaining of
    Seq.EmptyL -> Nothing
    byte Seq.:< rest -> Just (byte, rest)

  oneByte value = case value of
    IntValue _ number
      | number >= 0 && number <= 255 -> pure (fromInteger number)
    IntValue _ number ->
      abortAt (Just spanValue) "E7004"
        ("bytesOf received " <> textOf number <> ", which is not a byte")
        (Just "mask the value to eight bits before building a byte sequence")
    _ ->
      abortAt (Just spanValue) "E7001" "bytesOf expects an array of UInt8" Nothing

  textOf number = Text.pack (show number)

{-| The UTF-8 encoding of text.

    This direction cannot fail: every text value the language holds is a
    sequence of scalars, and every sequence of scalars has an encoding. The
    other direction can, which is why `toText` answers `Option`. -}
bytesFromText :: Text -> Value
bytesFromText = BytesValue . Encoding.encodeUtf8

{-| The methods a byte sequence carries, paired with their tags.

    Read by both dispatch and the name a session offers, so what a prompt
    suggests and what a call finds cannot disagree. -}
bytesMethods :: [(Text, BytesMethod)]
bytesMethods =
  [ ("length", BytesLength)
  , ("isEmpty", BytesIsEmpty)
  , ("at", BytesAt)
  , ("slice", BytesSlice)
  , ("take", BytesTake)
  , ("drop", BytesDrop)
  , ("concat", BytesConcat)
  , ("indexOf", BytesIndexOf)
  , ("contains", BytesContains)
  , ("startsWith", BytesStartsWith)
  , ("endsWith", BytesEndsWith)
  , ("reverse", BytesReverse)
  , ("strided", BytesStrided)
  , ("toArray", BytesToArray)
  , ("toText", BytesToText)
  ]

{-| Apply one built-in byte method.

    Every one answers with a new value rather than changing its receiver, like
    every other collection in the language.

    `slice`, `take`, and `drop` hand back a view onto the same storage: the
    answer names a stretch of the bytes the receiver already holds rather than
    a copy of them. That is what lets a decoder walk an input by handing the
    remainder forward at each step without the walk costing the square of the
    input. `concat`, `reverse` and `strided` are the operations that must build
    new storage, and they are named so a reader can see where the copying is.

    Where `Str` reports an index outside the text, a byte sequence clamps.
    The two are answering different questions: an index into text is a position
    a reader wrote down and getting it wrong is a mistake worth reporting,
    while a slice of a byte stream is usually arithmetic on a length that came
    from the input itself, and a decoder reading a truncated frame wants a
    short answer it can test rather than an abort it cannot catch. -}
callBytesMethod :: Span -> BytesMethod -> Value -> [Value] -> Evaluator Value
callBytesMethod spanValue method receiver arguments = case receiver of
  BytesValue bytes -> apply bytes
  _ -> abortAt (Just spanValue) "E7001" "not a byte sequence" Nothing
 where
  apply bytes = case (method, arguments) of
    (BytesLength, []) -> pure (intOf (fromIntegral (ByteString.length bytes)))
    (BytesIsEmpty, []) -> pure (BoolValue (ByteString.null bytes))
    (BytesAt, [IntValue _ index])
      | index >= 0 && index < fromIntegral (ByteString.length bytes) ->
          pure (someValue (byteValue (ByteString.index bytes (fromInteger index))))
      | otherwise -> pure noneValue
    (BytesSlice, [IntValue _ from, IntValue _ to]) ->
      pure (BytesValue (sliceOf bytes from to))
    (BytesTake, [IntValue _ count]) ->
      pure (BytesValue (ByteString.take (clampCount bytes count) bytes))
    (BytesDrop, [IntValue _ count]) ->
      pure (BytesValue (ByteString.drop (clampCount bytes count) bytes))
    (BytesConcat, [BytesValue other]) ->
      pure (BytesValue (ByteString.append bytes other))
    (BytesIndexOf, [BytesValue needle]) -> pure (intOf (indexOfBytes bytes needle))
    (BytesContains, [BytesValue needle]) ->
      pure (BoolValue (indexOfBytes bytes needle >= 0))
    (BytesStartsWith, [BytesValue needle]) ->
      pure (BoolValue (ByteString.isPrefixOf needle bytes))
    (BytesEndsWith, [BytesValue needle]) ->
      pure (BoolValue (ByteString.isSuffixOf needle bytes))
    (BytesReverse, []) -> pure (BytesValue (ByteString.reverse bytes))
    {-| Unlike the clamping views, a malformed group shape is a caller error
        with no sensible short answer, so it answers `None`. -}
    (BytesStrided, [IntValue _ offset, IntValue _ width, IntValue _ stride])
      | offset < 0 || width < 0 || stride < 1 || width > stride -> pure noneValue
      | otherwise -> pure (someValue (BytesValue (stridedOf bytes offset width stride)))
    (BytesToArray, []) ->
      pure (ArrayValue (Seq.fromFunction (ByteString.length bytes)
        (byteValue . ByteString.index bytes)))
    {-| Decoding answers `Option` because not every sequence of bytes is text.
        A wired-in signature cannot mention a type a library module declares,
        so the cause of the failure is named by `Std.Bytes` rather than here:
        this reports only that the bytes were not a valid encoding. -}
    (BytesToText, []) -> case Encoding.decodeUtf8' bytes of
      Right text -> pure (someValue (StrValue text))
      Left _ -> pure noneValue
    _ -> wrongArity (bytesMethodName method)

  wrongArity name =
    abortAt (Just spanValue) "E7003"
      ("wrong arguments for byte method " <> name) Nothing

  {-| Both ends are clamped into the sequence and a reversed pair reads as
      empty, so slicing arithmetic derived from an input cannot abort. -}
  sliceOf bytes from to =
    let size = ByteString.length bytes
        start = clampIndex size from
        end = clampIndex size to
     in if end <= start
          then ByteString.empty
          else ByteString.take (end - start) (ByteString.drop start bytes)

  clampIndex size number
    | number < 0 = 0
    | number > fromIntegral size = size
    | otherwise = fromInteger number

  clampCount bytes number = clampIndex (ByteString.length bytes) number

  {-| `width` bytes from each `stride`-byte group starting at `offset`; a final
      short group contributes what remains. One allocation of the exact size.
      A bytewise loop measured slower than one copy call per group. -}
  stridedOf bytes offset width stride
    | offset >= fromIntegral size = ByteString.empty
    | otherwise = Internal.unsafeCreate total $ \out ->
        Unsafe.unsafeUseAsCString bytes $ \source ->
          let copyGroup !group !written
                | written >= total = pure ()
                | otherwise = do
                    let count = min taken (extent - group * step)
                    copyBytes (out `plusPtr` written) (source `plusPtr` (start + group * step)) count
                    copyGroup (group + 1) (written + count)
           in copyGroup 0 0
    where
      size = ByteString.length bytes
      start = fromInteger offset :: Int
      extent = size - start
      step = fromInteger (min stride (fromIntegral extent)) :: Int
      taken = fromInteger (min width (fromIntegral step)) :: Int
      total = (extent `quot` step) * taken + min taken (extent `rem` step)

  {-| The position of a sub-sequence, or `-1` when it is absent.

      The absent answer matches what `indexOf` on text and on an array already
      give. One vocabulary answering `Option` in one place and a sentinel in
      another would be worse than either answer used everywhere. -}
  indexOfBytes :: ByteString.ByteString -> ByteString.ByteString -> Integer
  indexOfBytes haystack needle
    | ByteString.null needle = 0
    | otherwise =
        let (before, found) = ByteString.breakSubstring needle haystack
         in if ByteString.null found
              then -1
              else fromIntegral (ByteString.length before)

  someValue value = VariantValue "Some" [value]
  noneValue = VariantValue "None" []
