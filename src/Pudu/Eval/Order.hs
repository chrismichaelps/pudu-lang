{-| @Eval.Order.Module — a total order on runtime values -}
module Pudu.Eval.Order
  ( OrdValue (..)
  , comparableValue
  , compareValues
  ) where

import Data.Foldable (toList)
import Data.Text (Text)
import Pudu.Eval.Value (Value (..))

{-| @Eval.Order.OrdValue — a value used as a key.

    Keyed collections need a total order on the values they hold, and the
    runtime's `Value` deliberately has none: a function is a value, and no order
    on functions is meaningful. Wrapping the ones that can be ordered keeps that
    distinction visible at every use rather than hiding it behind an instance
    that would silently accept a key it cannot compare. -}
newtype OrdValue = OrdValue {unOrdValue :: Value}
  deriving stock (Eq, Show)

instance Ord OrdValue where
  compare (OrdValue left) (OrdValue right) = compareValues left right

{-| Whether a value can be a key.

    A function, a task, and a partially applied built-in method cannot: two of
    them are equal only when their syntax is, and no ordering of them means
    anything to a reader. Everything a program can compare with `<` can be a
    key, and so can the aggregates built out of those. -}
comparableValue :: Value -> Bool
comparableValue value = case value of
  FunctionValue _ -> False
  TaskValue{} -> False
  BuiltinValue _ -> False
  ArrayMethodValue _ _ -> False
  StringMethodValue _ _ -> False
  CharMethodValue _ _ -> False
  MapValue entries -> all (\(key, held) -> comparableValue key && comparableValue held) entries
  SetValue members -> all comparableValue members
  TupleValue members -> all comparableValue members
  ArrayValue members -> all comparableValue (toList members)
  RecordValue _ fields -> all (comparableValue . snd) fields
  VariantValue _ payload -> all comparableValue payload
  _ -> True

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
  (IntValue a, IntValue b) -> compare a b
  (FloatValue _ a, FloatValue _ b) -> compare a b
  (IntValue a, FloatValue _ b) -> compare (fromIntegral a) b
  (FloatValue _ a, IntValue b) -> compare a (fromIntegral b)
  (StrValue a, StrValue b) -> compare a b
  (CharValue a, CharValue b) -> compare a b
  (BoolValue a, BoolValue b) -> compare a b
  (NullValue, NullValue) -> EQ
  (UnitValue, UnitValue) -> EQ
  (TupleValue a, TupleValue b) -> compareLists a b
  (ArrayValue a, ArrayValue b) -> compareLists (toList a) (toList b)
  (MapValue a, MapValue b) -> compareEntries a b
  (SetValue a, SetValue b) -> compareLists a b
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

{-| Maps compare entry by entry in key order, which is the order they are kept
    in, so two maps with the same entries compare equal however they were
    built. -}
compareEntries :: [(Value, Value)] -> [(Value, Value)] -> Ordering
compareEntries [] [] = EQ
compareEntries [] _ = LT
compareEntries _ [] = GT
compareEntries ((keyA, a) : as) ((keyB, b) : bs) =
  compareValues keyA keyB <> compareValues a b <> compareEntries as bs

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
  IntValue _ -> 3
  FloatValue _ _ -> 3
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
