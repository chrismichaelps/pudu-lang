{-| @Core.Keyed — closed map/set operations shared by lowering and emission. -}
module Pudu.Core.Keyed (CoreKeyedMethodName (..)) where

{-| Lookup follows a successful contains test; FromArray reads typed pairs
    or members. Word operations require identical UInt64-valued map types. -}
data CoreKeyedMethodName
  = KeyedSize
  | KeyedIsEmpty
  | KeyedContains
  | KeyedLookup
  | KeyedInsert
  {-| Insert whose key replaces the spelling of an equal held key. -}
  | KeyedPut
  | KeyedRemove
  | KeyedKeys
  | KeyedValues
  | KeyedEntries
  | KeyedMerge
  | KeyedUnion
  | KeyedIntersect
  | KeyedDifference
  | KeyedFromArray
  | KeyedWordUnion
  | KeyedWordIntersection
  | KeyedWordDifference
  | KeyedWordSymmetricDifference
  | KeyedWordSubset
  | KeyedWordDisjoint
  | KeyedWordPopCount
  | KeyedWordMembers
  {-| The store index of an Int: the receiver is the Int itself. -}
  | KeyedMixHash
  {-| `hashOf` of text, bytes or an integer: the receiver is the value. -}
  | KeyedHash
  deriving stock (Eq, Show)
