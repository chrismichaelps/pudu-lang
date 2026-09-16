module Pudu.Eval.WordMap
  ( callWordMapPredicate
  , callWordMapAlgebra
  , callWordMapPopCount
  , callWordMapMembers
  ) where

import Data.Bits (shiftL)
import Data.Foldable (traverse_)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Data.Word (Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (OrdValue (..), Value (..))
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import qualified Pudu.Runtime.Word as Word
import Pudu.Source (Span)

callWordMapPopCount :: Span -> [Value] -> Evaluator Value
callWordMapPopCount spanValue arguments = case arguments of
  [MapValue entries] -> case Word.countWords (projectWord "wordMapPopCount") entries of
    Left problem -> abortAt (Just spanValue) "E7001" problem Nothing
    Right count -> pure (IntValue (UnsignedKind 128) count)
  [_] -> abortAt (Just spanValue) "E7001" "wordMapPopCount expects a map" Nothing
  _ -> abortAt (Just spanValue) "E7003" "wordMapPopCount expects one argument" Nothing

{-| Validate both payload trees before selecting keys or narrowing words. -}
callWordMapAlgebra :: Span -> Text -> Word.WordOperation -> [Value] -> Evaluator Value
callWordMapAlgebra spanValue name operation arguments = case arguments of
  [MapValue left, MapValue right] -> case checked left right of
    Left problem -> abortAt (Just spanValue) "E7001" problem Nothing
    Right combined -> pure (MapValue combined)
  [_, _] -> abortAt (Just spanValue) "E7001" (name <> " expects two maps") Nothing
  _ -> abortAt (Just spanValue) "E7003" (name <> " expects two arguments") Nothing
 where
  checked left right = do
    traverse_ (projectWord name) left
    traverse_ (projectWord name) right
    pure (Word.combineMapsWith operation payloadWord encodeWord left right)
  encodeWord = IntValue (UnsignedKind 64) . toInteger

  {-| Both immutable input trees passed projectWord before this extractor is used. -}
  payloadWord (IntValue _ number) = fromInteger number
  payloadWord _ = 0

projectWord :: Text -> Value -> Either Text Word64
projectWord _ (IntValue (UnsignedKind 64) number)
  | number >= 0 && number <= toInteger (maxBound :: Word64) = Right (fromInteger number)
projectWord name _ = Left (name <> " expects UInt64 map values")

{-| Validate only the payloads visited by the short-circuiting kernel. -}
callWordMapPredicate :: Span -> Text -> Word.WordPredicate -> [Value] -> Evaluator Value
callWordMapPredicate spanValue name predicate arguments = case arguments of
  [MapValue left, MapValue right] -> case Word.compareMaps predicate (projectWord name) left right of
    Left problem -> abortAt (Just spanValue) "E7001" problem Nothing
    Right answer -> pure (BoolValue answer)
  [_, _] -> abortAt (Just spanValue) "E7001" (name <> " expects two maps") Nothing
  _ -> abortAt (Just spanValue) "E7003" (name <> " expects two arguments") Nothing

projectKey :: Text -> OrdValue -> Either Text Word64
projectKey _ (OrdValue (IntValue (UnsignedKind 64) number))
  | number >= 0 && number <= toInteger (maxBound :: Word64) = Right (fromInteger number)
projectKey name _ = Left (name <> " expects UInt64 map keys")

{-| Unpack sparse set member IDs in ascending order. -}
callWordMapMembers :: Span -> [Value] -> Evaluator Value
callWordMapMembers spanValue arguments = case arguments of
  [MapValue entries] -> case checkEntries entries of
    Left problem -> abortAt (Just spanValue) "E7001" problem Nothing
    Right members -> pure (ArrayValue (Seq.fromList (map encode members)))
  [_] -> abortAt (Just spanValue) "E7001" "wordMapMembers expects a map" Nothing
  _ -> abortAt (Just spanValue) "E7003" "wordMapMembers expects one argument" Nothing
 where
  checkEntries m = Map.foldrWithKey step (Right []) m
  step k v acc = do
    kWord <- projectKey "wordMapMembers" k
    vWord <- projectWord "wordMapMembers" v
    rest <- acc
    pure (Word.unpackWords (kWord `shiftL` 6) vWord rest)
  encode = IntValue (UnsignedKind 64) . toInteger
