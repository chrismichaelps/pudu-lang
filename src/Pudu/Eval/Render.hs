{-| @Eval.Render.Module — how a runtime value prints -}
module Pudu.Eval.Render
  ( renderValue
  , valueKind
  ) where

import qualified Data.ByteString as ByteString
import qualified Data.IntMap.Strict as IntMap
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
  BuiltinValue BytesOfBuiltin -> "<builtin bytesOf>"
  BuiltinValue BucketsOfBuiltin -> "<builtin bucketsOf>"
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
  BytesMethodValue method _ -> "<byte method " <> bytesMethodName method <> ">"
  BucketsMethodValue method _ -> "<store method " <> bucketsMethodName method <> ">"
  ForeignValue binding ->
    "<foreign " <> foreignBindingLibrary binding <> "." <> foreignBindingSymbol binding <> ">"
  {-| Bytes print as hexadecimal pairs rather than as the text they might
      decode to. A sequence being inspected is usually one that did not decode,
      and rendering it as text would hide the bytes the reader is looking for
      behind replacement characters. -}
  BytesValue bytes ->
    "0x" <> Text.concat [hexPair byte | byte <- ByteString.unpack bytes]
  {-| A store prints its entries in key order. It is the buckets underneath a
      hash map rather than anything a program builds directly, so this is a
      reader inspecting the machinery rather than a value being shown. -}
  BucketsValue entries ->
    "#[" <> Text.intercalate ", "
      [Text.pack (show key) <> ": " <> renderValue held | (key, held) <- IntMap.toAscList entries]
      <> "]"
 where
  renderField (name, fieldValue) = name <> ": " <> renderValue fieldValue

  hexPair byte =
    let digits = "0123456789abcdef" :: String
        high = fromIntegral byte `div` (16 :: Int)
        low = fromIntegral byte `mod` (16 :: Int)
     in Text.pack [digits !! high, digits !! low]

escape :: Text -> Text
escape =
  Text.replace "\n" "\\n" . Text.replace "\t" "\\t" . Text.replace "\"" "\\\"" . Text.replace "\\" "\\\\"

{-| A short type-shaped label for diagnostics; it is a runtime shape, not a
    static type. -}
valueKind :: Value -> Text
valueKind value = case value of
  ForeignValue _ -> "foreign function"
  IntValue kind _ -> integerKindName kind
  FloatValue _ _ -> "float"
  DecimalValue _ -> "decimal"
  StrValue _ -> "string"
  BytesValue _ -> "bytes"
  BucketsValue _ -> "store"
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
  BytesMethodValue _ _ -> "byte method"
  BucketsMethodValue _ _ -> "store method"
