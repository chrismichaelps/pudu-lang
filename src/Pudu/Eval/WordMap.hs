{-| Checked evaluator adaptation of native-word map reductions. -}
module Pudu.Eval.WordMap
  ( callWordMapAlgebra
  , callWordMapPopCount
  ) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Word (Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..))
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
    Right combined -> pure (MapValue (Map.map (IntValue (UnsignedKind 64) . toInteger) combined))
  [_, _] -> abortAt (Just spanValue) "E7001" (name <> " expects two maps") Nothing
  _ -> abortAt (Just spanValue) "E7003" (name <> " expects two arguments") Nothing
 where
  checked left right = do
    a <- traverse (projectWord name) left
    b <- traverse (projectWord name) right
    pure (Word.combineMaps operation a b)

projectWord :: Text -> Value -> Either Text Word64
projectWord _ (IntValue (UnsignedKind 64) number)
  | number >= 0 && number <= toInteger (maxBound :: Word64) = Right (fromInteger number)
projectWord name _ = Left (name <> " expects UInt64 map values")
