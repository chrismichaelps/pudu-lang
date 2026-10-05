{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ViewPatterns #-}
{-| @Eval.Value.Module — models runtime values -}
module Pudu.Eval.Value
  ( Builtin (..)
  , intOf
  , zeroValue
  , oneValue
  , boolValue
  , trueValue
  , falseValue
  , builtinName
  , ArrayMethod (..)
  , BytesMethod (..)
  , BucketsMethod (..)
  , CharMethod (..)
  , MapMethod (..)
  , RangeMethod (..)
  , rangeMethodName
  , SetMethod (..)
  , bytesMethodName
  , bucketsMethodName
  , mapMethodName
  , setMethodName
  , StringMethod (..)
  , charMethodName
  , stringMethodName
  , Captured (..)
  , Frame (..)
  , Closure (..)
  , Value (.., StrValue, MapValue)
  , intPairMap
  , IntPairEntry (..)
  , ropeOfValue
  , ForeignBinding (..)
  , ForeignClaim (..)
  , ForeignRelease (..)
  , ForeignSlot (..)
  , OrdValue (..)
  , compareValues
  , arrayMethodName
  ) where

import Data.ByteString (ByteString)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.Foldable (toList)
import Data.Sequence (Seq)
import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)
import Data.IORef (IORef)
import GHC.IOArray (IOArray)
import Pudu.Eval.Rope (Rope, ropeOf, ropeText)
import Pudu.Eval.Method
import Pudu.IntegerLiteral (IntegerKind, defaultIntegerKind)
import Pudu.Eval.Builtin.Definition (Builtin (..), builtinName)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.DecimalLiteral (Decimal, decimalCompare)
import Data.Int (Int64)
import Pudu.FloatLiteral (FloatWidth)
import Pudu.Eval.Foreign.Binding (ForeignBinding (..), ForeignClaim (..), ForeignRelease (..), ForeignSlot (..))
import Pudu.Frontend.Syntax.Tree (Function)
import Pudu.Source (Span)
import Pudu.Runtime.SeriesMap (SeriesMap)
import qualified Pudu.Runtime.SeriesMap as SeriesMap

