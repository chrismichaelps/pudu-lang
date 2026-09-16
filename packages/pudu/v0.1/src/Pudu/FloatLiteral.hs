{-| @Pudu.FloatLiteral.Module — converts and normalizes floating literals -}
module Pudu.FloatLiteral
  ( FloatWidth (..)
  , ParsedFloat (..)
  , floatSuffix
  , floatWidthType
  , normalizeFloat
  , parseFloatLiteral
  , splitFloatSuffix
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Float (double2Float, float2Double)
import Text.Read (readMaybe)

data FloatWidth = Float32Width | Float64Width
  deriving stock (Eq, Ord, Show)

data ParsedFloat = ParsedFloat
  { parsedFloatValue :: !Double
  , parsedFloatWidth :: !FloatWidth
  , parsedFloatFits :: !Bool
  }
  deriving stock (Eq, Show)

floatSuffix :: Text -> Maybe FloatWidth
floatSuffix text = lookup text suffixes

floatWidthType :: FloatWidth -> Text
floatWidthType width = case width of
  Float32Width -> "Float32"
  Float64Width -> "Float64"

splitFloatSuffix :: Text -> (Text, Maybe FloatWidth)
splitFloatSuffix text = firstSuffix suffixes
 where
  firstSuffix candidates = case candidates of
    [] -> (text, Nothing)
    (suffixText, width) : rest -> case Text.stripSuffix suffixText text of
      Just body -> (body, Just width)
      Nothing -> firstSuffix rest

parseFloatLiteral :: Text -> Maybe ParsedFloat
parseFloatLiteral source =
  let (body, selected) = splitFloatSuffix source
      width = maybe Float64Width id selected
      input = Text.unpack (Text.filter (/= '_') body)
   in case width of
        Float32Width -> do
          value <- readMaybe input :: Maybe Float
          pure
            ParsedFloat
              { parsedFloatValue = float2Double value
              , parsedFloatWidth = width
              , parsedFloatFits = not (isInfinite value)
              }
        Float64Width -> do
          value <- readMaybe input :: Maybe Double
          pure
            ParsedFloat
              { parsedFloatValue = value
              , parsedFloatWidth = width
              , parsedFloatFits = not (isInfinite value)
              }

normalizeFloat :: FloatWidth -> Double -> Double
normalizeFloat width value = case width of
  Float32Width -> float2Double (double2Float value)
  Float64Width -> value

suffixes :: [(Text, FloatWidth)]
suffixes = [("f32", Float32Width), ("f64", Float64Width)]
