{-| @Eval.Method — the built-in methods a value answers to

    Each set is closed, which is what lets the checker type a method exactly and
    report an unknown one rather than dispatch it. The name table is the single
    spelling: the checker matches it, the diagnostic prints it, and the
    evaluator dispatches on it, so a rename cannot leave two of them
    disagreeing.

    Definitions only — nothing here depends on a runtime value, an environment,
    or an evaluator, which is why [[Eval Value]] can re-export the whole
    vocabulary and no caller learns that it moved. -}
module Pudu.Eval.Method
  ( ArrayMethod (..)
  , BucketsMethod (..)
  , BytesMethod (..)
  , CharMethod (..)
  , MapMethod (..)
  , SetMethod (..)
  , StringMethod (..)
  , arrayMethodName
  , bucketsMethodName
  , bytesMethodName
  , charMethodName
  , mapMethodName
  , setMethodName
  , stringMethodName
  ) where

import Data.Text (Text)

{-| @Eval.Value.MapMethod — one built-in operation on a keyed collection.

    A map answers with a new map rather than changing the one it was given, like
    every other collection here. The set is closed so each method can be typed
    exactly. -}
data MapMethod
  = MapSize
  | MapIsEmpty
  | MapGet
  | MapContainsKey
  | MapInsert
  | MapRemove
  | MapKeys
  | MapValues
  | MapEntries
  | MapMerge
  deriving stock (Eq, Show)

{-| @Eval.Value.BytesMethod — one built-in operation on a byte sequence.

    Closed for the reason the text and array sets are closed: a method whose
    semantics the compiler knows can be typed exactly, and one it does not know
    is reported rather than dispatched. Everything above this set — base64,
    hex, reading a number of a stated width and endianness — is `Std.Bytes`,
    written in the language. -}
{-| @Eval.Value.BucketsMethod — one built-in operation on an indexed store. -}
data BucketsMethod
  = BucketsSize
  | BucketsIsEmpty
  | BucketsGet
  | BucketsInsert
  | BucketsRemove
  | BucketsKeys
  | BucketsValues
  deriving stock (Eq, Show)

data BytesMethod
  = BytesLength
  | BytesIsEmpty
  | BytesAt
  | BytesSlice
  | BytesTake
  | BytesDrop
  | BytesConcat
  | BytesIndexOf
  | BytesContains
  | BytesStartsWith
  | BytesEndsWith
  | BytesReverse
  | BytesToArray
  | BytesToText
  deriving stock (Eq, Show)

{-| @Eval.Value.SetMethod — one built-in operation on a set. -}
data SetMethod
  = SetSize
  | SetIsEmpty
  | SetContains
  | SetInsert
  | SetRemove
  | SetToArray
  | SetUnion
  | SetIntersect
  | SetDifference
  deriving stock (Eq, Show)

bucketsMethodName :: BucketsMethod -> Text
bucketsMethodName method = case method of
  BucketsSize -> "size"
  BucketsIsEmpty -> "isEmpty"
  BucketsGet -> "get"
  BucketsInsert -> "insert"
  BucketsRemove -> "remove"
  BucketsKeys -> "keys"
  BucketsValues -> "values"

bytesMethodName :: BytesMethod -> Text
bytesMethodName method = case method of
  BytesLength -> "length"
  BytesIsEmpty -> "isEmpty"
  BytesAt -> "at"
  BytesSlice -> "slice"
  BytesTake -> "take"
  BytesDrop -> "drop"
  BytesConcat -> "concat"
  BytesIndexOf -> "indexOf"
  BytesContains -> "contains"
  BytesStartsWith -> "startsWith"
  BytesEndsWith -> "endsWith"
  BytesReverse -> "reverse"
  BytesToArray -> "toArray"
  BytesToText -> "toText"

mapMethodName :: MapMethod -> Text
mapMethodName method = case method of
  MapSize -> "size"
  MapIsEmpty -> "isEmpty"
  MapGet -> "get"
  MapContainsKey -> "containsKey"
  MapInsert -> "insert"
  MapRemove -> "remove"
  MapKeys -> "keys"
  MapValues -> "values"
  MapEntries -> "entries"
  MapMerge -> "merge"

setMethodName :: SetMethod -> Text
setMethodName method = case method of
  SetSize -> "size"
  SetIsEmpty -> "isEmpty"
  SetContains -> "contains"
  SetInsert -> "insert"
  SetRemove -> "remove"
  SetToArray -> "toArray"
  SetUnion -> "union"
  SetIntersect -> "intersect"
  SetDifference -> "difference"

{-| @Eval.Value.CharMethod — one built-in character operation.

    Only `code` is built in. Classification — digit, letter, whitespace — is
    library work that `Std.Char` does in the language, and building it into the
    compiler would settle questions about Unicode that the compiler is not yet
    equipped to answer. -}
data CharMethod
  = CharCode
  | CharToText
  deriving stock (Eq, Show)

data StringMethod
  = StringLength
  | StringIsEmpty
  | StringCharAt
  | StringIndexOf
  | StringContains
  | StringStartsWith
  | StringEndsWith
  | StringDrop
  | StringTake
  | StringSpanOf
  | StringSpanNotOf
  | StringSlice
  | StringTrim
  | StringToUpper
  | StringToLower
  | StringReplace
  | StringRepeat
  | StringSplit
  | StringToBytes
  | StringChars
  | StringLines
  | StringReverse
  deriving stock (Eq, Show)

data ArrayMethod
  = ArrayLength
  | ArrayIsEmpty
  | ArrayGet
  | ArrayIndexOf
  | ArrayContains
  | ArrayPush
  | ArrayPop
  | ArrayInsert
  | ArrayRemove
  | ArraySlice
  | ArrayConcat
  | ArrayJoin
  | ArrayReverse
  | ArrayMap
  | ArrayFilter
  | ArrayReduce
  deriving stock (Eq, Show)

{-| The name a text method answers to, which is the same spelling the checker
    matches and the diagnostic prints. -}
charMethodName :: CharMethod -> Text
charMethodName method = case method of
  CharCode -> "code"
  CharToText -> "toText"

stringMethodName :: StringMethod -> Text
stringMethodName method = case method of
  StringLength -> "length"
  StringIsEmpty -> "isEmpty"
  StringCharAt -> "charAt"
  StringIndexOf -> "indexOf"
  StringContains -> "contains"
  StringStartsWith -> "startsWith"
  StringEndsWith -> "endsWith"
  StringDrop -> "drop"
  StringTake -> "take"
  StringSpanOf -> "spanOf"
  StringSpanNotOf -> "spanNotOf"
  StringSlice -> "slice"
  StringTrim -> "trim"
  StringToUpper -> "toUpper"
  StringToLower -> "toLower"
  StringReplace -> "replace"
  StringRepeat -> "repeat"
  StringSplit -> "split"
  StringToBytes -> "toBytes"
  StringChars -> "chars"
  StringLines -> "lines"
  StringReverse -> "reverse"

arrayMethodName :: ArrayMethod -> Text
arrayMethodName method = case method of
  ArrayLength -> "length"
  ArrayIsEmpty -> "isEmpty"
  ArrayGet -> "get"
  ArrayIndexOf -> "indexOf"
  ArrayContains -> "contains"
  ArrayPush -> "push"
  ArrayPop -> "pop"
  ArrayInsert -> "insert"
  ArrayRemove -> "remove"
  ArraySlice -> "slice"
  ArrayConcat -> "concat"
  ArrayJoin -> "join"
  ArrayReverse -> "reverse"
  ArrayMap -> "map"
  ArrayFilter -> "filter"
  ArrayReduce -> "reduce"
