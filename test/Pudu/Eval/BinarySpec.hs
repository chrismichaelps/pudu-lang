{-# LANGUAGE PatternSynonyms #-}
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
import Pudu.Eval.Binary (decodeNodes, encodeNode, wireCount)
import Pudu.Eval.Value (OrdValue (..), Value (..), intOf)
import Pudu.FloatLiteral (FloatWidth (Float64Width))
import Test.QuickCheck (Gen, Property, arbitrary, chooseInt, conjoin, counterexample, elements, forAll, oneof, property, vectorOf, (===))

pattern Node :: Text -> [Value] -> Value
pattern Node name payload = SumValue "Std.Binary.Node" name payload

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
    Right back -> conjoin
      [ counterexample "decoded node owner was erased" (property (owned back))
      , encodeNode back === encodeNode (canonical node) ]

owned :: Value -> Bool
owned value = case value of
  SumValue owner _ members -> owner == "Std.Binary.Node" && all owned members
  TupleValue members -> all owned members
  ArrayValue members -> all owned members
  MapValue members -> all (owned . snd) (Map.toList members)
  _ -> True

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
  , Node "Present" . pure <$> child
  , do count <- chooseInt (0, 3)
       members <- vectorOf count child
       pure (Node "Items" [ArrayValue (Seq.fromList members)])
  , do a <- child
       b <- child
       let fields = ArrayValue (Seq.fromList [TupleValue [StrValue "árbol", a], TupleValue [StrValue "z", b]])
       oneof [pure (Node "Fields" [fields]), pure (Node "Choice" [StrValue "Stored", fields])]
  ]
 where
  child = nodes (depth - 1)
  leaf = oneof
    [ Node "Whole" . pure . intOf . toInteger <$> (arbitrary :: Gen Int64)
    , Node "Real" . pure . FloatValue Float64Width . castWord64ToDouble <$> arbitrary
    , Node "Flag" . pure . BoolValue <$> arbitrary
    , Node "Text" . pure . StrValue <$> elements ["", "a\0b", "árbol · 箱 · 🎮"]
    , do count <- chooseInt (0, 16)
         bytes <- BS.pack <$> vectorOf count arbitrary
         pure (Node "Raw" [BytesValue bytes])
    , do count <- chooseInt (0, 3)
         bytes <- BS.pack <$> vectorOf (count * 8) arbitrary
         pure (Node "Reals" [BytesValue bytes])
    , pure (Node "Absent" [])
    ]

{-| Read-side records are maps; canonicalize field order without comparing NaNs. -}
canonical :: Value -> Value
canonical node = case node of
  Node "Fields" [ArrayValue fields] -> Node "Record" [asMap fields]
  Node "Choice" [name, ArrayValue fields] -> Node "Picked" [name, asMap fields]
  Node "Items" [ArrayValue items] -> Node "Items" [ArrayValue (canonical <$> items)]
  Node "Present" [held] -> Node "Present" [canonical held]
  _ -> node
 where
  asMap fields = MapValue (Map.fromList [(OrdValue (StrValue name), canonical held)
    | TupleValue [StrValue name, held] <- foldr (:) [] fields])

boundaries :: Property
boundaries = conjoin
  [ map wireCount [-1, 0, 4294967295, 4294967296, 18446744073709551616] === [Nothing, Just 0, Just maxBound, Nothing, Nothing]
  , encodeNode (Node "Whole" [intOf (-1)]) === Just (BS.pack ([0,0,0,0,0] <> replicate 8 255))
  , encodeNode (Node "Real" [FloatValue Float64Width (castWord64ToDouble bits)]) ===
      Just (BS.pack [0,0,0,0,1,0x23,1,0,0,0,0,0xf8,0x7f])
  , decodeNodes (emptyNames <> BS.replicate 512 8 <> BS.singleton 7) `succeeds` "depth 512"
  , decodeNodes (emptyNames <> BS.replicate 513 8 <> BS.singleton 7) === Left "nodes nest deeper than 512"
  , conjoin [decodeNodes (emptyNames <> BS.pack bytes) === Left message | (bytes, message) <- malformed]
  , encodeNode (Node "Reals" [BytesValue (BS.singleton 1)]) === Nothing
  , encodeNode (intOf 1) === Nothing
  , encodeNode (nest 512) `writes` "writer depth 512"
  , encodeNode (nest 513) === Nothing
  , encodeNode (Node "Fields" [duplicates]) === Nothing
  , encodeNode (Node "Choice" [StrValue "Stored", duplicates]) === Nothing
  , encodeNode (Node "Items" [ArrayValue (Seq.fromList [singleField, singleField])]) `writes` "sibling field-name reuse"
  , decodeNodes (BS.pack [1,0,0,0,1,0,0,0,97,9,2,0,0,0,0,0,0,0,7,0,0,0,0,7]) === Left "the field a appears twice"
  , decodeNodes (BS.pack [1,0,0,0,1,0,0,0,255,7]) === Left "text that is not UTF-8"
  ]
 where
  nest count = foldr (\_ held -> Node "Present" [held]) (Node "Absent" []) [1 .. count :: Int]
  singleField = Node "Fields" [ArrayValue (Seq.singleton (TupleValue [StrValue "x", Node "Absent" []]))]
  duplicates = ArrayValue (Seq.fromList (replicate 2 (TupleValue [StrValue "x", Node "Absent" []])))
  writes result label = counterexample label (property (case result of Just _ -> True; Nothing -> False))
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
