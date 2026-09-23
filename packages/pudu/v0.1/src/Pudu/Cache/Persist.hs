{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-| @Cache.Persist.Module — a compact binary form for compiler products -}
module Pudu.Cache.Persist
  ( Decode
  , Persist (..)
  , decodeWith
  , encodeFor
  , failDecode
  , persistDeferred
  , restoreDeferred
  ) where

import Data.Bits (shiftL, shiftR, xor, (.&.), (.|.))
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Lazy as Lazy
import qualified Data.ByteString.Unsafe as Unsafe
import Data.ByteString (ByteString)
import Data.ByteString.Builder (Builder)
import Data.Char (chr, ord)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import qualified Data.Text.Encoding as Encoding
import Data.Kind (Type)
import Data.Word (Word64, Word8)
import GHC.Generics
import GHC.TypeLits (KnownNat, Nat, natVal, type (+))
import Pudu.Source (Source, Span, mkSpan, offsetFromInt, sourceName, spanEnd, spanSource, spanStart, unOffset)

{-| A value's bytes, and how to read them back.

    Written by hand rather than through a general serialization library because
    two properties matter here and neither is theirs: a span is stored as two
    offsets and rebound on reading to the source text this run actually read,
    so a stored tree can never point into text other than the text it was
    parsed from; and reading never throws — a truncated or foreign file is a
    decoding failure, which a cache treats as a miss. -}
class Persist a where
  persist :: Source -> a -> Builder
  default persist :: (Generic a, GPersist (Rep a)) => Source -> a -> Builder
  persist source = gpersist source . from

  restore :: Decode a
  default restore :: (Generic a, GPersist (Rep a)) => Decode a
  restore = to <$> grestore

{-| Reading over one strict buffer: the source spans are rebound to, the bytes,
    and the position reached. A step answers with the next position or fails. -}
newtype Decode a = Decode (Source -> ByteString -> Int -> Step a)

{-| The value is lazy on purpose: a deferred block's value must stay unread
    until something asks for it, and a strict field would read it here. -}
data Step a = Step !Int ~a | Failed

