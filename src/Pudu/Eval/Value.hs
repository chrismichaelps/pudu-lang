{-| @Eval.Value.Module — models runtime values -}
module Pudu.Eval.Value
  ( Builtin (..)
  , Closure (..)
  , Value (..)
  , renderValue
  , valueKind
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Tree (Function)

{-| @Eval.Value.Runtime — one evaluated result.

    Integers are arbitrary precision and floats are host doubles: without a
    typing phase there is no declared width to wrap or saturate against, so the
    evaluator computes exactly and leaves width-dependent behaviour to the
    slice that introduces types. -}
data Value
  = IntValue !Integer
  | FloatValue !Double
  | StrValue !Text
  | CharValue !Char
  | BoolValue !Bool
  | NullValue
  | UnitValue
  | TupleValue ![Value]
  | RecordValue !Text ![(Text, Value)]
  | VariantValue !Text ![Value]
  | FunctionValue !Closure
  | BuiltinValue !Builtin
  deriving stock (Eq, Show)

{-| A wired-in function the evaluator recognizes by name rather than by closure.
    `panic` is the prelude's unrecoverable abort: it takes a message and stops
    evaluation with `E7007`, matching [[architecture/SEMANTICS]]'s rule that
    panics represent violated invariants, not recoverable domain failure. -}
data Builtin = PanicBuiltin
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
  FloatValue number -> Text.pack (show number)
  StrValue text -> "\"" <> escape text <> "\""
  CharValue character -> "'" <> escape (Text.singleton character) <> "'"
  BoolValue flag -> if flag then "true" else "false"
  NullValue -> "null"
  UnitValue -> "()"
  TupleValue members -> "(" <> Text.intercalate ", " (map renderValue members) <> ")"
  RecordValue name fields ->
    name <> "{" <> Text.intercalate ", " (map renderField fields) <> "}"
  VariantValue name payload
    | null payload -> name
    | otherwise -> name <> "(" <> Text.intercalate ", " (map renderValue payload) <> ")"
  FunctionValue closure -> "<fn " <> closureName closure <> ">"
  BuiltinValue PanicBuiltin -> "<builtin panic>"
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
  FloatValue _ -> "float"
  StrValue _ -> "string"
  CharValue _ -> "char"
  BoolValue _ -> "bool"
  NullValue -> "null"
  UnitValue -> "unit"
  TupleValue _ -> "tuple"
  RecordValue name _ -> name
  VariantValue name _ -> name
  FunctionValue _ -> "function"
  BuiltinValue _ -> "builtin"
