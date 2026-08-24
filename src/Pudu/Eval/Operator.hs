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
import Pudu.Eval.Value (Closure (..), Value (..), ArrayMethod (..), StringMethod (..), CharMethod (..), valueKind)
import Pudu.FloatLiteral (FloatWidth, normalizeFloat)
import Pudu.Source (Span)

{-| Borrowing and dereferencing are identities at run time: a reference is the
    value it refers to, and only typing distinguishes them. The distinction
    becomes observable when ownership checking and a store exist. -}
applyUnary :: Span -> Text -> Value -> Evaluator Value
applyUnary spanValue operator value = case (operator, value) of
  ("-", IntValue number) -> pure (IntValue (negate number))
  ("-", FloatValue width number) -> pure (FloatValue width (negate number))
  ("!", BoolValue flag) -> pure (BoolValue (not flag))
  ("~", IntValue number) -> pure (IntValue (complement number))
  ("&", _) -> pure value
  ("&mut", _) -> pure value
  ("*", _) -> pure value
  _ ->
    abortAt (Just spanValue) "E7001"
      ("cannot apply " <> operator <> " to a " <> valueKind value) Nothing

combine :: Span -> Text -> Value -> Value -> Evaluator Value
combine spanValue operator left right = case (left, right) of
  (IntValue a, IntValue b) -> integerOperation spanValue operator a b
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

integerOperation :: Span -> Text -> Integer -> Integer -> Evaluator Value
integerOperation spanValue operator left right = case operator of
  "+" -> pure (IntValue (left + right))
  "-" -> pure (IntValue (left - right))
  "*" -> pure (IntValue (left * right))
  "&+" -> pure (IntValue (left + right))
  "&-" -> pure (IntValue (left - right))
  "&*" -> pure (IntValue (left * right))
  "+|" -> pure (IntValue (left + right))
  "-|" -> pure (IntValue (left - right))
  "*|" -> pure (IntValue (left * right))
  "/" ->
    if right == 0
      then abortAt (Just spanValue) "E7004" "division by zero" Nothing
      else pure (IntValue (quot left right))
  "%" ->
    if right == 0
      then abortAt (Just spanValue) "E7004" "division by zero" Nothing
      else pure (IntValue (rem left right))
  ".." -> pure (TupleValue (map IntValue [left .. right - 1]))
  "..=" -> pure (TupleValue (map IntValue [left .. right]))
  "<<" -> pure (IntValue (shiftL left (fromInteger right)))
  ">>" -> pure (IntValue (shiftR left (fromInteger right)))
  "^" -> pure (IntValue (xor left right))
  "&" -> pure (IntValue (left .&. right))
  "|" -> pure (IntValue (left .|. right))
  _ -> comparisonOnly spanValue operator left right

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
  (TupleValue members, IntValue index)
    | index >= 0 && fromInteger index < length members -> pure (members !! fromInteger index)
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  (ArrayValue members, IntValue index)
    | index >= 0 && fromInteger index < Seq.length members ->
        case Seq.lookup (fromInteger index) members of
          Just value -> pure value
          Nothing -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
    | otherwise -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
  (StrValue text, IntValue index)
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
  RecordValue owner fields -> case lookup member fields of
    Just found -> pure found
    Nothing -> readMethod spanValue value owner member
  VariantValue name _
    | name == member -> pure value
    | otherwise -> readMethod spanValue value name member
  _ ->
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
    Nothing ->
      abortAt (Just spanValue) "E7001"
        ("no method " <> member <> " on an array") Nothing

{-| Text methods are built into the evaluator for the same reason array methods
    are: their semantics are fixed, so the checker can type them exactly and the
    evaluator can implement them without a library that would need `unsafe` to
    reach the representation. -}
readStringMember :: Span -> Value -> Text -> Evaluator Value
readStringMember spanValue text member =
  case lookup member stringMethods of
    Just method -> pure (StringMethodValue method text)
    Nothing ->
      abortAt (Just spanValue) "E7001"
        ("no method " <> member <> " on text") Nothing

{-| A character answers only for its scalar value. Everything a reader wants to
    ask about a character — is it a digit, a letter, whitespace — is answered by
    `Std.Char` in the language, where the answer can be read and argued with. -}
readCharMember :: Span -> Value -> Text -> Evaluator Value
readCharMember spanValue character member
  | member == "code" = pure (CharMethodValue CharCode character)
  | otherwise =
      abortAt (Just spanValue) "E7001"
        ("no method " <> member <> " on a character") Nothing

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
  , ("reverse", ArrayReverse)
  , ("map", ArrayMap)
  , ("filter", ArrayFilter)
  , ("reduce", ArrayReduce)
  ]

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
