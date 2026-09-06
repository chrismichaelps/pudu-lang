{-| @Program.Eval.Operator — applies operator and access semantics -}
module Pudu.Eval.Operator
  ( applyUnary
  , builtinMethodNamesFor
  , combine
  , nominalNameOf
  , readIndex
  , readMember
  , unwrapTry
  ) where

import Data.Bits (shiftL, shiftR)
import Data.Text (Text)

import Pudu.DecimalLiteral
  ( Decimal
  , DivisionFailure (DivideByZero, NonTerminating)
  , decimalAdd
  , decimalCompare
  , decimalDivideExact
  , decimalMultiply
  , decimalNegate
  , decimalSubtract
  )
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Operator.Access
  ( builtinMethodNamesFor
  , nominalNameOf
  , readIndex
  , readMember
  , unwrapTry
  )
import Pudu.Eval.Render (valueKind)
import Pudu.Eval.Value (Value (..))
import Pudu.FloatLiteral (FloatWidth (..), normalizeFloat)
import Pudu.IntegerLiteral
  ( IntegerKind (..)
  , integerKindAddWrapping
  , integerKindAnd
  , integerKindBounds
  , integerKindComplement
  , integerKindFits
  , integerKindMeet
  , integerKindMultiplyWrapping
  , integerKindName
  , integerKindOr
  , integerKindShift
  , integerKindSigned
  , integerKindSubtractWrapping
  , integerKindWidth
  , integerKindWrap
  , integerKindXor
  )
import Pudu.Source (Span)

{-| Borrowing and dereferencing are identities at run time: a reference is the
    value it refers to, and only typing distinguishes them. The distinction
    becomes observable when ownership checking and a store exist. -}
applyUnary :: Span -> Text -> Value -> Evaluator Value
applyUnary spanValue operator value = case (operator, value) of
  ("-", IntValue kind number) -> checkedResult spanValue kind "negate" (negate number)
  ("-", FloatValue width number) -> pure (FloatValue width (negate number))
  {-| A decimal negates as the other numbers do. Without this `-1.50d` checked
      as an ordinary negation and then refused at run time, which made a
      negative decimal literal something a reader could write and not use. -}
  ("-", DecimalValue number) -> pure (DecimalValue (decimalNegate number))
  ("!", BoolValue flag) -> pure (BoolValue (not flag))
  {-| Complement is a bit pattern, so it is taken over the type's own width.
      Without one, `~0u8` answers `-1`, which is not a value `UInt8` has. -}
  ("~", IntValue kind number) -> pure (IntValue kind (integerKindComplement kind number))
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
  (DecimalValue a, DecimalValue b) -> decimalOperation spanValue operator a b
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
  "&+" -> pure (IntValue kind (integerKindAddWrapping kind left right))
  "&-" -> pure (IntValue kind (integerKindSubtractWrapping kind left right))
  "&*" -> pure (IntValue kind (integerKindMultiplyWrapping kind left right))
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
  "^" -> pure (IntValue kind (integerKindXor kind left right))
  "&" -> pure (IntValue kind (integerKindAnd kind left right))
  "|" -> pure (IntValue kind (integerKindOr kind left right))
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

{-| A saturating result, clamped to the type's ends.

    `BigInt` has no ends, so nothing to clamp to and nothing to do. -}
saturatedResult :: IntegerKind -> Integer -> Evaluator Value
saturatedResult kind value = pure (IntValue kind clamped)
 where
  clamped = case integerKindBounds kind of
    Nothing -> value
    Just (low, high) -> max low (min high value)

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
        | otherwise -> pure (IntValue kind (integerKindShift kind toHigh value (fromInteger count)))
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

{-| Apply an operator to two decimals.

    Addition, subtraction, and multiplication are exact and cannot round: each
    result scale is decided entirely by the operand scales, so nothing has to be
    thrown away.

    Division is exact or it is a failure. `1d / 3d` has no base-ten expansion
    that terminates, and rounding it to some digit count nobody asked for is the
    decimal analogue of letting an integer overflow wrap silently — which this
    language already refuses. A program that wants a rounded quotient says so
    through `Decimal.divide`, which takes the precision and the mode. -}
decimalOperation :: Span -> Text -> Decimal -> Decimal -> Evaluator Value
decimalOperation spanValue operator left right = case operator of
  "+" -> pure (DecimalValue (decimalAdd left right))
  "-" -> pure (DecimalValue (decimalSubtract left right))
  "*" -> pure (DecimalValue (decimalMultiply left right))
  "/" -> case decimalDivideExact left right of
    Right value -> pure (DecimalValue value)
    Left DivideByZero ->
      abortAt (Just spanValue) "E7004" "decimal division by zero" Nothing
    Left NonTerminating ->
      abortAt (Just spanValue) "E7010"
        "this decimal quotient has no exact base-ten expansion"
        ( Just
            ( "use Decimal.divide(left, right, digits, mode) to say how many "
                <> "fractional digits to keep and how to round the last one"
            )
        )
  "==" -> comparison (== EQ)
  "!=" -> comparison (/= EQ)
  "<" -> comparison (== LT)
  "<=" -> comparison (/= GT)
  ">" -> comparison (== GT)
  ">=" -> comparison (/= LT)
  _ -> abortAt (Just spanValue) "E7001" ("unsupported operator " <> operator) Nothing
 where
  comparison accept = pure (BoolValue (accept (decimalCompare left right)))

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
