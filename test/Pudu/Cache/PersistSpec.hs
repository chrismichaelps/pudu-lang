{-| @Test.Cache.Persist — what the product cache stores reads back as it was -}
module Pudu.Cache.PersistSpec (persistProperties) where

import GHC.Float (castDoubleToWord64)
import Pudu.Cache.Persist (decodeWith, encodeFor)
import Pudu.Eval.Frozen (freeze, thaw)
import Pudu.Eval.Value (Value (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Source (SourceName (..), newSource)
import Test.QuickCheck (Property, arbitrary, counterexample, elements, forAll, oneof, (===))

persistProperties :: [(String, IO Property)]
persistProperties =
  [ ("an integer of any magnitude survives storage", testIntegers)
  , ("an unbounded integer survives storage digit for digit", testUnbounded)
  , ("a stored float constant reads back bit for bit", testFloats)
  ]

testIntegers :: IO Property
testIntegers = do
  source <- newSource (SourceName "persist") ""
  let extremes = [minBound, maxBound, 2 ^ (62 :: Int), negate (2 ^ (62 :: Int)), 2 ^ (62 :: Int) - 1, 0, -1, 1]
  pure $ forAll (oneof [arbitrary, elements extremes]) $ \number ->
    decodeWith source (encodeFor source number) === Just (number :: Int)

testUnbounded :: IO Property
testUnbounded = do
  source <- newSource (SourceName "persist") ""
  let extremes = [0, -1, 2 ^ (64 :: Int), negate (2 ^ (200 :: Int)), 123456789012345678901234567890]
  pure $ forAll (oneof [(* (2 ^ (70 :: Int))) <$> arbitrary, elements extremes]) $ \number ->
    decodeWith source (encodeFor source number) === Just (number :: Integer)

testFloats :: IO Property
testFloats = do
  source <- newSource (SourceName "persist") ""
  let special = [3.14159, 0, -0.0, 1 / 0, -1 / 0, 5.0e-324, 1.7976931348623157e308]
  pure $ forAll (oneof [arbitrary, elements special]) $ \number ->
    case freeze (FloatValue Float64Width number) >>= decodeWith source . encodeFor source of
      Just stored -> case thaw stored of
        FloatValue Float64Width back -> castDoubleToWord64 back === castDoubleToWord64 number
        _ -> counterexample "a float read back as something else" False
      Nothing -> counterexample "a stored float could not be read" False
