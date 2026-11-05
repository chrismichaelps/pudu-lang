{-| Method-key owners for declared types that share a built-in value's name. -}
module Pudu.Eval.DeclaredOwner
  ( declaredOwner
  , declaredOwnerCandidates
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)

{-| Every nominal name a built-in value answers to.

    A program may declare a record or sum under one of these names. Its methods
    are then keyed by `declaredOwner`, and its values look there, so a built-in
    array never runs a method written for a declared `Array` and a declared
    `Array` never runs one written for the built-in. -}
builtinValueOwners :: Set Text
builtinValueOwners = Set.fromList
  [ "Int", "Int8", "Int16", "Int32", "Int64", "Int128"
  , "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "BigInt"
  , "Float32", "Float64", "Decimal", "Str", "Bytes", "Buckets", "Char", "Bool", "()"
  , "Array", "Range", "Map", "Set"
  ]

{-| The method-key owner for a declared type's name. `@` cannot begin a
    written name, so the key never meets a built-in owner. -}
declaredOwner :: Text -> Text
declaredOwner name
  | Set.member name builtinValueOwners = "@" <> name
  | otherwise = name

{-| The keys a written type name may stand for when no receiver tells which:
    the declared type's first, then the built-in's. -}
declaredOwnerCandidates :: Text -> [Text]
declaredOwnerCandidates name
  | declaredOwner name == name = [name]
  | otherwise = [declaredOwner name, name]
