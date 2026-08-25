{-| @Eval.Operator.Module — applies operator and access semantics -}
module Pudu.Eval.Operator
  ( applyUnary
  , combine
  , readIndex
  , readMember
  , unwrapTry
  ) where

import Data.Bits (complement, shiftL, shiftR, xor, (.&.), (.|.))
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, Unwind (ReturnUnwind), abortAt, lookupName, unwind)
import Pudu.Eval.Value (Closure (..), Value (..), ArrayMethod (..), StringMethod (..), CharMethod (..), MapMethod (..), SetMethod (..), valueKind)
import Pudu.FloatLiteral (FloatWidth (..), normalizeFloat)
import Pudu.IntegerLiteral
  ( IntegerKind (..)
  , integerKindFits
  , integerKindMeet
  , integerKindName
  , integerKindSigned
  , integerKindWidth
  , integerKindWrap
  )
import Pudu.Source (Span)

{-| Borrowing and dereferencing are identities at run time: a reference is the
    value it refers to, and only typing distinguishes them. The distinction
    becomes observable when ownership checking and a store exist. -}
applyUnary :: Span -> Text -> Value -> Evaluator Value
applyUnary spanValue operator value = case (operator, value) of
  ("-", IntValue kind number) -> checkedResult spanValue kind "negate" (negate number)
  ("-", FloatValue width number) -> pure (FloatValue width (negate number))
  ("!", BoolValue flag) -> pure (BoolValue (not flag))
  {-| Complement is a bit pattern, so it is taken over the type's own width.
      Without one, `~0u8` answers `-1`, which is not a value `UInt8` has. -}
  ("~", IntValue kind number) -> pure (IntValue kind (integerKindWrap kind (complement number)))
  ("&", _) -> pure value
  ("&mut", _) -> pure value
  ("*", _) -> pure value
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot apply " <> operator <> " to a " <> valueKind value) Nothing

combine :: Span -> Text -> Value -> Value -> Evaluator Value
combine spanValue operator left right = case (left, right) of
  (IntValue leftKind a, IntValue rightKind b) ->
    integerOperation spanValue (integerKindMeet leftKind rightKind) operator a b
  (FloatValue leftWidth a, FloatValue rightWidth b)
    | leftWidth == rightWidth -> floatOperation spanValue leftWidth operator a b
  (StrValue a, StrValue b) -> textOperation spanValue operator a b
  (CharValue a, CharValue b) -> comparisonOnly spanValue operator a b
  (BoolValue a, BoolValue b) -> comparisonOnly spanValue operator a b
  _ | operator == "==" -> pure (BoolValue (left == right))
    | operator == "!=" -> pure (BoolValue (left /= right))
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot apply " <> operator <> " to a " <> valueKind left <> " and a " <> valueKind right)
      Nothing

