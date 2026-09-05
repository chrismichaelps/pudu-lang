{-| @Eval.Value.Module — models runtime values -}
module Pudu.Eval.Value
  ( Builtin (..)
  , intOf
  , builtinName
  , ArrayMethod (..)
  , BytesMethod (..)
  , BucketsMethod (..)
  , CharMethod (..)
  , MapMethod (..)
  , SetMethod (..)
  , bytesMethodName
  , bucketsMethodName
  , mapMethodName
  , setMethodName
  , StringMethod (..)
  , charMethodName
  , stringMethodName
  , Closure (..)
  , Value (..)
  , ForeignBinding (..)
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
import Pudu.Eval.Method
import Pudu.IntegerLiteral (IntegerKind, defaultIntegerKind)
import Pudu.Eval.Builtin.Definition (Builtin (..), builtinName)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.DecimalLiteral (Decimal, decimalCompare)
import Data.Int (Int64)
import Pudu.FloatLiteral (FloatWidth)
import Pudu.Foreign.Crossing (Crossing)
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
  | BytesMethodValue !BytesMethod !Value
  | BucketsMethodValue !BucketsMethod !Value
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
  | ForeignHandleValue !Text !Int64 !Integer
  deriving stock (Eq, Show)

{-| Everything the runtime needs to make one foreign call.

    Resolved from the declaration rather than looked up per call: the library
    name, the symbol, and how each value crosses. Nothing here is decided while
    the program is running, so a call is a call rather than a search. -}
data ForeignBinding = ForeignBinding
  { foreignBindingLibrary :: !Text
  {-| The ABI version the declaration named, which the platform's own naming
      puts inside the file name rather than beside it. -}
  , foreignBindingVersion :: !(Maybe Text)
  , foreignBindingSymbol :: !Text
  {-| How every native argument crosses, slots included: the bridge needs a kind
      for each position whether the value is sent or written back. -}
  , foreignBindingArguments :: ![Crossing]
  {-| Which of those positions the library writes rather than reads, in the same
      order. An ordinary argument carries nothing here. -}
  , foreignBindingSlots :: ![Maybe ForeignSlot]
  , foreignBindingResult :: !Crossing
  , foreignBindingReleasedBy :: !(Maybe ForeignRelease)
  {-| The handle type this function releases, when it is a release.

      Known from the declaration rather than guessed at the call: a release is
      whatever some function in the same block named after `by`. -}
  , foreignBindingReleases :: !(Maybe Text)
  }
  deriving stock (Eq, Show)

{-| One argument the library writes rather than reads.

    Carries what the slot answers with rather than what the caller sends: the
    handle type when it is a handle, so the address it receives can be claimed
    under the same name a direct result would be, and the destructor that claim
    retains. -}
data ForeignSlot = ForeignSlot
  { foreignSlotCrossing :: !Crossing
  , foreignSlotReleasedBy :: !(Maybe ForeignRelease)
  }
  deriving stock (Eq, Show)

{-| The exact native destructor an owned result retains for runtime teardown. -}
data ForeignRelease = ForeignRelease
  { foreignReleaseLibrary :: !Text
  , foreignReleaseVersion :: !(Maybe Text)
  , foreignReleaseSymbol :: !Text
  }
  deriving stock (Eq, Show)

{-| A plain `Int`, for the counts the runtime itself produces: a length, an
    index, a scalar value. That is the type the language gives an unsuffixed
    literal, so a caller comparing the two never has to convert. -}
intOf :: Integer -> Value
intOf = IntValue defaultIntegerKind

{-| Tags the built-in array method so [[Evaluator]] can apply it with the right
    arity and semantics. The receiver is carried so `arr.push(x)` evaluates as
    `push(arr, x)`. -}
{-| @Eval.Value.StringMethod — one built-in text operation.

    Text is a value, so every one of these answers with a new string rather than
    changing the receiver. The set is closed for the same reason the array set
    is: a method the compiler knows the semantics of can be typed exactly, and
    an unknown one is reported rather than dispatched. -}

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

