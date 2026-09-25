{-| @Eval.Csv — reads separated records out of bytes natively. -}
module Pudu.Eval.Csv
  ( callCsvRecords
  , scanRecords
  ) where

import Data.Bits ((.&.))
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Unsafe as Unsafe
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word8)

import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.Source (Span)

{-| `csvRecords(buffer, delimiter)`: the complete records at the front of a
    buffer, the bytes and the characters they span, or `None` when one of them
    is not valid text.

    The remainder is left to the caller, which carries it into the next read,
    because a record divided by a read boundary is one record. -}
callCsvRecords :: Span -> [Value] -> Evaluator Value
callCsvRecords spanValue arguments = case arguments of
  [BytesValue buffer, StrValue delimiter] -> case delimiterByte delimiter of
    Nothing ->
      abortAt (Just spanValue) "E7004"
        "csvRecords reads a one-byte delimiter other than a quote or a line ending" Nothing
    Just byte -> pure $ case scanRecords byte buffer of
      Nothing -> VariantValue "None" []
      Just (rows, used, characters) ->
        VariantValue "Some"
          [ TupleValue
              [ ArrayValue (Seq.fromList (map rowValue rows))
              , intOf (toInteger used)
              , intOf (toInteger characters)
              ]
          ]
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for csvRecords" Nothing
 where
  rowValue fields = ArrayValue (Seq.fromList (map StrValue fields))

{-| How far a scan of one record got. -}
data Scanned
  = Complete ![Text] !Int
  | Incomplete
  | Invalid

{-| The complete records at the front of a buffer, with the bytes and
    characters they span.

    Outside quotes the scan searches for the next quote, delimiter, or newline;
    inside quotes it searches for the next quote alone. The bytes between are
    kept as slices and a field is joined and decoded once when it ends. A quote
    in the last byte leaves its record incomplete, because the byte after it
    decides whether it closes the field or begins an escaped pair. -}
scanRecords :: Word8 -> ByteString.ByteString -> Maybe ([[Text]], Int, Int)
scanRecords delimiter buffer = records 0 []
 where
  size = ByteString.length buffer

  records start done = case outside start [] [] of
    Invalid -> Nothing
    Incomplete ->
      let characters = characterCount (ByteString.take start buffer)
       in characters `seq` Just (reverse done, start, characters)
    Complete fields next -> records next (fields : done)

  outside from fields pieces = case ByteString.findIndex structural (ByteString.drop from buffer) of
    Nothing -> Incomplete
    Just offset ->
      let at = from + offset
          held = ByteString.take offset (ByteString.drop from buffer) : pieces
          byte = Unsafe.unsafeIndex buffer at
       in if byte == quote
            then inside (at + 1) fields held
            else case fieldOf (byte == newline) held of
              Nothing -> Invalid
              Just field
                | byte == newline -> Complete (reverse (field : fields)) (at + 1)
                | otherwise -> outside (at + 1) (field : fields) []

  inside from fields pieces = case ByteString.elemIndex quote (ByteString.drop from buffer) of
    Nothing -> Incomplete
    Just offset ->
      let at = from + offset
          held = ByteString.take offset (ByteString.drop from buffer) : pieces
       in if at + 1 >= size
            then Incomplete
            else
              if Unsafe.unsafeIndex buffer (at + 1) == quote
                then inside (at + 2) fields (quoteBytes : held)
                else outside (at + 1) fields held

  structural byte = byte == quote || byte == delimiter || byte == newline

{-| One field's pieces joined and decoded. A carriage return ending a
    record's last field is dropped, as the library's character scanner drops
    it. -}
fieldOf :: Bool -> [ByteString.ByteString] -> Maybe Text
fieldOf ending pieces =
  let joined = ByteString.concat (reverse pieces)
      trimmed
        | ending && not (ByteString.null joined) && ByteString.last joined == carriageReturn =
            ByteString.init joined
        | otherwise = joined
   in either (const Nothing) Just (Encoding.decodeUtf8' trimmed)

quote :: Word8
quote = 34

newline :: Word8
newline = 10

carriageReturn :: Word8
carriageReturn = 13

quoteBytes :: ByteString.ByteString
quoteBytes = ByteString.singleton quote

{-| The characters valid UTF-8 bytes encode: every byte that does not continue
    a sequence begins one. -}
characterCount :: ByteString.ByteString -> Int
characterCount =
  ByteString.foldl' (\total byte -> if byte .&. 0xC0 == 0x80 then total else total + 1) 0

{-| The delimiter as the byte the scan compares, when it is one byte that is
    not a quote or a line ending. -}
delimiterByte :: Text -> Maybe Word8
delimiterByte text = case Text.unpack text of
  [character]
    | character < '\x80' && character /= '"' && character /= '\n' && character /= '\r' ->
        Just (fromIntegral (fromEnum character))
  _ -> Nothing
