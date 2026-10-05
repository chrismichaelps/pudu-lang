{-| @Type.Formation.Builtin — fixed language constructors, carriers and aliases. -}
module Pudu.Type.Formation.Builtin
  ( builtinAliases, builtinKinds, builtinOwnedVariants, builtinOwners
  , builtinTypeNames, builtinVariants ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Type.Value (NominalId (..), Type (..))

builtinTypeNames :: [Text]
builtinTypeNames =
  [ "Array", "Str", "Bytes", "Buckets", "Map", "Set", "Char", "Bool", "Option", "Result", "Task"
  , "Range"
  , "Int", "UInt", "BigInt", "Decimal", "Float", "Float32", "Float64"
  , "Int8", "Int16", "Int32", "Int64", "Int128"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128"
  ]

builtinKinds :: NominalId -> [Int]
builtinKinds owner
  | nominalModule owner /= Nothing = []
  | nominalName owner `elem` ["Array", "Set", "Option", "Range", "Buckets"] = [0]
  | nominalName owner `elem` ["Map", "Result", "Task"] = [0, 0]
  | otherwise = []

{-| Option and Result are the language's absence/failure carriers; their
    variants exist without any declaration or imported module. -}
builtinOwnedVariants :: Map (NominalId, Text) (NominalId, [Text], [Type])
builtinOwnedVariants =
  Map.fromList
    [ ((owner, name), shape)
    | (name, shape@(owner, _, _)) <- Map.toList builtinVariants
    ]

builtinVariants :: Map Text (NominalId, [Text], [Type])
builtinVariants =
  Map.fromList
    [ ("Some", ("Option", ["T"], [RigidType "T"]))
    , ("None", ("Option", ["T"], []))
    , ("Ok", ("Result", ["T", "E"], [RigidType "T"]))
    , ("Err", ("Result", ["T", "E"], [RigidType "E"]))
    ]

builtinOwners :: Map NominalId [Text]
builtinOwners = Map.fromList [("Option", ["Some", "None"]), ("Result", ["Ok", "Err"])]

{-| Float is a transparent alias, not an independently nominal type. -}
builtinAliases :: Map Text ([Text], Type)
builtinAliases = Map.fromList [("Float", ([], NominalType "Float64" []))]