{-| Apply an operator to two integers of a shared kind.

    [[architecture/SEMANTICS]] separates three families and this is where they
    stop being the same operation:

    * checked `+ - *` yield the exact result or report overflow — never a
      quietly truncated answer;
    * wrapping `&+ &- &*` reduce into the type's interval, which is what
      two's-complement wrapping means;
    * saturating `+| -| *|` clamp to the interval's ends.

    They were all plain addition before, so a program asking for one of the
    three got whichever the machine's integers happened to do. -}
integerOperation :: Span -> IntegerKind -> Text -> Integer -> Integer -> Evaluator Value
integerOperation spanValue kind operator left right = case operator of
  "+" -> checkedResult spanValue kind "add" (left + right)
  "-" -> checkedResult spanValue kind "subtract" (left - right)
  "*" -> checkedResult spanValue kind "multiply" (left * right)
  "&+" -> wrappedResult kind (left + right)
  "&-" -> wrappedResult kind (left - right)
  "&*" -> wrappedResult kind (left * right)
  "+|" -> saturatedResult kind (left + right)
  "-|" -> saturatedResult kind (left - right)
  "*|" -> saturatedResult kind (left * right)
  "/" ->
    if right == 0
      then abortAt (Just spanValue) "E7004" "division by zero" Nothing
      else checkedResult spanValue kind "divide" (quot left right)
  "%" ->
    if right == 0
      then abortAt (Just spanValue) "E7004" "division by zero" Nothing
      else pure (IntValue kind (rem left right))
  ".." -> pure (TupleValue (map (IntValue kind) [left .. right - 1]))
  "..=" -> pure (TupleValue (map (IntValue kind) [left .. right]))
  "<<" -> shiftResult spanValue kind True left right
  ">>" -> shiftResult spanValue kind False left right
  "^" -> pure (IntValue kind (integerKindWrap kind (xor left right)))
  "&" -> pure (IntValue kind (integerKindWrap kind (left .&. right)))
  "|" -> pure (IntValue kind (integerKindWrap kind (left .|. right)))
  _ -> comparisonOnly spanValue operator left right

{-| A checked result: the exact value, or a report that the type cannot hold it.

    The diagnostic names the type rather than the operator, because a reader
    seeing `UInt8` in it learns why the answer did not fit; the operator is
    already on the line in front of them. -}
checkedResult :: Span -> IntegerKind -> Text -> Integer -> Evaluator Value
checkedResult spanValue kind what value
  | integerKindFits kind value = pure (IntValue kind value)
  | otherwise =
      abortAt (Just spanValue) "E7005"
        (integerKindName kind <> " cannot hold the result of this " <> what)
        ( Just
            ( "use the wrapping or saturating form, or a wider type; "
                <> "checked arithmetic never truncates quietly"
            )
        )

{-| A wrapping result, reduced into the type's interval. -}
wrappedResult :: IntegerKind -> Integer -> Evaluator Value
wrappedResult kind value = pure (IntValue kind (integerKindWrap kind value))

{-| A saturating result, clamped to the type's ends.

    `BigInt` has no ends, so nothing to clamp to and nothing to do. -}
saturatedResult :: IntegerKind -> Integer -> Evaluator Value
saturatedResult kind value = pure (IntValue kind clamped)
 where
  clamped = case integerKindWidth kind of
    Nothing -> value
    Just width ->
      let (low, high) =
            if integerKindSigned kind
              then (negate (2 ^ (width - 1)), 2 ^ (width - 1) - 1)
              else (0, 2 ^ width - 1)
       in max low (min high value)

{-| A shift, in the checked form the vault requires.

    The count must be non-negative and smaller than the type's width: a shift by
    the width has no defined answer, and reporting one would be inventing it.
    A right shift on a signed type keeps its sign, and on an unsigned type does
    not — which is the whole difference between the two shifts and the reason
    the value has to carry its signedness. -}
shiftResult :: Span -> IntegerKind -> Bool -> Integer -> Integer -> Evaluator Value
shiftResult spanValue kind toHigh value count
  | count < 0 =
      abortAt (Just spanValue) "E7004" "a shift count cannot be negative"
        (Just "shift by a non-negative count smaller than the type's width")
  | otherwise = case integerKindWidth kind of
      Nothing -> pure (IntValue kind (moved (fromInteger count)))
      Just width
        | count >= fromIntegral width ->
            abortAt (Just spanValue) "E7004"
              ( "a shift count must be smaller than "
                  <> integerKindName kind
                  <> "'s width"
              )
              (Just "mask the count, or use a wider type")
        | otherwise -> pure (IntValue kind (integerKindWrap kind (moved (fromInteger count))))
 where
  moved places
    | toHigh = shiftL value places
    | integerKindSigned kind = shiftR value places
    | otherwise = shiftR (integerKindWrap (unsignedOf kind) value) places

  {-| Reading right on an unsigned type first takes the value's own bit
      pattern, so a pattern that would read as negative shifts in noughts. -}
  unsignedOf other = case integerKindWidth other of
    Just width -> UnsignedKind width
    Nothing -> other

floatOperation :: Span -> FloatWidth -> Text -> Double -> Double -> Evaluator Value
floatOperation spanValue width operator left right = case operator of
  "+" -> result (left + right)
  "-" -> result (left - right)
  "*" -> result (left * right)
  "/" -> result (left / right)
  _ -> comparisonOnly spanValue operator left right
 where
  result value = pure (FloatValue width (normalizeFloat width value))

textOperation :: Span -> Text -> Text -> Text -> Evaluator Value
textOperation spanValue operator left right = case operator of
  "+" -> pure (StrValue (left <> right))
  _ -> comparisonOnly spanValue operator left right

comparisonOnly :: Ord a => Span -> Text -> a -> a -> Evaluator Value
comparisonOnly spanValue operator left right = case operator of
  "==" -> pure (BoolValue (left == right))
  "!=" -> pure (BoolValue (left /= right))
  "<" -> pure (BoolValue (left < right))
  "<=" -> pure (BoolValue (left <= right))
  ">" -> pure (BoolValue (left > right))
  ">=" -> pure (BoolValue (left >= right))
  _ -> abortAt (Just spanValue) "E7001" ("unsupported operator " <> operator) Nothing

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
  CharValue _ -> readCharMember spanValue value member
  MapValue _ -> readKeyedMember spanValue value member mapMethods MapMethodValue "Map"
  SetValue _ -> readKeyedMember spanValue value member setMethods SetMethodValue "Set"
  RecordValue owner fields -> case lookup member fields of
    Just found -> pure found
    Nothing -> readMethod spanValue value owner member
  VariantValue name _
    | name == member -> pure value
    | otherwise -> readMethod spanValue value name member
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
  , ("slice", StringSlice)
  , ("trim", StringTrim)
  , ("toUpper", StringToUpper)
  , ("toLower", StringToLower)
  , ("replace", StringReplace)
  , ("repeat", StringRepeat)
  , ("split", StringSplit)
  , ("chars", StringChars)
  , ("lines", StringLines)
  , ("reverse", StringReverse)
  ]

{-| Method names paired with their method tags. -}
arrayMethods :: [(Text, ArrayMethod)]
arrayMethods =
  [ ("length", ArrayLength)
  , ("get", ArrayGet)
  , ("indexOf", ArrayIndexOf)
  , ("contains", ArrayContains)
  , ("push", ArrayPush)
  , ("pop", ArrayPop)
  , ("insert", ArrayInsert)
  , ("remove", ArrayRemove)
  , ("slice", ArraySlice)
  , ("concat", ArrayConcat)
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
  CharValue _ -> Just "Char"
  BoolValue _ -> Just "Bool"
  UnitValue -> Just "()"
  ArrayValue _ -> Just "Array"
  MapValue _ -> Just "Map"
  SetValue _ -> Just "Set"
  TupleValue _ -> Nothing
  _ -> Nothing

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
  _ -> abortAt (Just spanValue) "E7001" "? expects a Result value" Nothing
