{-| @Eval.Render.Module — how a runtime value prints -}
module Pudu.Eval.Render
  ( renderValue
  , valueKind
  ) where

import Data.Foldable (toList)
import Data.Text (Text)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import Pudu.DecimalLiteral (renderDecimal)
import Pudu.IntegerLiteral (integerKindName)
import Pudu.Eval.Value

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
    "{" <> Text.intercalate ", " [renderValue (unOrdValue key) <> ": " <> renderValue held | (key, held) <- Map.toAscList entries] <> "}"
  SetValue members -> "#{" <> Text.intercalate ", " (map (renderValue . unOrdValue) (Set.toAscList members)) <> "}"
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
