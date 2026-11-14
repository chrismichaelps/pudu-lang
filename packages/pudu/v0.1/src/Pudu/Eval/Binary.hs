{-| @Eval.Binary — writes and reads `Std.Binary` node trees as compact bytes natively.

    The wire form is a table of the distinct field and variant names, each
    written once, followed by the root node. Every node starts with one tag
    byte; fixed-width values are little-endian, and anything of variable size
    carries a 32-bit count or length first. A record refers to its field names
    by table index, so names cost their bytes once per archive however many
    records share them, and reading needs no hashing: a decoded record is a
    map from name to node. -}
module Pudu.Eval.Binary
  ( callBinaryDecode
  , callBinaryEncode
  , decodeNodes
  , encodeNode
  , wireCount
  ) where

import Data.Bits (shiftL, (.|.))
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.ByteString.Unsafe as Unsafe
import Data.Foldable (toList)
import Data.Int (Int64)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Word (Word32, Word64, Word8)
import GHC.Float (castDoubleToWord64, castWord64ToDouble)

import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (OrdValue (..), Value (..), intOf)
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Pudu.Source (Span)

{-| `binaryEncode(node)`: a `Std.Binary.Node` tree as bytes. -}
callBinaryEncode :: Span -> [Value] -> Evaluator Value
callBinaryEncode spanValue arguments = case arguments of
  [node] -> case encodeNode node of
    Just bytes -> pure (BytesValue bytes)
    Nothing -> abortAt (Just spanValue) "E7001" "binaryEncode expects a Std.Binary node" Nothing
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for binaryEncode" Nothing

{-| `binaryDecode(bytes)`: the node tree the bytes hold, or why they hold none. -}
callBinaryDecode :: Span -> [Value] -> Evaluator Value
callBinaryDecode spanValue arguments = case arguments of
  [BytesValue bytes] -> pure $ case decodeNodes bytes of
    Right node -> VariantValue "Ok" [node]
    Left problem -> VariantValue "Err" [StrValue problem]
  _ -> abortAt (Just spanValue) "E7012" "wrong arguments for binaryDecode" Nothing

-- Node tags. The order is the wire contract.
tagWhole, tagReal, tagFlag, tagText, tagRaw, tagReals, tagItems, tagAbsent, tagPresent, tagFields, tagChoice :: Word8
tagWhole = 0
tagReal = 1
tagFlag = 2
tagText = 3
tagRaw = 4
tagReals = 5
tagItems = 6
tagAbsent = 7
tagPresent = 8
tagFields = 9
tagChoice = 10

{-| How deep nodes may nest before reading or writing refuses, so hostile input cannot
    exhaust the stack. -}
maximumDepth :: Int
maximumDepth = 512

-- Names in first-use order with their table index, and the count so far.
data Names = Names !(Map.Map Text Word32) !Word32

{-| Refuse unsupported extents before narrowing a wire prefix. -}
wireCount :: Integer -> Maybe Word32
wireCount count
  | count >= 0 && count <= toInteger (maxBound :: Word32) = Just (fromInteger count)
  | otherwise = Nothing

