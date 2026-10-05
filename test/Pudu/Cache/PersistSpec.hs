{-| @Test.Cache.Persist — what the product cache stores reads back as it was -}
module Pudu.Cache.PersistSpec (persistProperties) where

import GHC.Float (castDoubleToWord64)
import Data.List.NonEmpty (NonEmpty ((:|)))
import Pudu.Cache.Persist (Persist, decodeWith, encodeFor)
import Pudu.Eval.Frozen (freeze, thaw)
import qualified Pudu.Eval.Value as Value
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Frontend.Syntax
  ( Attribute (..)
  , Block (..)
  , ComptimeFor (..)
  , Constraint (..)
  , Derive (..)
  , DeriveRequest (..)
  , DeriveShape (..)
  , Expression (..)
  , Literal (..)
  , Located (..)
  , TypeSyntax (..)
  , Visibility (..)
  )
import Pudu.Frontend.Syntax.Stored ()
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Source, SourceName (..), emptySpan, newSource)
import Test.QuickCheck (Property, arbitrary, conjoin, counterexample, elements, forAll, oneof, (===))

persistProperties :: [(String, IO Property)]
persistProperties =
  [ ("an integer of any magnitude survives storage", testIntegers)
  , ("an unbounded integer survives storage digit for digit", testUnbounded)
  , ("a stored float constant reads back bit for bit", testFloats)
  , ("derive surface syntax survives storage", testDeriveSurface)
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
    case freeze (Value.FloatValue Float64Width number) >>= decodeWith source . encodeFor source of
      Just stored -> case thaw stored of
        Value.FloatValue Float64Width back -> castDoubleToWord64 back === castDoubleToWord64 number
        _ -> counterexample "a float read back as something else" False
      Nothing -> counterexample "a stored float could not be read" False

testDeriveSurface :: IO Property
testDeriveSurface = do
  source <- newSource (SourceName "persist") ""
  let spanValue = emptySpan source
      name text = Located spanValue text
      trait = Located spanValue (NamedType (ModuleName ("Encode" :| [])) [])
      target = Located spanValue (NamedType (ModuleName ("T" :| [])) [])
      attribute = Attribute (name "json") [Located spanValue (StringValue "id")]
      request = DeriveRequest trait target
      loop = ComptimeFor (name "field")
        (Located spanValue (NamedType (ModuleName ("F" :| [])) []))
        (Located spanValue (LiteralExpression (IntegerValue "1")))
        [Located spanValue (Constraint (name "F") [Located spanValue (NamedType (ModuleName ("Encode" :| [])) [])])]
        (Located spanValue (Block [] Nothing))
      derive = Derive Private trait (name "T") (Located spanValue RecordShape) []
  pure $ conjoin
    [ roundTrip source "attribute" attribute
    , roundTrip source "request" request
    , roundTrip source "loop" loop
    , roundTrip source "derive" derive
    ]
 where
  roundTrip :: (Eq value, Show value, Persist value) => Source -> String -> value -> Property
  roundTrip source label value =
    counterexample ("a " <> label <> " changed in storage")
      (decodeWith source (encodeFor source value) === Just value)
