{-| @Test.Eval.BinarySpec — native wire laws, exact bits and refusal boundaries. -}
module Pudu.Eval.BinarySpec (binaryProperties) where

import qualified Data.ByteString as BS
import Data.Either (isLeft)
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Data.Word (Word8)
import GHC.Float (castWord64ToDouble)
import Pudu.Eval.Binary (decodeNodes, encodeNode)
import Pudu.Eval.Value (OrdValue (..), Value (..), intOf)
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Test.QuickCheck (Gen, Property, arbitrary, chooseInt, conjoin, counterexample, elements, forAll, oneof, property, vectorOf, (===))

binaryProperties :: [(String, IO Property)]
binaryProperties =
  [ ("binary codec preserves canonical nodes and exact bits", pure roundTrips)
  , ("binary codec refuses every strict truncation", pure truncations)
  , ("binary codec pins wire boundaries and refusals", pure boundaries)
  ]

roundTrips :: Property
roundTrips = forAll (nodes 3) $ \node -> case encodeNode node of
  Nothing -> counterexample "generated node refused by writer" False
  Just bytes -> case decodeNodes bytes of
    Left problem -> counterexample (show problem) False
    Right back -> encodeNode back === encodeNode (canonical node)

truncations :: Property
truncations = forAll (nodes 2) $ \node -> case encodeNode node of
  Nothing -> counterexample "generated node refused by writer" False
  Just bytes -> conjoin
    [ counterexample ("accepted prefix " <> show count) (property (isLeft (decodeNodes (BS.take count bytes))))
    | count <- [0 .. BS.length bytes - 1] ]

{-| Containers have at most three children and recursion decreases explicitly. -}
nodes :: Int -> Gen Value
nodes depth = if depth == 0 then leaf else oneof
  [ leaf
  , VariantValue "Present" . pure <$> child
  , do count <- chooseInt (0, 3)
       members <- vectorOf count child
       pure (VariantValue "Items" [ArrayValue (Seq.fromList members)])
  , do a <- child
       b <- child
       let fields = ArrayValue (Seq.fromList [TupleValue [StrValue "árbol", a], TupleValue [StrValue "z", b]])
       oneof [pure (VariantValue "Fields" [fields]), pure (VariantValue "Choice" [StrValue "Stored", fields])]
  ]
 where
  child = nodes (depth - 1)
  leaf = oneof
    [ VariantValue "Whole" . pure . intOf . toInteger <$> (arbitrary :: Gen Int64)
    , VariantValue "Real" . pure . FloatValue Float64Width . castWord64ToDouble <$> arbitrary
    , VariantValue "Flag" . pure . BoolValue <$> arbitrary
    , VariantValue "Text" . pure . StrValue <$> elements ["", "a\0b", "árbol · 箱 · 🎮"]
    , do count <- chooseInt (0, 16)
         bytes <- BS.pack <$> vectorOf count arbitrary
         pure (VariantValue "Raw" [BytesValue bytes])
    , do count <- chooseInt (0, 3)
         bytes <- BS.pack <$> vectorOf (count * 8) arbitrary
         pure (VariantValue "Reals" [BytesValue bytes])
    , pure (VariantValue "Absent" [])
    ]

{-| Read-side records are maps; canonicalize field order without comparing NaNs. -}
canonical :: Value -> Value
canonical node = case node of
  VariantValue "Fields" [ArrayValue fields] -> VariantValue "Record" [asMap fields]
  VariantValue "Choice" [name, ArrayValue fields] -> VariantValue "Picked" [name, asMap fields]
  VariantValue "Items" [ArrayValue items] -> VariantValue "Items" [ArrayValue (canonical <$> items)]
  VariantValue "Present" [held] -> VariantValue "Present" [canonical held]
  _ -> node
 where
  asMap fields = MapValue (Map.fromList [(OrdValue (StrValue name), canonical held)
    | TupleValue [StrValue name, held] <- foldr (:) [] fields])

boundaries :: Property
boundaries = conjoin
  [ encodeNode (VariantValue "Whole" [intOf (-1)]) === Just (BS.pack ([0,0,0,0,0] <> replicate 8 255))
  , encodeNode (VariantValue "Real" [FloatValue Float64Width (castWord64ToDouble bits)]) ===
      Just (BS.pack [0,0,0,0,1,0x23,1,0,0,0,0,0xf8,0x7f])
  , decodeNodes (emptyNames <> BS.replicate 512 8 <> BS.singleton 7) `succeeds` "depth 512"
  , decodeNodes (emptyNames <> BS.replicate 513 8 <> BS.singleton 7) === Left "nodes nest deeper than 512"
  , conjoin [decodeNodes (emptyNames <> BS.pack bytes) === Left message | (bytes, message) <- malformed]
  , encodeNode (VariantValue "Reals" [BytesValue (BS.singleton 1)]) === Nothing
  , encodeNode (intOf 1) === Nothing
  , decodeNodes (BS.pack [1,0,0,0,1,0,0,0,97,9,2,0,0,0,0,0,0,0,7,0,0,0,0,7]) === Left "the field a appears twice"
  , decodeNodes (BS.pack [1,0,0,0,1,0,0,0,255,7]) === Left "text that is not UTF-8"
  ]
 where
  bits = 0x7ff8000000000123
  emptyNames = BS.replicate 4 0
  malformed :: [([Word8], Text)]
  malformed =
    [ ([99], "an unknown node tag 99")
    , ([2,2], "a flag byte above 1")
    , ([3,1,0,0,0,255], "text that is not UTF-8")
    , ([5,255,255,255,255], "the bytes end inside a node")
    , ([6,255,255,255,255], "the bytes end inside a node")
    , ([9,1,0,0,0,1,0,0,0], "a name index 1 past the name table")
    , ([7,0], "1 bytes follow the root node")
    ]
  succeeds result label = counterexample label (property (case result of Right _ -> True; Left _ -> False))
