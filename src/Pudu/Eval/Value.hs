{-| @Eval.Value.Module — models runtime values -}
module Pudu.Eval.Value
  ( Builtin (..)
  , intOf
  , builtinName
  , ArrayMethod (..)
  , CharMethod (..)
  , MapMethod (..)
  , SetMethod (..)
  , mapMethodName
  , setMethodName
  , StringMethod (..)
  , charMethodName
  , stringMethodName
  , Closure (..)
  , Value (..)
  , renderValue
  , valueKind
  ) where

import Data.Foldable (toList)
import Data.Sequence (Seq)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Pudu.IntegerLiteral (IntegerKind, defaultIntegerKind, integerKindName)
import qualified Data.Text as Text
import Pudu.DecimalLiteral (Decimal, renderDecimal)
import Pudu.FloatLiteral (FloatWidth)
import Pudu.Frontend.Syntax.Tree (Function)
import Pudu.Source (Span)

{-| @Eval.Value.Runtime — one evaluated result.

    Integers are arbitrary precision. Floats retain their source-selected width
    beside normalized `Double` storage so binary32 operations cannot silently
    use binary64 intermediates. -}
{-| @Eval.Value — a value at run time.

    An integer carries its kind for the same reason a float carries its width:
    the type says `UInt8` and the value has to agree, or the type said nothing.
    Without it `~0u8` answers `-1` and `255u8 + 1u8` answers `256`, which are
    values those types do not have. -}
data Value
  = IntValue !IntegerKind !Integer
  | FloatValue !FloatWidth !Double
  | DecimalValue !Decimal
  | StrValue !Text
  | CharValue !Char
  | BoolValue !Bool
  | NullValue
  | UnitValue
  | TupleValue ![Value]
  | ArrayValue !(Seq Value)
  | MapValue ![(Value, Value)]
  | SetValue ![Value]
  | RecordValue !Text ![(Text, Value)]
  | VariantValue !Text ![Value]
  | FunctionValue !Closure
  | TaskValue !Closure ![(Text, Value)] !(Maybe Span)
  | BuiltinValue !Builtin
  | ArrayMethodValue !ArrayMethod !Value
  | StringMethodValue !StringMethod !Value
  | CharMethodValue !CharMethod !Value
  | MapMethodValue !MapMethod !Value
  | SetMethodValue !SetMethod !Value
  deriving stock (Eq, Show)

{-| The name a built-in answers to, which is the name it was bound under. -}
builtinName :: Builtin -> Text
builtinName value = case value of
  PanicBuiltin -> "panic"
  CharFromCodeBuiltin -> "charFromCode"
  MapOfBuiltin -> "mapOf"
  SetOfBuiltin -> "setOf"
  ShowBuiltin -> "show"
  DisplayBuiltin -> "display"
  PrintBuiltin -> "print"
  PrintErrorBuiltin -> "printError"
  ReadLineBuiltin -> "readLine"
  ReadFileBuiltin -> "readFile"
  WriteFileBuiltin -> "writeFile"
  AppendFileBuiltin -> "appendFile"
  FileExistsBuiltin -> "fileExists"
  RemoveFileBuiltin -> "removeFile"
  ListDirectoryBuiltin -> "listDirectory"
  CreateDirectoryBuiltin -> "createDirectory"
  ArgumentsBuiltin -> "arguments"
  EnvironmentBuiltin -> "environment"
  ExitBuiltin -> "exit"
  ClockBuiltin -> "clock"
  NowBuiltin -> "now"
  FormatTimeBuiltin -> "formatTime"
  ParseTimeBuiltin -> "parseTime"
  ZoneOffsetBuiltin -> "zoneOffset"
  RunBuiltin -> "runProgram"
  ConvertIntegerBuiltin -> "convertInteger"
  DecimalOfBuiltin -> "decimalOf"
  DecimalFromIntBuiltin -> "decimalFromInt"
  DecimalScaleBuiltin -> "decimalScale"
  DecimalToIntBuiltin -> "decimalToInt"
  DecimalToFloatBuiltin -> "decimalToFloat"
  DecimalDivideBuiltin -> "decimalDivide"
  DecimalRoundBuiltin -> "decimalRound"

{-| A plain `Int`, for the counts the runtime itself produces: a length, an
    index, a scalar value. That is the type the language gives an unsuffixed
    literal, so a caller comparing the two never has to convert. -}
intOf :: Integer -> Value
intOf = IntValue defaultIntegerKind

{-| A wired-in function the evaluator recognizes by name rather than by closure.
    `panic` is the prelude's unrecoverable abort: it takes a message and stops
    evaluation with `E7007`, matching [[architecture/SEMANTICS]]'s rule that
    panics represent violated invariants, not recoverable domain failure. -}
