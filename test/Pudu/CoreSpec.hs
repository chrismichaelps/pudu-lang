module Pudu.CoreSpec (coreProperties) where

import Pudu.Core (CoreType (..), coreTypeName)
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import Test.QuickCheck (Property, conjoin, (===))

coreProperties :: [(String, IO Property)]
coreProperties =
  [("native Core type names preserve canonical owner identity", pure $ conjoin
      [ coreTypeName (nested "First") === "Map[Key, fn(Token[Str]) -> UInt128]"
      , coreTypeName (nested "Second") === coreTypeName (nested "First")
      , (nested "First" == nested "Second") === False
      ])]
 where
  nested owner = CoreMapType (CoreRecordType (owner <> ".Key") [])
    (CoreFunctionType [CoreSumType (owner <> ".Token") [CoreTextType]]
      (CoreIntegerType (UnsignedKind 128)))