instance Functor Decode where
  fmap transform (Decode action) = Decode $ \source bytes position ->
    case action source bytes position of
      Step next value -> Step next (transform value)
      Failed -> Failed
  {-# INLINE fmap #-}

instance Applicative Decode where
  pure value = Decode $ \_ _ position -> Step position value
  {-# INLINE pure #-}
  Decode left <*> Decode right = Decode $ \source bytes position ->
    case left source bytes position of
      Failed -> Failed
      Step middle transform -> case right source bytes middle of
        Failed -> Failed
        Step next value -> Step next (transform value)
  {-# INLINE (<*>) #-}

instance Monad Decode where
  Decode action >>= continue = Decode $ \source bytes position ->
    case action source bytes position of
      Failed -> Failed
      Step next value -> case continue value of
        Decode rest -> rest source bytes next
  {-# INLINE (>>=) #-}

failDecode :: Decode a
failDecode = Decode $ \_ _ _ -> Failed

encodeFor :: Persist a => Source -> a -> ByteString
encodeFor source value = Lazy.toStrict (Builder.toLazyByteString (persist source value))

{-| Read a whole buffer, which must be consumed exactly. -}
decodeWith :: Persist a => Source -> ByteString -> Maybe a
decodeWith source bytes = case restore of
  Decode action -> case action source bytes 0 of
    Step end value | end == ByteString.length bytes -> Just value
    _ -> Nothing

byte :: Decode Word8
byte = Decode $ \_ bytes position ->
  if position < ByteString.length bytes
    then Step (position + 1) (Unsafe.unsafeIndex bytes position)
    else Failed
{-# INLINE byte #-}

{-| Seven bits at a time, low first, the high bit saying more follow. Most
    numbers a tree holds — offsets, lengths, tags — fit in one or two bytes.
    The number is taken as the 64 unsigned bits it occupies, so every value,
    including one that uses the top bit, is written in at most ten bytes. -}
putUnsigned :: Int -> Builder
putUnsigned = putWord . fromIntegral

putWord :: Word64 -> Builder
putWord value
  | value < 0x80 = Builder.word8 (fromIntegral value)
  | otherwise = Builder.word8 (fromIntegral (value .&. 0x7f) .|. 0x80) <> putWord (value `shiftR` 7)

getUnsigned :: Decode Int
getUnsigned = fromIntegral <$> getWord
{-# INLINE getUnsigned #-}

{-| Read directly off the buffer: one comparison for the common one-byte
    number, and no step of the decoder per byte for a longer one. More than
    ten bytes cannot be a 64-bit number and is a failure. -}
getWord :: Decode Word64
getWord = Decode $ \_ bytes position -> go bytes (ByteString.length bytes) position 0 0
 where
  go bytes size position shift accumulated
    | position >= size || shift > 63 = Failed
    | otherwise =
        let next = Unsafe.unsafeIndex bytes position
            value = accumulated .|. (fromIntegral (next .&. 0x7f) `shiftL` shift)
         in if next .&. 0x80 == 0
              then Step (position + 1) value
              else go bytes size (position + 1) (shift + 7) value
{-# INLINE getWord #-}

{-| Zigzag: a number and its negation are written the same size, `0, -1, 1,
    -2, …` as `0, 1, 2, 3, …`. It is computed on the unsigned bits, so a number
    of any magnitude — the bits of a `Float64`, `minBound` — survives the round
    trip; shifting the signed number overflowed from 2^62 on. -}
instance Persist Int where
  persist _ value =
    putWord ((fromIntegral value `shiftL` 1) `xor` fromIntegral (value `shiftR` 63))
  restore = do
    encoded <- getWord
    pure (fromIntegral (encoded `shiftR` 1) `xor` negate (fromIntegral (encoded .&. 1)))

instance Persist Bool where
  persist _ value = Builder.word8 (if value then 1 else 0)
  restore = do
    tag <- byte
    case tag of
      0 -> pure False
      1 -> pure True
      _ -> failDecode

instance Persist Char where
  persist _ = putUnsigned . ord
  restore = do
    code <- getUnsigned
    if code <= 0x10FFFF then pure (chr code) else failDecode

instance Persist Text where
  persist _ value =
    let encoded = Encoding.encodeUtf8 value
     in putUnsigned (ByteString.length encoded) <> Builder.byteString encoded
  restore = do
    size <- getUnsigned
    Decode $ \_ bytes position ->
      if size >= 0 && position + size <= ByteString.length bytes
        then case Encoding.decodeUtf8' (Unsafe.unsafeTake size (Unsafe.unsafeDrop position bytes)) of
          Right value -> Step (position + size) value
          Left _ -> Failed
        else Failed

instance Persist a => Persist [a] where
  persist source values = putUnsigned (length values) <> foldMap (persist source) values
  restore = do
    count <- getUnsigned
    go count []
   where
    go 0 accumulated = pure (reverse accumulated)
    go remaining accumulated = do
      value <- restore
      go (remaining - 1 :: Int) (value : accumulated)

instance Persist a => Persist (NonEmpty a) where
  persist source (first :| rest) = persist source first <> persist source rest
  restore = (:|) <$> restore <*> restore

instance Persist a => Persist (Maybe a) where
  persist _ Nothing = Builder.word8 0
  persist source (Just value) = Builder.word8 1 <> persist source value
  restore = do
    tag <- byte
    case tag of
      0 -> pure Nothing
      1 -> Just <$> restore
      _ -> failDecode

instance Persist ByteString where
  persist _ value = putUnsigned (ByteString.length value) <> Builder.byteString value
  restore = do
    size <- getUnsigned
    Decode $ \_ bytes position ->
      if size >= 0 && position + size <= ByteString.length bytes
        then Step (position + size) (ByteString.copy (Unsafe.unsafeTake size (Unsafe.unsafeDrop position bytes)))
        else Failed

instance (Persist a, Persist b) => Persist (a, b) where
  persist source (left, right) = persist source left <> persist source right
  restore = (,) <$> restore <*> restore

{-| A value stored as a block of its own, read only when it is first needed.

    A function's body is most of a tree and most bodies are never run: the
    standard library is mostly functions a given program does not call. Stored
    whole and read on demand, a run pays for the bodies it reaches. The entry
    the block sits in was checked whole before any of it was read, so a block
    that will not read is a fault in this compiler, not in the file. -}
persistDeferred :: Persist a => Source -> a -> Builder
persistDeferred source value =
  let encoded = encodeFor source value
   in putUnsigned (ByteString.length encoded) <> Builder.byteString encoded

restoreDeferred :: Persist a => Decode a
restoreDeferred = do
  size <- getUnsigned
  Decode $ \source bytes position ->
    if size >= 0 && position + size <= ByteString.length bytes
      then
        let block = Unsafe.unsafeTake size (Unsafe.unsafeDrop position bytes)
            value = case decodeWith source block of
              Just decoded -> decoded
              Nothing -> error "pudu: a stored function body could not be read; run with PUDU_CACHE=off"
         in Step (position + size) value
      else Failed

{-| A span is its two offsets in the source being written.

    Only the module's own spans are stored. A span into another source would
    have nothing to be rebound to when read, so meeting one is written as a
    marker that fails the read, and the entry is a miss rather than a tree
    pointing into the wrong text. -}
instance Persist Span where
  persist source value
    | spanSource value == sourceName source =
        putUnsigned (unOffset (spanStart value)) <> putUnsigned (unOffset (spanEnd value) - unOffset (spanStart value))
    | otherwise = Builder.word8 0xff <> Builder.word8 0xff <> Builder.word8 0xff <> Builder.word8 0xff <> Builder.word8 0x7f
  restore = do
    start <- getUnsigned
    width <- getUnsigned
    Decode $ \source _ position ->
      case (offsetFromInt start, offsetFromInt (start + width)) of
        (Just first, Just past) -> case mkSpan source first past of
          Just value -> Step position value
          Nothing -> Failed
        _ -> Failed

class GPersist f where
  gpersist :: Source -> f a -> Builder
  grestore :: Decode (f a)

instance GPersist V1 where
  gpersist _ value = case value of {}
  grestore = failDecode

instance GPersist U1 where
  gpersist _ U1 = mempty
  grestore = pure U1

instance (GPersist f, GPersist g) => GPersist (f :*: g) where
  gpersist source (left :*: right) = gpersist source left <> gpersist source right
  grestore = (:*:) <$> grestore <*> grestore

instance Persist c => GPersist (K1 i c) where
  gpersist source (K1 value) = persist source value
  grestore = K1 <$> restore

instance GPersist f => GPersist (M1 D d f) where
  gpersist source (M1 value) = gpersist source value
  grestore = M1 <$> grestore

instance GPersist f => GPersist (M1 C c f) where
  gpersist source (M1 value) = gpersist source value
  grestore = M1 <$> grestore

instance GPersist f => GPersist (M1 S s f) where
  gpersist source (M1 value) = gpersist source value
  grestore = M1 <$> grestore

{-| A sum is its constructor's position among the alternatives, then that
    constructor's fields.

    How many constructors each side of a sum holds is a type-level number, so
    it is a constant in the compiled code rather than something counted again
    at every node read. -}
type family SumSize (f :: Type -> Type) :: Nat where
  SumSize (f :+: g) = SumSize f + SumSize g
  SumSize (M1 C c f) = 1

sumSize :: forall f. KnownNat (SumSize f) => Proxy f -> Int
sumSize _ = fromIntegral (natVal (Proxy @(SumSize f)))
{-# INLINE sumSize #-}

instance (GSum f, GSum g, KnownNat (SumSize f), KnownNat (SumSize (f :+: g))) => GPersist (f :+: g) where
  gpersist source value = gsumPersist source 0 value
  {-# INLINE gpersist #-}
  grestore = do
    tag <- getUnsigned
    if tag < sumSize (Proxy @(f :+: g)) then gsumRestore tag 0 else failDecode
  {-# INLINE grestore #-}

class GSum f where
  gsumPersist :: Source -> Int -> f a -> Builder
  gsumRestore :: Int -> Int -> Decode (f a)

instance (GSum f, GSum g, KnownNat (SumSize f)) => GSum (f :+: g) where
  gsumPersist source base (L1 value) = gsumPersist source base value
  gsumPersist source base (R1 value) = gsumPersist source (base + sumSize (Proxy @f)) value
  {-# INLINE gsumPersist #-}
  gsumRestore tag base
    | tag < base + sumSize (Proxy @f) = L1 <$> gsumRestore tag base
    | otherwise = R1 <$> gsumRestore tag (base + sumSize (Proxy @f))
  {-# INLINE gsumRestore #-}

instance GPersist f => GSum (M1 C c f) where
  gsumPersist source base value = putUnsigned base <> gpersist source value
  {-# INLINE gsumPersist #-}
  gsumRestore _ _ = grestore
  {-# INLINE gsumRestore #-}