{-| A node tree as bytes, or nothing when the value is not a node tree. -}
encodeNode :: Value -> Maybe ByteString.ByteString
encodeNode root = do
  (Names table count, body) <- nodeOf 0 (Names Map.empty 0) root
  names <- traverse textOf (map fst (sortOn snd (Map.toList table)))
  let header = word32 count <> mconcat names
  Just (LazyByteString.toStrict (Builder.toLazyByteString (header <> body)))
 where
  nodeOf depth names value
    | depth > maximumDepth = Nothing
    | otherwise = nodeWith depth names value
  nodeWith depth names value = case value of
    VariantValue "Whole" [IntValue _ number]
      | number >= toInteger (minBound :: Int64) && number <= toInteger (maxBound :: Int64) ->
          Just (names, Builder.word8 tagWhole <> Builder.int64LE (fromInteger number))
    VariantValue "Real" [FloatValue _ number] ->
      Just (names, Builder.word8 tagReal <> Builder.word64LE (castDoubleToWord64 number))
    VariantValue "Flag" [BoolValue flag] ->
      Just (names, Builder.word8 tagFlag <> Builder.word8 (if flag then 1 else 0))
    VariantValue "Text" [StrValue content] -> do
      part <- textOf content
      Just (names, Builder.word8 tagText <> part)
    VariantValue "Raw" [BytesValue bytes] -> do
      part <- bytesOf bytes
      Just (names, Builder.word8 tagRaw <> part)
    VariantValue "Reals" [BytesValue bytes]
      | ByteString.length bytes `mod` 8 == 0 -> do
          count <- wireCount (toInteger (ByteString.length bytes `div` 8))
          Just (names, Builder.word8 tagReals <> word32 count <> Builder.byteString bytes)
    VariantValue "Items" [ArrayValue members] -> do
      count <- wireCount (toInteger (Seq.length members))
      (after, parts) <- many (depth + 1) names (toList members)
      Just (after, Builder.word8 tagItems <> word32 count <> parts)
    VariantValue "Absent" [] -> Just (names, Builder.word8 tagAbsent)
    VariantValue "Present" [held] -> do
      (after, part) <- nodeOf (depth + 1) names held
      Just (after, Builder.word8 tagPresent <> part)
    VariantValue "Fields" [ArrayValue entries] -> do
      (after, part) <- fieldsOf depth names (toList entries)
      Just (after, Builder.word8 tagFields <> part)
    VariantValue "Record" [MapValue entries] -> do
      (after, part) <- fieldsOf depth names (mapEntries entries)
      Just (after, Builder.word8 tagFields <> part)
    VariantValue "Choice" [StrValue name, ArrayValue entries] -> do
      (named, index) <- intern names name
      (after, part) <- fieldsOf depth named (toList entries)
      Just (after, Builder.word8 tagChoice <> word32 index <> part)
    VariantValue "Picked" [StrValue name, MapValue entries] -> do
      (named, index) <- intern names name
      (after, part) <- fieldsOf depth named (mapEntries entries)
      Just (after, Builder.word8 tagChoice <> word32 index <> part)
    _ -> Nothing

  many depth names values = case values of
    [] -> Just (names, mempty)
    value : rest -> do
      (after, part) <- nodeOf depth names value
      (final, parts) <- many depth after rest
      Just (final, part <> parts)

  fieldsOf depth names entries = do
    count <- wireCount (toInteger (length entries))
    (after, parts) <- go names Set.empty entries
    Just (after, word32 count <> parts)
   where
    go current seen remaining = case remaining of
      [] -> Just (current, mempty)
      TupleValue [StrValue name, held] : rest | Set.notMember name seen -> do
        (named, index) <- intern current name
        (after, part) <- nodeOf (depth + 1) named held
        (final, parts) <- go after (Set.insert name seen) rest
        Just (final, word32 index <> part <> parts)
      _ -> Nothing

  mapEntries entries = [TupleValue [key, held] | (OrdValue key, held) <- Map.toAscList entries]

  intern names@(Names table count) name = case Map.lookup name table of
    Just index -> Just (names, index)
    Nothing -> do
      next <- wireCount (toInteger count + 1)
      Just (Names (Map.insert name count table) next, count)

  textOf content = bytesOf (Encoding.encodeUtf8 content)
  bytesOf bytes = do
    count <- wireCount (toInteger (ByteString.length bytes))
    Just (word32 count <> Builder.byteString bytes)
  word32 = Builder.word32LE

{-| The node tree bytes hold, or the first problem found in them. Every
    length is checked against the bytes left before anything is copied. -}
