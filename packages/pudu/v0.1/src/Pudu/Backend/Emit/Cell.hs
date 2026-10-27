{-| @Pudu.Backend.Emit.Cell — how one value sits in a cell: its C type, its
    union member, retaining and releasing it, rendering, equality, ordering
    and comparability of a member, and the names of per-type helpers. -}
module Pudu.Backend.Emit.Cell
  ( ownedType, cType, retained, released, mangle, mangleKey, aggregateHelper, aggregateNeed
  , isAggregate, memberRender, memberEqual, memberCompare, memberComparable, cellName, number
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Support (integerHelper, isWideInteger)
import Pudu.Core (CoreType (..), coreTypeName)
import Pudu.FloatLiteral (floatWidthType)
import Pudu.IntegerLiteral (integerKindName)

{-| Values a slot holds a reference to: the frame retains and releases them. -}
ownedType :: CoreType -> Bool
ownedType CoreTextType = True
ownedType (CoreTupleType _) = True
ownedType (CoreRecordType _ _) = True
ownedType (CoreSumType _ _) = True
ownedType (CoreFunctionType _ _) = True
ownedType (CoreArrayType _) = True
ownedType (CoreMapType _ _) = True
ownedType (CoreSetType _) = True
ownedType _ = False

cType :: CoreType -> Text
cType kind = case kind of
  CoreIntegerType integer | isWideInteger integer -> "pudu_wide_int"
  CoreIntegerType _ -> "pudu_int"
  CoreFloatType _ -> "uint64_t"
  CoreCharType -> "uint32_t"
  CoreTextType -> "pudu_text"
  CoreTupleType _ -> "pudu_box *"
  CoreRecordType _ _ -> "pudu_box *"
  CoreSumType _ _ -> "pudu_box *"
  CoreFunctionType _ _ -> "pudu_box *"
  CoreArrayType _ -> "pudu_box *"
  CoreMapType _ _ -> "pudu_box *"
  CoreSetType _ -> "pudu_box *"
  _ -> "int"

{-| A new reference to the value an expression reads, and what it needs. -}
retained :: CoreType -> Text -> (Text, [Text])
retained kind expression = case kind of
  CoreTextType -> ("pudu_text_retain(" <> expression <> ")", ["text_retain"])
  _ | isAggregate kind -> ("pudu_box_retain(" <> expression <> ")", [])
  _ -> (expression, [])

{-| A statement letting one reference go. -}
released :: CoreType -> Text -> Text
released kind expression = case kind of
  CoreTextType -> "pudu_text_release(" <> expression <> ");"
  _ | isAggregate kind -> aggregateHelper "drop" kind <> "(" <> expression <> ");"
  _ -> ""

mangle :: CoreType -> Text
mangle kind = case kind of
  CoreIntegerType integer -> integerKindName integer
  CoreFloatType width -> floatWidthType width
  CoreTupleType members -> "T" <> Text.pack (show (length members)) <> "_" <> Text.intercalate "_" (map mangle members) <> "_E"
  CoreRecordType name [] -> "R_" <> mangleKey name
  CoreRecordType name arguments -> "R" <> Text.pack (show (length arguments)) <> "_" <> Text.intercalate "_" (mangleKey name : map mangle arguments) <> "_E"
  CoreSumType name arguments -> "S" <> Text.pack (show (length arguments)) <> "_" <> Text.intercalate "_" (mangleKey name : map mangle arguments) <> "_E"
  CoreArrayType element -> "A_" <> mangle element <> "_E"
  CoreMapType key value -> "MP_" <> mangle key <> "_" <> mangle value <> "_E"
  CoreSetType member -> "ST_" <> mangle member <> "_E"
  CoreFunctionType inputs result -> "F" <> Text.pack (show (length inputs)) <> "_" <> Text.intercalate "_" (map mangle (inputs <> [result])) <> "_E"
  other -> coreTypeName other

{-| A canonical key as a C identifier part: each segment after its length, so
    `A.B_C` and `A_B.C` cannot meet. -}
mangleKey :: Text -> Text
mangleKey key = Text.concat [Text.pack (show (Text.length segment)) <> segment | segment <- Text.splitOn "." key]

aggregateHelper :: Text -> CoreType -> Text
aggregateHelper operation kind = "pudu_agg_" <> operation <> "_" <> mangle kind

aggregateNeed :: Text -> CoreType -> Text
aggregateNeed operation kind = "agg_" <> operation <> ":" <> mangle kind

isAggregate :: CoreType -> Bool
isAggregate kind = case kind of
  CoreTupleType _ -> True
  CoreRecordType _ _ -> True
  CoreSumType _ _ -> True
  CoreFunctionType _ _ -> True
  CoreArrayType _ -> True
  CoreMapType _ _ -> True
  CoreSetType _ -> True
  _ -> False

{-| A member rendered as `renderValue` writes it inside an aggregate. -}
memberRender :: CoreType -> Text -> (Text, [Text])
memberRender kind expression = case kind of
  CoreIntegerType integer
    | isWideInteger integer -> ("pudu_text_display_wide(" <> expression <> ")", ["text_display_wide"])
    | otherwise -> ("pudu_text_display_int(" <> expression <> ")", ["text_display_int"])
  CoreFloatType _ -> ("pudu_text_display_float(" <> expression <> ")", ["text_display_float"])
  CoreBoolType -> ("(" <> expression <> " ? pudu_text_literal(\"true\", 4) : pudu_text_literal(\"false\", 5))", ["text_literal"])
  CoreUnitType -> ("pudu_text_literal(\"()\", 2)", ["text_literal"])
  CoreCharType -> ("pudu_char_show(" <> expression <> ")", ["char_show"])
  CoreTextType -> ("pudu_text_show(" <> expression <> ")", ["text_show"])
  _ -> (aggregateHelper "show" kind <> "(" <> expression <> ")", [aggregateNeed "show" kind])

{-| `==` on two members, as Value's Eq instance has it. -}
memberEqual :: CoreType -> Text -> Text -> (Text, [Text])
memberEqual kind a b = case kind of
  CoreIntegerType _ -> let helper = integerHelper kind "compare" in ("pudu_" <> helper <> "(" <> a <> ", " <> b <> ") == 0", [helper])
  CoreFloatType _ -> ("pudu_float_eq(" <> a <> ", " <> b <> ")", ["float_eq"])
  CoreTextType -> ("pudu_text_compare(" <> a <> ", " <> b <> ") == 0", ["text_compare"])
  _ | isAggregate kind -> (aggregateHelper "equal" kind <> "(" <> a <> ", " <> b <> ")", [aggregateNeed "equal" kind])
  _ -> (a <> " == " <> b, [])

{-| compareValues on two members as -1, 0 or 1. Floats use its total order:
    NaN equals NaN and sorts after every number. -}
memberCompare :: CoreType -> Text -> Text -> (Text, [Text])
memberCompare kind a b = case kind of
  CoreIntegerType _ -> let helper = integerHelper kind "compare" in ("pudu_" <> helper <> "(" <> a <> ", " <> b <> ")", [helper])
  CoreFloatType _ -> ("pudu_float_order(" <> a <> ", " <> b <> ")", ["float_order"])
  CoreTextType -> ("pudu_text_compare(" <> a <> ", " <> b <> ")", ["text_compare"])
  CoreUnitType -> ("0", [])
  -- compareValues ranks two functions alike, so they never decide an order.
  CoreFunctionType _ _ -> ("0", [])
  _ | isAggregate kind -> (aggregateHelper "compare" kind <> "(" <> a <> ", " <> b <> ")", [aggregateNeed "compare" kind])
  _ -> ("(" <> a <> " > " <> b <> ") - (" <> a <> " < " <> b <> ")", [])

{-| Whether a member can be ordered, as comparableValue answers: a function
    cannot, and an aggregate can when everything it holds can. -}
memberComparable :: CoreType -> Text -> (Text, [Text])
memberComparable kind expression
  | isAggregate kind = (aggregateHelper "comparable" kind <> "(" <> expression <> ")", [aggregateNeed "comparable" kind])
  | otherwise = ("1", [])

cellName :: CoreType -> Text
cellName kind = case kind of
  CoreIntegerType integer | isWideInteger integer -> "wide"
  CoreIntegerType _ -> "integer"
  CoreFloatType _ -> "floating"
  CoreCharType -> "character"
  CoreTextType -> "text"
  _ | isAggregate kind -> "box"
  _ -> "scalar"

number :: Int -> Text
number = Text.pack . show
