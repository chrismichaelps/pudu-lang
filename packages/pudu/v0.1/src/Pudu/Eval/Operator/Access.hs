{-| @Program.Eval.Operator.Access — indexing, member dispatch, method tables, and try unwinding -}
module Pudu.Eval.Operator.Access
  ( arrayMethods
  , builtinMethodNamesFor
  , mapMethods
  , nominalNameOf
  , readArrayMember
  , readCharMember
  , readIndex
  , readKeyedMember
  , readMember
  , readMethod
  , readMethodAmong
  , readStringMember
  , setMethods
  , stringMethods
  , unwrapTry
  ) where

import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text

import Pudu.Eval.Bytes (bytesMethods)
import Pudu.Eval.Env
  ( Evaluator
  , Unwind (ReturnUnwind)
  , abortAt
  , lookupName
  , unwind
  , variantOwner
  )
import Pudu.Eval.HashMap (bucketsMethods)
import Pudu.Eval.Render (valueKind)
import Pudu.Eval.Value
  ( ArrayMethod (..)
  , CharMethod (..)
  , Closure (..)
  , MapMethod (..)
  , SetMethod (..)
  , StringMethod (..)
  , Value (..)
  )
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (integerKindName)
import Pudu.Source (Span)

readIndex :: Span -> Value -> Value -> Evaluator Value
readIndex spanValue container key = case (container, key) of
  (TupleValue members, IntValue _ index)
    | index >= 0 && fromInteger index < length members -> pure (members !! fromInteger index)
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  (ArrayValue members, IntValue _ index)
    | index >= 0 && fromInteger index < Seq.length members ->
        case Seq.lookup (fromInteger index) members of
          Just value -> pure value
          Nothing -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  (StrValue text, IntValue _ index)
    | index >= 0 && fromInteger index < Text.length text ->
        pure (CharValue (Text.index text (fromInteger index)))
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot index a " <> valueKind container) Nothing

{-| A member is a field when the value has one, and otherwise a method of the
    value's type. Reading a method binds the receiver, so `value.method()` calls
    it with `value` as its first argument. -}
readMember :: Span -> Value -> Text -> Evaluator Value
readMember spanValue value member = case value of
  ArrayValue _ -> readArrayMember spanValue value member
  StrValue _ -> readStringMember spanValue value member
  BytesValue _ -> readKeyedMember spanValue value member bytesMethods BytesMethodValue "Bytes"
  BucketsValue _ -> readKeyedMember spanValue value member bucketsMethods BucketsMethodValue "Buckets"
  CharValue _ -> readCharMember spanValue value member
  MapValue _ -> readKeyedMember spanValue value member mapMethods MapMethodValue "Map"
  SetValue _ -> readKeyedMember spanValue value member setMethods SetMethodValue "Set"
  RecordValue owner fields -> case lookup member fields of
    Just found -> pure found
    Nothing -> readMethod spanValue value owner member
  {-| A member on a variant is looked for on the sum that owns it before the
      variant itself. An implementation is written for the type — `impl Named
      for Option[Int]` — and the value in hand is one of its variants, so
      looking only at the variant found nothing and reported a type the reader
      never wrote. The variant's own name is still tried, so a member keyed
      there keeps working. -}
  VariantValue name _
    | name == member -> pure value
    | otherwise -> do
        owner <- variantOwner name
        readMethodAmong spanValue value (maybe [name] (\found -> [found, name]) owner) name member
  {-| A scalar has no fields, but it may have methods: an `impl Ord for Int`
      is a method on every integer. The nominal name a method is keyed by comes
      from the value's own type, which is why an integer had to start carrying
      one. Without this an implementation for a built-in type checked and then
      failed at run time. -}
  _ -> case nominalNameOf value of
    Just owner -> readMethod spanValue value owner member
    Nothing ->
      abortAt (Just spanValue) "E7001"
        ("cannot read " <> member <> " from a " <> valueKind value) Nothing