data Builtin
  = PanicBuiltin
  | CharFromCodeBuiltin
  | MapOfBuiltin
  | SetOfBuiltin
  | ShowBuiltin
  | DisplayBuiltin
  | PrintBuiltin
  | PrintErrorBuiltin
  | ReadLineBuiltin
  | ReadFileBuiltin
  | WriteFileBuiltin
  | AppendFileBuiltin
  | FileExistsBuiltin
  | RemoveFileBuiltin
  | ListDirectoryBuiltin
  | CreateDirectoryBuiltin
  | ArgumentsBuiltin
  | EnvironmentBuiltin
  | ExitBuiltin
  | ClockBuiltin
  | NowBuiltin
  | FormatTimeBuiltin
  | ParseTimeBuiltin
  | ZoneOffsetBuiltin
  | RunBuiltin
  | ConvertIntegerBuiltin
  | DecimalOfBuiltin
  | DecimalFromIntBuiltin
  | DecimalScaleBuiltin
  | DecimalToIntBuiltin
  | DecimalToFloatBuiltin
  | DecimalDivideBuiltin
  | DecimalRoundBuiltin
  deriving stock (Eq, Show)

{-| Tags the built-in array method so [[Evaluator]] can apply it with the right
    arity and semantics. The receiver is carried so `arr.push(x)` evaluates as
    `push(arr, x)`. -}
{-| @Eval.Value.StringMethod — one built-in text operation.

    Text is a value, so every one of these answers with a new string rather than
    changing the receiver. The set is closed for the same reason the array set
    is: a method the compiler knows the semantics of can be typed exactly, and
    an unknown one is reported rather than dispatched. -}
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
  | ArrayConcat
  | ArrayReverse
  | ArrayMap
  | ArrayFilter
  | ArrayReduce
  deriving stock (Eq, Show)

{-| @Eval.Value.Closure — a callable function.

    `closureSelf` is present when the function was reached as a method: the
    receiver is bound to the first parameter, which is what `value.method()`
    means.

    `closureCaptured` is present for a function *literal* and absent for a
    declaration. A declaration is called in the environment it is called from,
    which is what lets a module's functions see each other and an imported
    module's frame stay reachable. A literal cannot work that way: it may be
    returned, stored, and called long after the block that gave its free names
    meaning has ended, so it carries that environment with it. -}
data Closure = Closure
  { closureName :: !Text
  , closureFunction :: !Function
  , closureSelf :: !(Maybe Value)
  , closureCaptured :: !(Maybe [Map Text Value])
  }
  deriving stock (Eq, Show)

{-| Render a value the way the session prints it. Strings and characters show
    their quotes and escape their control characters, so a printed `"1"` is
    never mistaken for the integer and a newline never breaks the line. -}
renderValue :: Value -> Text
renderValue value = case value of
  IntValue _ number -> Text.pack (show number)
  FloatValue _ number -> Text.pack (show number)
  DecimalValue number -> renderDecimal number
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
  BuiltinValue CharFromCodeBuiltin -> "<builtin charFromCode>"
  BuiltinValue MapOfBuiltin -> "<builtin mapOf>"
  BuiltinValue SetOfBuiltin -> "<builtin setOf>"
  BuiltinValue ShowBuiltin -> "<builtin show>"
  BuiltinValue other -> "<builtin " <> builtinName other <> ">"
  MapValue entries ->
    "{" <> Text.intercalate ", " [renderValue key <> ": " <> renderValue held | (key, held) <- entries] <> "}"
  SetValue members -> "#{" <> Text.intercalate ", " (map renderValue members) <> "}"
  MapMethodValue method _ -> "<map method " <> mapMethodName method <> ">"
  SetMethodValue method _ -> "<set method " <> setMethodName method <> ">"
  ArrayMethodValue method _ -> "<array method " <> arrayMethodName method <> ">"
  StringMethodValue method _ -> "<text method " <> stringMethodName method <> ">"
  CharMethodValue method _ -> "<character method " <> charMethodName method <> ">"
 where
  renderField (name, fieldValue) = name <> ": " <> renderValue fieldValue

escape :: Text -> Text
escape =
  Text.replace "\n" "\\n" . Text.replace "\t" "\\t" . Text.replace "\"" "\\\"" . Text.replace "\\" "\\\\"

{-| A short type-shaped label for diagnostics; it is a runtime shape, not a
    static type. -}
valueKind :: Value -> Text
valueKind value = case value of
  IntValue kind _ -> integerKindName kind
  FloatValue _ _ -> "float"
  DecimalValue _ -> "decimal"
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
  MapValue _ -> "map"
  SetValue _ -> "set"
  MapMethodValue _ _ -> "map method"
  SetMethodValue _ _ -> "set method"
  ArrayMethodValue _ _ -> "array method"
  StringMethodValue _ _ -> "text method"
  CharMethodValue _ _ -> "character method"

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
  ArrayConcat -> "concat"
  ArrayReverse -> "reverse"
  ArrayMap -> "map"
  ArrayFilter -> "filter"
  ArrayReduce -> "reduce"
