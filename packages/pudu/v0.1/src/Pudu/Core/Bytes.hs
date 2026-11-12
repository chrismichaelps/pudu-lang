{-| @Core.Bytes — closed byte-sequence operations shared by lowering and emission. -}
module Pudu.Core.Bytes (CoreBytesMethodName (..)) where

data CoreBytesMethodName
  = BytesOfArray
  | BytesFromText
  | BytesLengthOf
  | BytesAtIndex
  | BytesSliceOf
  | BytesTakeOf
  | BytesDropOf
  | BytesConcatWith
  | BytesIndexOfValue
  | BytesContainsValue
  | BytesStartsWithValue
  | BytesEndsWithValue
  | BytesReversed
  {-| `width` bytes from each `stride`-byte group from `offset`, the shape
      already checked; a final short group gives what remains. -}
  | BytesStridedOf
  | BytesToArrayOf
  | BytesIsText
  | BytesAsText
  deriving stock (Eq, Show)
