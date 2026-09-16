{-| @Eval.Foreign.Result — converts only the native shape promised by the declaration -}
module Pudu.Eval.Foreign.Result
  ( ConversionFailure (..)
  , convertForeignValue
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Word (Word64)
import Pudu.Eval.Value (Value (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Foreign.Call (CrossedValue (..))
import Pudu.Foreign.Crossing (Crossing (..), fitsCrossing)
import Pudu.IntegerLiteral (IntegerKind (..))

{-| A missing pointer is distinct from a carrier outside the declared shape. -}
data ConversionFailure = MissingText !Text | InvalidShape
  deriving stock (Eq, Show)

convertForeignValue :: Text -> Crossing -> CrossedValue -> Either ConversionFailure Value
convertForeignValue label crossing produced = case (crossing, produced) of
  (NothingCrossing, _) -> Right UnitValue
  (BooleanCrossing, CrossedInteger held) -> Right (BoolValue (held /= 0))
  (FloatingCrossing 32, CrossedDouble held) -> Right (FloatValue Float32Width held)
  (FloatingCrossing 64, CrossedDouble held) -> Right (FloatValue Float64Width held)
  (SignedCrossing width, CrossedInteger held)
    | width `elem` [8, 16, 32, 64] && fitsCrossing crossing (toInteger held) ->
        Right (IntValue (SignedKind width) (toInteger held))
  (UnsignedCrossing width, CrossedInteger held)
    | width `elem` [8, 16, 32, 64] && fitsCrossing crossing (unsigned width held) ->
        Right (IntValue (UnsignedKind width) (unsigned width held))
  (TextCrossing, CrossedText text) -> Right (StrValue text)
  (TextCrossing, CrossedNoText) -> Left (MissingText label)
  (RecordCrossing name declared, CrossedRecord actual fields)
    | name == actual && map fst declared == map fst fields ->
        RecordValue name <$> traverse field (zip declared fields)
  _ -> Left InvalidShape
 where
  field ((name, kind), (_, value)) = case kind of
    NothingCrossing -> Left InvalidShape
    HandleCrossing _ -> Left InvalidShape
    BytesCrossing -> Left InvalidShape
    _ -> do
      converted <- convertForeignValue name kind value
      pure (name, converted)

unsigned :: Int -> Int64 -> Integer
unsigned width held
  | width == 64 = toInteger (fromIntegral held :: Word64)
  | otherwise = toInteger held
