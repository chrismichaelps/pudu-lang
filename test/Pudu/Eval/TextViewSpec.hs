{-| @Test.Eval.TextViewSpec — byte-addressed text reads against a byte-level model -}
module Pudu.Eval.TextViewSpec
  ( testTextView
  ) where

import qualified Data.ByteString as ByteString
import Data.Bits ((.&.))
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Eval.TextView (byteFind, byteFindLast, byteSlice, scalarAt)
import Test.QuickCheck
  ( Gen
  , Property
  , choose
  , conjoin
  , counterexample
  , elements
  , forAll
  , listOf
  , oneof
  , property
  , (===)
  )

{-| One-, two-, three- and four-byte scalars, so every offset kind occurs. -}
scalarText :: Gen Text
scalarText = Text.pack <$> listOf (elements "ab,é中😀")

{-| A needle cut from the text itself, so matches occur, or drawn freshly. -}
needleFor :: Text -> Gen Text
needleFor text = oneof
  [ do
      let size = Text.length text
      start <- choose (0, size)
      count <- choose (0, size - start)
      pure (Text.take count (Text.drop start text))
  , scalarText
  ]

bytesOf :: Text -> ByteString.ByteString
bytesOf = Encoding.encodeUtf8

isBoundary :: ByteString.ByteString -> Integer -> Bool
isBoundary bytes at
  | at < 0 || at > size = False
  | at == size = True
  | otherwise = ByteString.index bytes (fromInteger at) .&. 0xC0 /= 0x80
 where
  size = toInteger (ByteString.length bytes)

matchesAt :: ByteString.ByteString -> ByteString.ByteString -> Integer -> Bool
matchesAt bytes needle at = needle `ByteString.isPrefixOf` ByteString.drop (fromInteger at) bytes

testTextView :: IO Property
testTextView = pure $ forAll scalarText $ \text ->
  forAll (needleFor text) $ \needle ->
    let bytes = bytesOf text
        needleBytes = bytesOf needle
        size = toInteger (ByteString.length bytes)
        offsets = [-2 .. size + 2]
        modelSlice start end
          | start <= end && isBoundary bytes start && isBoundary bytes end =
              Just (Encoding.decodeUtf8 (ByteString.take (fromInteger (end - start)) (ByteString.drop (fromInteger start) bytes)))
          | otherwise = Nothing
        modelFind from
          | from < 0 || from > size = Nothing
          | otherwise = find (matchesAt bytes needleBytes) [from .. size]
        modelFindLast = find (matchesAt bytes needleBytes) (reverse [0 .. size])
        modelScalar at
          | at < size && isBoundary bytes at =
              case Text.uncons (Encoding.decodeUtf8 (ByteString.drop (fromInteger at) bytes)) of
                Just (scalar, _) -> Just (scalar, ByteString.length (bytesOf (Text.singleton scalar)))
                Nothing -> Nothing
          | otherwise = Nothing
     in conjoin
          [ counterexample "slice" (property (and [byteSlice text a b == modelSlice a b | a <- offsets, b <- offsets]))
          , counterexample "find" (property (and [byteFind text needle from == modelFind from | from <- offsets]))
          , counterexample "find last" (byteFindLast text needle === modelFindLast)
          , counterexample "scalar" (property (and [scalarAt text at == modelScalar at | at <- offsets]))
          ]