{-| Strict metadata avoids retaining the temporary numeric conversion tuple. -}
data IntPairEntry = PlatformIntPairEntry !Value | IntPairEntry !IntegerKind !IntegerKind !Value
  deriving stock (Show)

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
  {-| Text as one contiguous value: every text that was not built by `+`. -}
  | FlatText !Text
  {-| Text built by `+`, held as the chunks it was appended from so that
      building one a piece at a time does not copy it at every step. -}
  | RopeText !Rope
  {-| A byte sequence is its own value rather than an `Array[UInt8]`.

      An array holds each element as a separate runtime value and reaches the
      nth of them by descending a tree, so a byte would carry an integer kind
      and an arbitrary-precision payload of its own and every read would walk.
      Input measured in gigabytes is not merely slow on that shape; it does not
      fit. One contiguous buffer stores a byte in a byte, and a slice of it
      names a stretch of the same storage rather than copying. -}
  | BytesValue !ByteString
  {-| An indexed store, reached by a number rather than by comparison.

      It exists for `Std.HashMap`, which cannot reach its buckets through the
      ordered map without paying an ordered lookup for every hashed one. The
      store holds no opinion about hashing or equality: those belong to the
      library, where a type's own `Eq` can be called. -}
  | BucketsValue !(IntMap Value)
  {-| Two ends and a rule for reading them, rather than the numbers between.

      `0..1000000` is three fields here and a million values if it were the
      list it stands for, which is the difference between a loop that starts
      and one that allocates first. Either end may be absent, which is what
      lets `items[2..]` mean the tail of something whose length the writer
      never had to ask for; the value that is indexed supplies what is missing.

      Elements are platform integers, which is the type a range's ends are
      checked at. -}
  | RangeValue !(Maybe Integer) !Bool !(Maybe Integer)
  | CharValue !Char
  | BoolValue !Bool
  | NullValue
  | UnitValue
  | TupleValue ![Value]
  | ArrayValue !(Seq Value)
  | OrderedMapValue !(Map OrdValue Value)
  {-| Numeric occurrence storage with its ordered view computed only on demand. -}
  | IntPairMapValue !(IntMap (SeriesMap IntPairEntry)) ~(Map OrdValue Value)
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
  | RangeMethodValue !RangeMethod !Value
  | BytesMethodValue !BytesMethod !Value
  | BucketsMethodValue !BucketsMethod !Value
  {-| `value.toText()` for a value whose type answers no `toText` of its own:
      the receiver, bound, rendered as `display` renders it when called. Every
      value has one, so a program never needs to know which built-in types
      carry a text method before asking for text. -}
  | TextMethodValue !Value
  {-| A function that is somebody else's, reached through the boundary the
      declaration describes.

      It is a value like any other so that passing one around, naming one, and
      calling one all work the way calling anything here works. What is not like
      anything else is that its type was asserted rather than proved, which is
      why reaching it needed the foreign capability at the call site. -}
  | ForeignValue !ForeignBinding
  {-| Something a foreign library handed back, under the name its block gave it.

      Opaque: the address is carried and never read through, and the name keeps
      a texture from being passed where a window is wanted. What makes it worth
      being a value of its own rather than a number is that the runtime knows
      what frees it, so releasing one twice is refused where it happens instead
      of being a fault the operating system reports much later. -}
  | ForeignHandleValue !Text !Int64 !ForeignClaim
  deriving stock (Show)

{-| Both map representations expose the same persistent ordered contents. -}
pattern MapValue :: Map OrdValue Value -> Value
pattern MapValue entries <- (mapOfValue -> Just entries)
  where
    MapValue entries = OrderedMapValue entries

mapOfValue :: Value -> Maybe (Map OrdValue Value)
mapOfValue value = case value of
  OrderedMapValue entries -> Just entries
  IntPairMapValue _ entries -> Just entries
  _ -> Nothing

{-| The view is lazy and shared; native integer updates never force it. -}
intPairMap :: IntMap (SeriesMap IntPairEntry) -> Value
intPairMap index = IntPairMapValue index $ Map.fromDistinctAscList
  [ (OrdValue (TupleValue [IntValue keyKind (toInteger number), IntValue valueKind (toInteger member)]), count)
  | (number, values) <- IntMap.toAscList index
  , (member, entry) <- SeriesMap.toAscList values
  , let (keyKind, valueKind, count) = case entry of
          PlatformIntPairEntry value -> (defaultIntegerKind, defaultIntegerKind, value)
          IntPairEntry a b value -> (a, b, value)
  ]

{-| A text value, read as its whole text and built from one.

    Matching joins an appended text once and keeps the join, so every reader
    sees plain text; `+` on two texts appends ropes instead of copying. Text
    that was never appended to stays flat and carries no rope. -}
{-# INLINE StrValue #-}
pattern StrValue :: Text -> Value
pattern StrValue text <- (textOf -> Just text)
  where
    StrValue text = FlatText text

{-| The whole text of a text value, joining an appended one once. -}
textOf :: Value -> Maybe Text
{-# INLINE textOf #-}
textOf value = case value of
  FlatText text -> Just text
  RopeText rope -> Just (ropeText rope)
  _ -> Nothing

{-| A text value as a rope, ready to be appended to without copying. -}
ropeOfValue :: Value -> Maybe Rope
ropeOfValue value = case value of
  FlatText text -> Just (ropeOf text)
  RopeText rope -> Just rope
  _ -> Nothing

{-# COMPLETE IntValue, FloatValue, DecimalValue, StrValue, BytesValue, BucketsValue, RangeValue, CharValue, BoolValue, NullValue, UnitValue, TupleValue, ArrayValue, MapValue, SetValue, RecordValue, VariantValue, FunctionValue, TaskValue, BuiltinValue, ArrayMethodValue, StringMethodValue, CharMethodValue, MapMethodValue, SetMethodValue, RangeMethodValue, BytesMethodValue, BucketsMethodValue, TextMethodValue, ForeignValue, ForeignHandleValue #-}

{-| Aggregate equality follows numeric Decimal equality without changing the
    retained scale or the identity of closures and foreign handle claims. -}
instance Eq Value where
  left == right = case (left, right) of
    (IntValue kindA a, IntValue kindB b) -> kindA == kindB && a == b
    (FloatValue widthA a, FloatValue widthB b) -> widthA == widthB && a == b
    (DecimalValue a, DecimalValue b) -> decimalCompare a b == EQ
    (StrValue a, StrValue b) -> a == b
    (BytesValue a, BytesValue b) -> a == b
    (BucketsValue a, BucketsValue b) -> a == b
    (CharValue a, CharValue b) -> a == b
    (BoolValue a, BoolValue b) -> a == b
    (TupleValue a, TupleValue b) -> a == b
    (ArrayValue a, ArrayValue b) -> a == b
    (MapValue a, MapValue b) -> a == b
    (SetValue a, SetValue b) -> a == b
    (FunctionValue a, FunctionValue b) -> a == b
    (BuiltinValue a, BuiltinValue b) -> a == b
    (TextMethodValue a, TextMethodValue b) -> a == b
    (ForeignValue a, ForeignValue b) -> a == b
    (NullValue, NullValue) -> True
    (UnitValue, UnitValue) -> True
    (RecordValue tagA a, RecordValue tagB b) -> tagA == tagB && a == b
    (VariantValue tagA a, VariantValue tagB b) -> tagA == tagB && a == b
    (ArrayMethodValue tagA a, ArrayMethodValue tagB b) -> tagA == tagB && a == b
    (StringMethodValue tagA a, StringMethodValue tagB b) -> tagA == tagB && a == b
    (CharMethodValue tagA a, CharMethodValue tagB b) -> tagA == tagB && a == b
    (MapMethodValue tagA a, MapMethodValue tagB b) -> tagA == tagB && a == b
    (SetMethodValue tagA a, SetMethodValue tagB b) -> tagA == tagB && a == b
    (RangeMethodValue tagA a, RangeMethodValue tagB b) -> tagA == tagB && a == b
    (BytesMethodValue tagA a, BytesMethodValue tagB b) -> tagA == tagB && a == b
    (BucketsMethodValue tagA a, BucketsMethodValue tagB b) -> tagA == tagB && a == b
    (RangeValue lowA inclusiveA highA, RangeValue lowB inclusiveB highB) ->
      lowA == lowB && inclusiveA == inclusiveB && highA == highB
    (TaskValue closureA bindingsA spanA, TaskValue closureB bindingsB spanB) ->
      closureA == closureB && bindingsA == bindingsB && spanA == spanB
    (ForeignHandleValue nameA addressA claimA, ForeignHandleValue nameB addressB claimB) ->
      nameA == nameB && addressA == addressB && claimA == claimB
    _ -> False

{-| A plain `Int`, for the counts the runtime itself produces: a length, an
    index, a scalar value. That is the type the language gives an unsuffixed
    literal, so a caller comparing the two never has to convert. -}
intOf :: Integer -> Value
intOf 0 = zeroValue
intOf 1 = oneValue
intOf n = IntValue defaultIntegerKind n

zeroValue :: Value
zeroValue = IntValue defaultIntegerKind 0

oneValue :: Value
oneValue = IntValue defaultIntegerKind 1

{-| Reusable boolean values that avoid allocating on every comparison or check. -}
{-# INLINE boolValue #-}
boolValue :: Bool -> Value
boolValue True = trueValue
boolValue False = falseValue

trueValue :: Value
trueValue = BoolValue True

falseValue :: Value
falseValue = BoolValue False

{-| Tags the built-in array method so [[Evaluator]] can apply it with the right
    arity and semantics. The receiver is carried so `arr.push(x)` evaluates as
    `push(arr, x)`. -}
{-| @Eval.Value.StringMethod — one built-in text operation.

    Text is a value, so every one of these answers with a new string rather than
    changing the receiver. The set is closed for the same reason the array set
    is: a method the compiler knows the semantics of can be typed exactly, and
    an unknown one is reported rather than dispatched. -}

{-| @Eval.Value.Frame — one level of bindings.

    A map frame holds names as they are bound; a cell frame updates private
    block-local cells and snapshots their values for captures. A slot frame belongs to a
    compiled body: its locals sit in an array at positions fixed when the body
    was compiled, named by the layout, and a name bound at run time that the
    body never declared goes to the extra map. Everything that works by name
    reads these representations through the same frame operations. -}
data Frame
  = MapFrame !(Map Text Value)
  | CellFrame !(IORef (Map Text (IORef Value)))
  | SlotFrame !(Map Text Int) !(IOArray Int Value) !(IORef (Map Text Value))

instance Show Frame where
  show frame = case frame of
    MapFrame held -> "MapFrame " <> show held
    CellFrame _ -> "CellFrame"
    SlotFrame layout _ _ -> "SlotFrame " <> show (Map.keys layout)

{-| @Eval.Value.Closure — a callable function.

    `closureSelf` is present when the function was reached as a method: the
    receiver is bound to the first parameter, which is what `value.method()`
    means.

    `closureCaptured` carries both the retained frames and the module boundary.
    A literal may be returned, stored, and called long after the block that gave
    its free names meaning has ended, so it carries its narrowed environment.
    A declaration is scoped to the module frames installed by the linker. The
    boundary travels with either capture so a nested literal can still tell
    durable module bindings from transient call locals. -}
data Captured = Captured
  { capturedEnvironment :: ![Frame]
  , capturedModuleDepth :: !Int
  }
  deriving stock (Show)

data Closure = Closure
  { closureName :: !Text
  , closureFunction :: !Function
  , closureSelf :: !(Maybe Value)
  , closureCaptured :: !(Maybe Captured)
  {-| Proven after immutable capture; forced once by the first invocation. -}
  , closureMultiMap :: ~(Maybe (Span, Builtin))
  }
  deriving stock (Show)

{-| Two closures are the same when they are the same function reached the same
    way.

    The captured environment is deliberately left out. A module's functions see
    each other, so the environment a declaration captures holds that declaration
    among its own bindings, and walking it to compare would not terminate — a
    scope removing the child it had just awaited would compare one task against
    itself and never finish.

    Nothing that compares closures is asking about the environment. The question
    is always which closure this is, and the name, the function, and the
    receiver it was reached through answer that. -}
instance Eq Closure where
  left == right =
    closureName left == closureName right
      && closureSelf left == closureSelf right
      && closureFunction left == closureFunction right

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
  {-| Byte sequences order by their contents, which for bytes is both the
      lexicographic order and the numeric one. -}
  (BytesValue a, BytesValue b) -> compare a b
  {-| Two stores compare entry by entry in key order, so two built by different
      routes to the same contents compare equal. -}
  (BucketsValue a, BucketsValue b) ->
    compareIndexed (IntMap.toAscList a) (IntMap.toAscList b)
  {-| Two ranges compare by where they start, then by how far they reach, so
      an ordered collection holding ranges holds them in the order they cover.
      An absent end sorts before every present one, which is the order the two
      `Maybe`s already have. -}
  (RangeValue lowA inclusiveA highA, RangeValue lowB inclusiveB highB) ->
    compare lowA lowB <> compare highA highB <> compare inclusiveA inclusiveB
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

compareIndexed :: [(Int, Value)] -> [(Int, Value)] -> Ordering
compareIndexed [] [] = EQ
compareIndexed [] _ = LT
compareIndexed _ [] = GT
compareIndexed ((keyA, a) : as) ((keyB, b) : bs) =
  compare keyA keyB <> compareValues a b <> compareIndexed as bs

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
    numbers have no meaning beyond being distinct and stable.

    Distinct is the property that matters. Two shapes sharing a rank compare
    equal, which for a keyed collection means two values of different kinds
    collapsing onto one entry. Integers and floats share rank 3 deliberately,
    because the case above already compares them against each other and the
    rank is never reached; every other shape holds a rank of its own. -}
shapeRank :: Value -> Int
shapeRank value = case value of
  UnitValue -> 0
  NullValue -> 1
  BoolValue _ -> 2
  IntValue _ _ -> 3
  FloatValue _ _ -> 3
  CharValue _ -> 4
  StrValue _ -> 5
  TupleValue _ -> 6
  ArrayValue _ -> 7
  VariantValue _ _ -> 8
  RecordValue _ _ -> 9
  FunctionValue _ -> 10
  TaskValue{} -> 11
  BuiltinValue _ -> 12
  ArrayMethodValue _ _ -> 13
  StringMethodValue _ _ -> 14
  CharMethodValue _ _ -> 15
  SetValue _ -> 16
  MapValue _ -> 17
  DecimalValue _ -> 18
  MapMethodValue _ _ -> 19
  SetMethodValue _ _ -> 20
  BytesValue _ -> 21
  BytesMethodValue _ _ -> 22
  BucketsValue _ -> 23
  BucketsMethodValue _ _ -> 24
  ForeignValue _ -> 25
  ForeignHandleValue _ _ _ -> 26
  RangeValue{} -> 27
  RangeMethodValue _ _ -> 28
  TextMethodValue _ -> 29
