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
  , OrdValue (..)
  , compareValues
  , arrayMethodName
  ) where

import Data.Foldable (toList)
import Data.Sequence (Seq)
import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)
import Pudu.IntegerLiteral (IntegerKind, defaultIntegerKind)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.DecimalLiteral (Decimal, decimalCompare)
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
  | MapValue !(Map OrdValue Value)
  | SetValue !(Set OrdValue)
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
  TemporaryDirectoryBuiltin -> "temporaryPath"
  HomeDirectoryBuiltin -> "userHome"
  PathSeparatorsBuiltin -> "pathSeparators"
  SearchSeparatorBuiltin -> "searchSeparator"
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
  | TemporaryDirectoryBuiltin
  | HomeDirectoryBuiltin
  | PathSeparatorsBuiltin
  | SearchSeparatorBuiltin
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

{-| @Eval.Value.OrdValue — a value used as a key.

    Keyed collections need a total order on the values they hold, and `Value`
    deliberately has none: a function is a value, and no order on functions is
    meaningful. Wrapping the ones that can be ordered keeps that distinction
    visible at every use rather than hiding it behind an instance that would
    silently accept a key it cannot compare.

    The wrapper and its order live here rather than beside `comparableValue`
    because the keyed collections are constructors of `Value` itself: a map is
    keyed by this order, so the type cannot be declared without it. -}
newtype OrdValue = OrdValue {unOrdValue :: Value}
  deriving stock (Eq, Show)

instance Ord OrdValue where
  compare (OrdValue left) (OrdValue right) = compareValues left right

{-| Compare two values.

    Values of different shapes are ordered by shape, so a map may hold keys of
    more than one type without the comparison becoming partial. Within a shape
    the order is the obvious one: numeric for numbers, scalar order for text and
    characters, and lexicographic for every aggregate.

    Two values that cannot be ordered compare equal. That is not a claim that
    they are: it keeps the order total so a malformed key cannot make the
    structure inconsistent, and the caller is refused the insertion before it
    ever gets here. -}
compareValues :: Value -> Value -> Ordering
compareValues left right = case (left, right) of
  (IntValue _ a, IntValue _ b) -> compare a b
  (FloatValue _ a, FloatValue _ b) -> compare a b
  (IntValue _ a, FloatValue _ b) -> compare (fromIntegral a) b
  (FloatValue _ a, IntValue _ b) -> compare a (fromIntegral b)
  {-| Two decimals compare as the numbers they are, not as the digits they
      store, so `1.50d` and `1.5d` are equal even though only one of them
      renders with a trailing zero. A number whose `==` depended on how it was
      written would fail the one property every reader assumes of one. -}
  (DecimalValue a, DecimalValue b) -> decimalCompare a b
  (StrValue a, StrValue b) -> compare a b
  (CharValue a, CharValue b) -> compare a b
  (BoolValue a, BoolValue b) -> compare a b
  (NullValue, NullValue) -> EQ
  (UnitValue, UnitValue) -> EQ
  (TupleValue a, TupleValue b) -> compareLists a b
  (ArrayValue a, ArrayValue b) -> compareLists (toList a) (toList b)
  {-| Two keyed collections compare entry by entry in key order, which is the
      order they are held in, so two built differently still compare equal. -}
  (MapValue a, MapValue b) -> compareEntries (Map.toAscList a) (Map.toAscList b)
  (SetValue a, SetValue b) -> compareLists (map unOrdValue (Set.toAscList a)) (map unOrdValue (Set.toAscList b))
  (RecordValue nameA a, RecordValue nameB b) ->
    compare nameA nameB <> compareFields a b
  (VariantValue nameA a, VariantValue nameB b) ->
    compare nameA nameB <> compareLists a b
  _ -> compare (shapeRank left) (shapeRank right)

compareLists :: [Value] -> [Value] -> Ordering
compareLists [] [] = EQ
compareLists [] _ = LT
compareLists _ [] = GT
compareLists (a : as) (b : bs) = compareValues a b <> compareLists as bs

compareEntries :: [(OrdValue, Value)] -> [(OrdValue, Value)] -> Ordering
compareEntries [] [] = EQ
compareEntries [] _ = LT
compareEntries _ [] = GT
compareEntries ((keyA, a) : as) ((keyB, b) : bs) =
  compare keyA keyB <> compareValues a b <> compareEntries as bs

{-| Records compare field by field in declaration order, which is the order the
    reader wrote them and therefore the one they can predict. -}
compareFields :: [(Text, Value)] -> [(Text, Value)] -> Ordering
compareFields [] [] = EQ
compareFields [] _ = LT
compareFields _ [] = GT
compareFields ((nameA, a) : as) ((nameB, b) : bs) =
  compare nameA nameB <> compareValues a b <> compareFields as bs

{-| The order between shapes, so values of different kinds still compare. The
    numbers have no meaning beyond being distinct and stable. -}
shapeRank :: Value -> Int
shapeRank value = case value of
  UnitValue -> 0
  NullValue -> 1
  BoolValue _ -> 2
  IntValue _ _ -> 3
  FloatValue _ _ -> 3
  DecimalValue _ -> 18
  CharValue _ -> 4
  StrValue _ -> 5
  TupleValue _ -> 6
  ArrayValue _ -> 7
  SetValue _ -> 16
  MapValue _ -> 17
  VariantValue _ _ -> 8
  RecordValue _ _ -> 9
  FunctionValue _ -> 10
  TaskValue{} -> 11
  BuiltinValue _ -> 12
  ArrayMethodValue _ _ -> 13
  StringMethodValue _ _ -> 14
  CharMethodValue _ _ -> 15
  MapMethodValue _ _ -> 18
  SetMethodValue _ _ -> 19


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
