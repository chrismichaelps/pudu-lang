{-| @Eval.Value.Module — models runtime values -}
module Pudu.Eval.Value
  ( Builtin (..)
  , ArrayMethod (..)
  , StringMethod (..)
  , stringMethodName
  , Closure (..)
  , Value (..)
  , renderValue
  , valueKind
  ) where

import Data.Foldable (toList)
import Data.Sequence (Seq)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.FloatLiteral (FloatWidth)
import Pudu.Frontend.Syntax.Tree (Function)
import Pudu.Source (Span)

{-| @Eval.Value.Runtime — one evaluated result.

    Integers are arbitrary precision. Floats retain their source-selected width
    beside normalized `Double` storage so binary32 operations cannot silently
    use binary64 intermediates. -}
data Value
  = IntValue !Integer
  | FloatValue !FloatWidth !Double
  | StrValue !Text
  | CharValue !Char
  | BoolValue !Bool
  | NullValue
  | UnitValue
  | TupleValue ![Value]
  | ArrayValue !(Seq Value)
  | RecordValue !Text ![(Text, Value)]
  | VariantValue !Text ![Value]
  | FunctionValue !Closure
  | TaskValue !Closure ![(Text, Value)] !(Maybe Span)
  | BuiltinValue !Builtin
  | ArrayMethodValue !ArrayMethod !Value
  | StringMethodValue !StringMethod !Value
  deriving stock (Eq, Show)

{-| A wired-in function the evaluator recognizes by name rather than by closure.
    `panic` is the prelude's unrecoverable abort: it takes a message and stops
    evaluation with `E7007`, matching [[architecture/SEMANTICS]]'s rule that
    panics represent violated invariants, not recoverable domain failure. -}
data Builtin = PanicBuiltin
  deriving stock (Eq, Show)

{-| Tags the built-in array method so [[Evaluator]] can apply it with the right
    arity and semantics. The receiver is carried so `arr.push(x)` evaluates as
    `push(arr, x)`. -}
{-| @Eval.Value.StringMethod — one built-in text operation.

    Text is a value, so every one of these answers with a new string rather than
    changing the receiver. The set is closed for the same reason the array set
    is: a method the compiler knows the semantics of can be typed exactly, and
    an unknown one is reported rather than dispatched. -}
data StringMethod
  = StringLength
  | StringIsEmpty
  | StringCharAt
  | StringIndexOf
  | StringContains
  | StringStartsWith
  | StringEndsWith
  | StringSlice
  | StringTrim
  | StringToUpper
  | StringToLower
  | StringReplace
  | StringRepeat
  | StringSplit
  | StringChars
  | StringLines
  | StringReverse
  deriving stock (Eq, Show)

data ArrayMethod
  = ArrayLength
  | ArrayGet
  | ArrayIndexOf
  | ArrayContains
  | ArrayPush
  | ArrayPop
  | ArrayInsert
  | ArrayRemove
  | ArraySlice
  | ArrayReverse
  | ArrayMap
  | ArrayFilter
  | ArrayReduce
  deriving stock (Eq, Show)

{-| @Eval.Value.Closure — a callable function.

    `closureSelf` is present when the function was reached as a method: the
    receiver is bound to the first parameter, which is what `value.method()`
    means. -}
data Closure = Closure
  { closureName :: !Text
  , closureFunction :: !Function
  , closureSelf :: !(Maybe Value)
  }
  deriving stock (Eq, Show)

{-| Render a value the way the session prints it. Strings and characters show
    their quotes and escape their control characters, so a printed `"1"` is
    never mistaken for the integer and a newline never breaks the line. -}
renderValue :: Value -> Text
renderValue value = case value of
  IntValue number -> Text.pack (show number)
  FloatValue _ number -> Text.pack (show number)
  StrValue text -> "\"" <> escape text <> "\""
  CharValue character -> "'" <> escape (Text.singleton character) <> "'"
  BoolValue flag -> if flag then "true" else "false"
  NullValue -> "null"
  UnitValue -> "()"
  TupleValue members -> "(" <> Text.intercalate ", " (map renderValue members) <> ")"
  ArrayValue members -> "[" <> Text.intercalate ", " (map renderValue (toList members)) <> "]"
  RecordValue name fields ->
    name <> "{" <> Text.intercalate ", " (map renderField fields) <> "}"
  VariantValue name payload
    | null payload -> name
    | otherwise -> name <> "(" <> Text.intercalate ", " (map renderValue payload) <> ")"
  FunctionValue closure -> "<fn " <> closureName closure <> ">"
  TaskValue closure _ _ -> "<task " <> closureName closure <> ">"
  BuiltinValue PanicBuiltin -> "<builtin panic>"
  ArrayMethodValue method _ -> "<array method " <> arrayMethodName method <> ">"
  StringMethodValue method _ -> "<text method " <> stringMethodName method <> ">"
 where
  renderField (name, fieldValue) = name <> ": " <> renderValue fieldValue

escape :: Text -> Text
escape =
  Text.replace "\n" "\\n" . Text.replace "\t" "\\t" . Text.replace "\"" "\\\"" . Text.replace "\\" "\\\\"

{-| A short type-shaped label for diagnostics; it is a runtime shape, not a
    static type. -}
valueKind :: Value -> Text
valueKind value = case value of
  IntValue _ -> "integer"
  FloatValue _ _ -> "float"
  StrValue _ -> "string"
  CharValue _ -> "char"
  BoolValue _ -> "bool"
  NullValue -> "null"
  UnitValue -> "unit"
  TupleValue _ -> "tuple"
  ArrayValue _ -> "array"
  RecordValue name _ -> name
  VariantValue name _ -> name
  FunctionValue _ -> "function"
  TaskValue _ _ _ -> "task"
  BuiltinValue _ -> "builtin"
  ArrayMethodValue _ _ -> "array method"
  StringMethodValue _ _ -> "text method"

{-| The name a text method answers to, which is the same spelling the checker
    matches and the diagnostic prints. -}
stringMethodName :: StringMethod -> Text
stringMethodName method = case method of
  StringLength -> "length"
  StringIsEmpty -> "isEmpty"
  StringCharAt -> "charAt"
  StringIndexOf -> "indexOf"
  StringContains -> "contains"
  StringStartsWith -> "startsWith"
  StringEndsWith -> "endsWith"
  StringSlice -> "slice"
  StringTrim -> "trim"
  StringToUpper -> "toUpper"
  StringToLower -> "toLower"
  StringReplace -> "replace"
  StringRepeat -> "repeat"
  StringSplit -> "split"
  StringChars -> "chars"
  StringLines -> "lines"
  StringReverse -> "reverse"

arrayMethodName :: ArrayMethod -> Text
arrayMethodName method = case method of
  ArrayLength -> "length"
  ArrayGet -> "get"
  ArrayIndexOf -> "indexOf"
  ArrayContains -> "contains"
  ArrayPush -> "push"
  ArrayPop -> "pop"
  ArrayInsert -> "insert"
  ArrayRemove -> "remove"
  ArraySlice -> "slice"
  ArrayReverse -> "reverse"
  ArrayMap -> "map"
  ArrayFilter -> "filter"
  ArrayReduce -> "reduce"
