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
  deriving stock (Eq, Show)