{-| Array accessor methods are built into the evaluator: `length`, `get`,
    `indexOf`, `contains`, `push`, `pop`, `insert`, `remove`, `slice`,
    `reverse`, `map`, `filter`, `reduce`. Each is a curried builtin that
    carries the receiver so `arr.push(x)` evaluates as `push(arr, x)`. -}
readArrayMember :: Span -> Value -> Text -> Evaluator Value
readArrayMember spanValue array member =
  case lookup member arrayMethods of
    Just method -> pure (ArrayMethodValue method array)
    Nothing -> readMethod spanValue array "Array" member

{-| Text methods are built into the evaluator for the same reason array methods
    are: their semantics are fixed, so the checker can type them exactly and the
    evaluator can implement them without a library that would need `unsafe` to
    reach the representation. -}
readStringMember :: Span -> Value -> Text -> Evaluator Value
readStringMember spanValue text member =
  case lookup member stringMethods of
    Just method -> pure (StringMethodValue method text)
    Nothing -> readMethod spanValue text "Str" member

{-| A character answers only for its scalar value. Everything a reader wants to
    ask about a character — is it a digit, a letter, whitespace — is answered by
    `Std.Char` in the language, where the answer can be read and argued with. -}
readCharMember :: Span -> Value -> Text -> Evaluator Value
readCharMember spanValue character member
  | member == "code" = pure (CharMethodValue CharCode character)
  | member == "toText" = pure (CharMethodValue CharToText character)
  | otherwise = readMethod spanValue character "Char" member

{-| Map and set methods share one lookup: both are closed vocabularies keyed by
    name, and writing the search twice would let the two drift. A name the
    vocabulary does not hold falls through to the type's own implementations,
    so `impl Show for Map` reaches its method. -}
readKeyedMember
  :: Span -> Value -> Text -> [(Text, method)] -> (method -> Value -> Value) -> Text -> Evaluator Value
readKeyedMember spanValue receiver member table build described =
  case lookup member table of
    Just method -> pure (build method receiver)
    Nothing -> readMethod spanValue receiver described member

{-| The methods a value of this kind carries, by the name its type is written
    under.

    Read from the same tables dispatch reads, so what the prompt offers and what
    a call finds cannot disagree — the reason `effectBuiltins` is one list too.
    A kind with no built-in methods answers with none rather than with
    everything. -}
builtinMethodNamesFor :: Text -> [Text]
builtinMethodNamesFor owner = case owner of
  "Array" -> map fst arrayMethods
  "Str" -> map fst stringMethods
  "Map" -> map fst mapMethods
  "Set" -> map fst setMethods
  "Bytes" -> map fst bytesMethods
  "Buckets" -> map fst bucketsMethods
  "Char" -> ["code", "toText"]
  _ -> []

mapMethods :: [(Text, MapMethod)]
mapMethods =
  [ ("size", MapSize)
  , ("isEmpty", MapIsEmpty)
  , ("get", MapGet)
  , ("containsKey", MapContainsKey)
  , ("insert", MapInsert)
  , ("remove", MapRemove)
  , ("keys", MapKeys)
  , ("values", MapValues)
  , ("entries", MapEntries)
  , ("merge", MapMerge)
  ]

setMethods :: [(Text, SetMethod)]
setMethods =
  [ ("size", SetSize)
  , ("isEmpty", SetIsEmpty)
  , ("contains", SetContains)
  , ("insert", SetInsert)
  , ("remove", SetRemove)
  , ("toArray", SetToArray)
  , ("union", SetUnion)
  , ("intersect", SetIntersect)
  , ("difference", SetDifference)
  ]

