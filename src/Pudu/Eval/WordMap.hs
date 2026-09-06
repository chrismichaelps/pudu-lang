{-| Checked evaluator adaptation of native-word map reductions. -}
module Pudu.Eval.WordMap
  ( callWordMapPopCount
  ) where

import Data.Text (Text)
import Data.Word (Word64)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (Value (..))
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import qualified Pudu.Runtime.Word as Word
import Pudu.Source (Span)

callWordMapPopCount :: Span -> [Value] -> Evaluator Value
callWordMapPopCount spanValue arguments = case arguments of
  [MapValue entries] -> case Word.countWords project entries of
    Left problem -> abortAt (Just spanValue) "E7001" problem Nothing
    Right count -> pure (IntValue (UnsignedKind 128) count)
  [_] -> abortAt (Just spanValue) "E7001" "wordMapPopCount expects a map" Nothing
  _ -> abortAt (Just spanValue) "E7003" "wordMapPopCount expects one argument" Nothing
 where
  project :: Value -> Either Text Word64
  project (IntValue (UnsignedKind 64) number)
    | number >= 0 && number <= toInteger (maxBound :: Word64) = Right (fromInteger number)
  project _ = Left "wordMapPopCount expects UInt64 map values"