decodeNodes :: ByteString.ByteString -> Either Text Value
decodeNodes bytes = do
  (count, afterCount) <- word32At 0
  (names, afterNames) <- namesFrom (fromIntegral count) afterCount []
  let table = Seq.fromList names
  (root, end) <- nodeAt table 0 afterNames
  if end == ByteString.length bytes then Right root else Left (Text.pack (show (ByteString.length bytes - end) <> " bytes follow the root node"))
 where
  size = ByteString.length bytes

  need offset count
    | count < 0 || offset + count > size = Left "the bytes end inside a node"
    | otherwise = Right ()

  byteAt offset = need offset 1 >> Right (Unsafe.unsafeIndex bytes offset)

  word32At offset = do
    need offset 4
    let at index = fromIntegral (Unsafe.unsafeIndex bytes (offset + index)) :: Word32
    Right (at 0 .|. at 1 `shiftL` 8 .|. at 2 `shiftL` 16 .|. at 3 `shiftL` 24, offset + 4)

  word64At offset = do
    need offset 8
    let at index = fromIntegral (Unsafe.unsafeIndex bytes (offset + index)) :: Word64
    Right (foldl' (\held index -> held .|. at index `shiftL` (8 * index)) 0 [0 .. 7], offset + 8)

  sliceAt offset = do
    (length', afterLength) <- word32At offset
    let count = fromIntegral length'
    need afterLength count
    Right (ByteString.take count (ByteString.drop afterLength bytes), afterLength + count)

  textAt offset = do
    (raw, after) <- sliceAt offset
    case Encoding.decodeUtf8' raw of
      Right content -> Right (content, after)
      Left _ -> Left "text that is not UTF-8"

  namesFrom remaining offset collected
    | remaining == (0 :: Int) = Right (reverse collected, offset)
    | otherwise = do
        (name, after) <- textAt offset
        namesFrom (remaining - 1) after (name : collected)

  nodeAt table depth offset
    | depth > maximumDepth = Left "nodes nest deeper than 512"
    | otherwise = do
        tag <- byteAt offset
        let body = offset + 1
        case tag of
          _ | tag == tagWhole -> do
                (bits, after) <- word64At body
                Right (SumValue "Std.Binary.Node" "Whole" [intOf (toInteger (fromIntegral bits :: Int64))], after)
            | tag == tagReal -> do
                (bits, after) <- word64At body
                Right (SumValue "Std.Binary.Node" "Real" [FloatValue Float64Width (castWord64ToDouble bits)], after)
            | tag == tagFlag -> do
                flag <- byteAt body
                if flag > 1 then Left "a flag byte above 1" else Right (SumValue "Std.Binary.Node" "Flag" [BoolValue (flag == 1)], body + 1)
            | tag == tagText -> do
                (content, after) <- textAt body
                Right (SumValue "Std.Binary.Node" "Text" [StrValue content], after)
            | tag == tagRaw -> do
                (raw, after) <- sliceAt body
                Right (SumValue "Std.Binary.Node" "Raw" [BytesValue raw], after)
            | tag == tagReals -> do
                (count, afterCount) <- word32At body
                let width = fromIntegral count * 8
                need afterCount width
                Right (SumValue "Std.Binary.Node" "Reals" [BytesValue (ByteString.take width (ByteString.drop afterCount bytes))], afterCount + width)
            | tag == tagItems -> do
                (count, afterCount) <- word32At body
                (members, after) <- itemsFrom table (depth + 1) (fromIntegral count) afterCount Seq.empty
                Right (SumValue "Std.Binary.Node" "Items" [ArrayValue members], after)
            | tag == tagAbsent -> Right (SumValue "Std.Binary.Node" "Absent" [], body)
            | tag == tagPresent -> do
                (held, after) <- nodeAt table (depth + 1) body
                Right (SumValue "Std.Binary.Node" "Present" [held], after)
            | tag == tagFields -> do
                (entries, after) <- fieldsFrom table (depth + 1) body
                Right (SumValue "Std.Binary.Node" "Record" [MapValue entries], after)
            | tag == tagChoice -> do
                (index, afterIndex) <- word32At body
                name <- nameAt table index
                (entries, after) <- fieldsFrom table (depth + 1) afterIndex
                Right (SumValue "Std.Binary.Node" "Picked" [StrValue name, MapValue entries], after)
            | otherwise -> Left (Text.pack ("an unknown node tag " <> show tag))

  itemsFrom table depth remaining offset collected
    | remaining == (0 :: Int) = Right (collected, offset)
    | otherwise = do
        (member, after) <- nodeAt table depth offset
        itemsFrom table depth (remaining - 1) after (collected Seq.|> member)

  fieldsFrom table depth offset = do
    (count, afterCount) <- word32At offset
    go (fromIntegral count :: Int) afterCount Map.empty
   where
    go remaining at collected
      | remaining == 0 = Right (collected, at)
      | otherwise = do
          (index, afterIndex) <- word32At at
          name <- nameAt table index
          let key = OrdValue (StrValue name)
          if Map.member key collected
            then Left ("the field " <> name <> " appears twice")
            else do
              (held, after) <- nodeAt table depth afterIndex
              go (remaining - 1) after (Map.insert key held collected)

  nameAt table index = case Seq.lookup (fromIntegral index) table of
    Just name -> Right name
    Nothing -> Left (Text.pack ("a name index " <> show index <> " past the name table"))