stringMethods :: [(Text, StringMethod)]
stringMethods =
  [ ("length", StringLength)
  , ("isEmpty", StringIsEmpty)
  , ("charAt", StringCharAt)
  , ("indexOf", StringIndexOf)
  , ("contains", StringContains)
  , ("startsWith", StringStartsWith)
  , ("endsWith", StringEndsWith)
  , ("drop", StringDrop)
  , ("take", StringTake)
  , ("spanOf", StringSpanOf)
  , ("spanNotOf", StringSpanNotOf)
  , ("slice", StringSlice)
  , ("escapeHtml", StringEscapeHtml)
  , ("trim", StringTrim)
  , ("toUpper", StringToUpper)
  , ("toLower", StringToLower)
  , ("replace", StringReplace)
  , ("repeat", StringRepeat)
  , ("split", StringSplit)
  , ("toBytes", StringToBytes)
  , ("chars", StringChars)
  , ("lines", StringLines)
  , ("reverse", StringReverse)
  ]

{-| Method names paired with their method tags. -}
arrayMethods :: [(Text, ArrayMethod)]
arrayMethods =
  [ ("length", ArrayLength)
  , ("isEmpty", ArrayIsEmpty)
  , ("get", ArrayGet)
  , ("indexOf", ArrayIndexOf)
  , ("contains", ArrayContains)
  , ("push", ArrayPush)
  , ("pop", ArrayPop)
  , ("insert", ArrayInsert)
  , ("remove", ArrayRemove)
  , ("slice", ArraySlice)
  , ("concat", ArrayConcat)
  , ("join", ArrayJoin)
  , ("reverse", ArrayReverse)
  , ("map", ArrayMap)
  , ("filter", ArrayFilter)
  , ("reduce", ArrayReduce)
  ]

{-| The nominal type a value belongs to, for the values that belong to one the
    reader can write an implementation for.

    A function and a task have no nominal name a program can name in an `impl`
    head, so they answer with nothing and keep the old refusal. -}
nominalNameOf :: Value -> Maybe Text
nominalNameOf value = case value of
  IntValue kind _ -> Just (integerKindName kind)
  FloatValue Float32Width _ -> Just "Float32"
  FloatValue Float64Width _ -> Just "Float64"
  StrValue _ -> Just "Str"
  BytesValue _ -> Just "Bytes"
  BucketsValue _ -> Just "Buckets"
  CharValue _ -> Just "Char"
  BoolValue _ -> Just "Bool"
  UnitValue -> Just "()"
  ArrayValue _ -> Just "Array"
  MapValue _ -> Just "Map"
  SetValue _ -> Just "Set"
  TupleValue _ -> Nothing
  _ -> Nothing

{-| Look for a member under each name in turn, reporting against the first —
    the type the reader wrote — rather than against whichever was tried last. -}
readMethodAmong :: Span -> Value -> [Text] -> Text -> Text -> Evaluator Value
readMethodAmong spanValue receiver owners reported member = case owners of
  [] ->
    abortAt (Just spanValue) "E7001"
      ("no field or method " <> member <> " on a " <> reported) Nothing
  owner : rest -> do
    found <- lookupName (owner <> "." <> member)
    case found of
      Just (FunctionValue closure) ->
        pure (FunctionValue closure{closureSelf = Just receiver})
      _ -> readMethodAmong spanValue receiver rest reported member

readMethod :: Span -> Value -> Text -> Text -> Evaluator Value
readMethod spanValue receiver owner member = do
  found <- lookupName (owner <> "." <> member)
  case found of
    Just (FunctionValue closure) ->
      pure (FunctionValue closure{closureSelf = Just receiver})
    _ ->
      abortAt (Just spanValue) "E7001"
        ("no field or method " <> member <> " on a " <> owner) Nothing

{-| `?` yields the success value, or returns the failure from the enclosing
    function unchanged, which is the elaboration [[architecture/SEMANTICS]]
    gives it. -}
unwrapTry :: Span -> Value -> Evaluator Value
unwrapTry spanValue value = case value of
  VariantValue "Ok" [inner] -> pure inner
  VariantValue "Err" _ -> unwind (ReturnUnwind value)
  VariantValue "Some" [inner] -> pure inner
  VariantValue "None" [] -> unwind (ReturnUnwind value)
  _ -> abortAt (Just spanValue) "E7001" "? expects a Result or Option value" Nothing
