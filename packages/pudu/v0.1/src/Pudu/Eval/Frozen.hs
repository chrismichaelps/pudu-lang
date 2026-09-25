{-| @Eval.Frozen.Module — constant values that may outlive the evaluation that made them -}
module Pudu.Eval.Frozen
  ( Frozen
  , freeze
  , thaw
  ) where

import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import qualified Data.Set as Set
import qualified Data.Text as Text
import Data.Foldable (toList)
import GHC.Float (castDoubleToWord64, castWord64ToDouble)
import Pudu.Cache.Persist (Decode, Persist (..), failDecode)
import Pudu.DecimalLiteral (Decimal (..))
import Pudu.Eval.Value (OrdValue (..), Value (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))

{-| A constant's value, when it is plain data.

    Folding a module's constants already evaluated them, with effects denied and
    nothing but the module and the language in scope, so what folding computed
    is what linking would compute again. A value made only of numbers, text,
    bytes, ranges, and the collections, records, and variants built from them
    owns nothing and captures nothing, and can be installed in place of running
    its initializer a second time. A function, a task, a method, or anything
    foreign carries an environment or a resource of the evaluation that made it,
    and is never frozen: such a constant is evaluated again, as before. -}
newtype Frozen = Frozen Value
  deriving stock (Eq, Show)

freeze :: Value -> Maybe Frozen
freeze value
  | portable value = Just (Frozen value)
  | otherwise = Nothing

thaw :: Frozen -> Value
thaw (Frozen value) = value

portable :: Value -> Bool
portable value = case value of
  IntValue _ _ -> True
  FloatValue _ _ -> True
  DecimalValue _ -> True
  StrValue _ -> True
  BytesValue _ -> True
  BucketsValue items -> all portable (IntMap.elems items)
  RangeValue {} -> True
  CharValue _ -> True
  BoolValue _ -> True
  NullValue -> True
  UnitValue -> True
  TupleValue items -> all portable items
  ArrayValue items -> all portable (toList items)
  MapValue items -> all (portable . unOrdValue) (Map.keys items) && all portable (Map.elems items)
  SetValue items -> all (portable . unOrdValue) (Set.toList items)
  RecordValue _ fields -> all (portable . snd) fields
  VariantValue _ payload -> all portable payload
  _ -> False

instance Persist Frozen where
  persist source (Frozen value) = encodeValue value
   where
    encodeValue current = case current of
      IntValue kind number -> tag 0 <> persist source (kindCode kind) <> persistInteger number
      FloatValue width number ->
        tag 1 <> persist source (width == Float32Width) <> persist source (fromIntegral (castDoubleToWord64 number) :: Int)
      DecimalValue decimal ->
        tag 2 <> persistInteger (decimalCoefficient decimal) <> persist source (decimalScale decimal)
      StrValue text -> tag 3 <> persist source text
      BytesValue bytes -> tag 4 <> persist source bytes
      BucketsValue items ->
        tag 5 <> persist source (IntMap.size items)
          <> foldMap (\(key, item) -> persist source key <> encodeValue item) (IntMap.toAscList items)
      RangeValue from inclusive to ->
        tag 6 <> maybeInteger from <> persist source inclusive <> maybeInteger to
      CharValue character -> tag 7 <> persist source character
      BoolValue flag -> tag 8 <> persist source flag
      NullValue -> tag 9
      UnitValue -> tag 10
      TupleValue items -> tag 11 <> many items
      ArrayValue items -> tag 12 <> many (toList items)
      MapValue items ->
        tag 13 <> persist source (Map.size items)
          <> foldMap (\(key, item) -> encodeValue (unOrdValue key) <> encodeValue item) (Map.toAscList items)
      SetValue items -> tag 14 <> many (map unOrdValue (Set.toAscList items))
      RecordValue name fields ->
        tag 15 <> persist source name <> persist source (length fields)
          <> foldMap (\(field, item) -> persist source field <> encodeValue item) fields
      VariantValue name payload -> tag 16 <> persist source name <> many payload
      _ -> tag 255
    tag code = persist source (code :: Int)
    many items = persist source (length items) <> foldMap encodeValue items
    maybeInteger = maybe (persist source False) (\number -> persist source True <> persistInteger number)
    persistInteger number = persist source (Text.pack (show number))

  restore = Frozen <$> decodeValue
   where
    decodeValue :: Decode Value
    decodeValue = do
      code <- restore :: Decode Int
      case code of
        0 -> IntValue <$> (restore >>= kindOf) <*> restoreInteger
        1 -> do
          narrow <- restore
          bits <- restore :: Decode Int
          pure (FloatValue (if narrow then Float32Width else Float64Width) (castWord64ToDouble (fromIntegral bits)))
        2 -> DecimalValue <$> (Decimal <$> restoreInteger <*> restore)
        3 -> StrValue <$> restore
        4 -> BytesValue <$> restore
        5 -> do
          count <- restore
          BucketsValue . IntMap.fromList <$> counted count ((,) <$> restore <*> decodeValue)
        6 -> RangeValue <$> restoreMaybeInteger <*> restore <*> restoreMaybeInteger
        7 -> CharValue <$> restore
        8 -> BoolValue <$> restore
        9 -> pure NullValue
        10 -> pure UnitValue
        11 -> TupleValue <$> restoreMany
        12 -> ArrayValue . Seq.fromList <$> restoreMany
        13 -> do
          count <- restore
          MapValue . Map.fromList <$> counted count ((,) <$> (OrdValue <$> decodeValue) <*> decodeValue)
        14 -> SetValue . Set.fromList . map OrdValue <$> restoreMany
        15 -> do
          name <- restore
          count <- restore
          RecordValue name <$> counted count ((,) <$> restore <*> decodeValue)
        16 -> VariantValue <$> restore <*> restoreMany
        _ -> failDecode
    restoreMany = do
      count <- restore
      counted count decodeValue
    counted :: Int -> Decode a -> Decode [a]
    counted count item
      | count < 0 = failDecode
      | otherwise = go count []
     where
      go 0 accumulated = pure (reverse accumulated)
      go remaining accumulated = do
        next <- item
        go (remaining - 1) (next : accumulated)
    restoreInteger = do
      written <- restore
      case reads (Text.unpack written) of
        [(number, "")] -> pure number
        _ -> failDecode
    restoreMaybeInteger = do
      present <- restore
      if present then Just <$> restoreInteger else pure Nothing
    kindOf :: Int -> Decode IntegerKind
    kindOf code = case code of
      0 -> pure PlatformSigned
      1 -> pure PlatformUnsigned
      2 -> pure BigIntKind
      _
        | code >= 1000 -> pure (UnsignedKind (code - 1000))
        | code >= 100 -> pure (SignedKind (code - 100))
        | otherwise -> failDecode

kindCode :: IntegerKind -> Int
kindCode kind = case kind of
  PlatformSigned -> 0
  PlatformUnsigned -> 1
  BigIntKind -> 2
  SignedKind width -> 100 + width
  UnsignedKind width -> 1000 + width
