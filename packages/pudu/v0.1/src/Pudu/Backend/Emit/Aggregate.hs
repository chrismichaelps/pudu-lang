{-| @Pudu.Backend.Emit.Aggregate — owned cells, tuple helper names, and the
    per-type tuple helpers a program actually calls.

    Helper needs travel in the emitter's ordinary need set as `tuple_make:X`,
    `tuple_show:X`, `tuple_equal:X` and `tuple_compare:X`, where X is the
    type's mangled name. `aggregateSection` turns the ones it sees into C and
    reports which runtime parts those helpers lean on. -}
module Pudu.Backend.Emit.Aggregate
  ( ownedType, ownedKinds, retained, released, cType, memberRender
  , tupleHelper, tupleNeed, aggregateTypes, aggregateSection
  ) where

import Data.List (sortOn)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Support (integerHelper, isWideInteger)
import Pudu.Core (CoreType (..), coreTypeName)
import Pudu.Core.Frame (FrameFunction (..), FrameModule (..), FrameSlot (..))
import Pudu.IntegerLiteral (integerKindName)
import Pudu.FloatLiteral (floatWidthType)

{-| Values a slot holds a reference to: the frame retains and releases them. -}
ownedType :: CoreType -> Bool
ownedType CoreTextType = True
ownedType (CoreTupleType _) = True
ownedType _ = False

cType :: CoreType -> Text
cType kind = case kind of
  CoreIntegerType integer | isWideInteger integer -> "pudu_wide_int"
  CoreIntegerType _ -> "pudu_int"
  CoreFloatType _ -> "uint64_t"
  CoreCharType -> "uint32_t"
  CoreTextType -> "pudu_text"
  CoreTupleType _ -> "pudu_box *"
  _ -> "int"

{-| A new reference to the value an expression reads, and what it needs. -}
retained :: CoreType -> Text -> (Text, [Text])
retained kind expression = case kind of
  CoreTextType -> ("pudu_text_retain(" <> expression <> ")", ["text_retain"])
  CoreTupleType _ -> ("pudu_box_retain(" <> expression <> ")", [])
  _ -> (expression, [])

{-| A statement letting one reference go. -}
released :: CoreType -> Text -> Text
released kind expression = case kind of
  CoreTextType -> "pudu_text_release(" <> expression <> ");"
  CoreTupleType _ -> tupleHelper "drop" kind <> "(" <> expression <> ");"
  _ -> ""

mangle :: CoreType -> Text
mangle kind = case kind of
  CoreIntegerType integer -> integerKindName integer
  CoreFloatType width -> floatWidthType width
  CoreTupleType members -> "T" <> Text.pack (show (length members)) <> "_" <> Text.intercalate "_" (map mangle members) <> "_E"
  other -> coreTypeName other

tupleHelper :: Text -> CoreType -> Text
tupleHelper operation kind = "pudu_tuple_" <> operation <> "_" <> mangle kind

tupleNeed :: Text -> CoreType -> Text
tupleNeed operation kind = "tuple_" <> operation <> ":" <> mangle kind

{-| Every tuple type a frame mentions, members before the tuples holding them. -}
aggregateTypes :: FrameModule -> [CoreType]
aggregateTypes source = sortOn depth (foldr collect [] slotTypes)
 where
  slotTypes = concat
    [ frameFunctionResult function : map frameSlotType (frameFunctionParameters function <> frameFunctionSlots function)
    | function <- frameModuleFunctions source ]
  collect kind found = case kind of
    CoreTupleType members | kind `notElem` found -> foldr collect (kind : found) members
    _ -> found
  depth (CoreTupleType members) = 1 + maximum (0 : map depth members)
  depth _ = 0 :: Int

{-| Ownership kinds the frame engine switches on: 1 is text, then each tuple
    type in `aggregateTypes` order. -}
ownedKinds :: [CoreType] -> [(CoreType, Int)]
ownedKinds tuples = (CoreTextType, 1) : zip tuples [2 ..]

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
  _ -> (tupleHelper "show" kind <> "(" <> expression <> ")", [tupleNeed "show" kind])

{-| The helpers the needs name, their own needs included, in an order where
    each comes after what it calls; and the runtime parts they use. Drop
    helpers are always written, since the frame engine releases every owned
    slot through them. -}
aggregateSection :: [CoreType] -> Set Text -> ([Text], Set Text)
aggregateSection tuples needs = (concat chosen, runtime)
 where
  wanted = close (Set.fromList ([tupleNeed "drop" kind | kind <- tuples]
    <> filter ("tuple_" `Text.isPrefixOf`) (Set.toList needs)))
  close found =
    let next = Set.union found (Set.fromList (concat [helperNeeds name | name <- Set.toList found]))
     in if next == found then found else close next
  helperNeeds name = filter ("tuple_" `Text.isPrefixOf`) (maybe [] fst (lookup name catalogue))
  chosen = [body | operation <- ["drop", "make", "equal", "compare", "show"], kind <- tuples
    , let name = tupleNeed operation kind, Set.member name wanted
    , Just (_, body) <- [lookup name catalogue]]
  runtime = Set.fromList (concat [filter (not . ("tuple_" `Text.isPrefixOf`)) (fst entry)
    | (name, entry) <- catalogue, Set.member name wanted])
  catalogue = concat [helpers kind | kind <- tuples]

helpers :: CoreType -> [(Text, ([Text], [Text]))]
helpers kind@(CoreTupleType members) =
  [ (tupleNeed "drop" kind, ([tupleNeed "drop" member | member <- members, isTuple member],
      [ "static void " <> tupleHelper "drop" kind <> "(pudu_box *box) {"
      , "  if (box == NULL || --box->count != 0) return;" ]
      <> [ "  " <> released member (field index member) | (index, member) <- indexed, ownedType member ]
      <> [ "  free(box);", "}" ]))
  , (tupleNeed "make" kind, (concat [snd (retained member "") | member <- members],
      [ "static pudu_box *" <> tupleHelper "make" kind <> "("
          <> Text.intercalate ", " [cType member <> " m" <> number index | (index, member) <- indexed] <> ") {"
      , "  pudu_box *box = pudu_box_new(" <> number (length members) <> ");" ]
      <> [ "  " <> field index member <> " = " <> fst (retained member ("m" <> number index)) <> ";" | (index, member) <- indexed ]
      <> [ "  return box;", "}" ]))
  , (tupleNeed "show" kind, ("text_join" : concat [snd (memberRender member "") | member <- members],
      [ "static pudu_text " <> tupleHelper "show" kind <> "(pudu_box *box) {"
      , "  pudu_text parts[" <> number (length members) <> "];" ]
      <> [ "  parts[" <> number index <> "] = " <> fst (memberRender member (field index member)) <> ";" | (index, member) <- indexed ]
      <> [ "  return pudu_text_join(\"(\", parts, " <> number (length members) <> ", \")\");", "}" ]))
  , (tupleNeed "equal" kind, (concat [snd (memberEqual member "" "") | member <- members],
      [ "static int " <> tupleHelper "equal" kind <> "(pudu_box *a, pudu_box *b) {"
      , "  return " <> Text.intercalate "\n    && " [fst (memberEqual member (on "a" index member) (on "b" index member)) | (index, member) <- indexed] <> ";"
      , "}" ]))
  , (tupleNeed "compare" kind, (concat [snd (memberCompare member "" "") | member <- members],
      [ "/* compareValues: the first member that differs decides. */"
      , "static int " <> tupleHelper "compare" kind <> "(pudu_box *a, pudu_box *b) {"
      , "  int order;" ]
      <> concat [ [ "  order = " <> fst (memberCompare member (on "a" index member) (on "b" index member)) <> ";"
                  , "  if (order != 0) return order;" ] | (index, member) <- indexed ]
      <> [ "  return 0;", "}" ]))
  ]
 where
  indexed = zip [0 :: Int ..] members
  field index member = on "box" index member
  on box index member = box <> "->fields[" <> number index <> "]." <> cellName member
  isTuple (CoreTupleType _) = True
  isTuple _ = False
helpers _ = []

{-| `==` on two members, as Value's Eq instance has it. -}
memberEqual :: CoreType -> Text -> Text -> (Text, [Text])
memberEqual kind a b = case kind of
  CoreIntegerType _ -> let helper = integerHelper kind "compare" in ("pudu_" <> helper <> "(" <> a <> ", " <> b <> ") == 0", [helper])
  CoreFloatType _ -> ("pudu_float_eq(" <> a <> ", " <> b <> ")", ["float_eq"])
  CoreTextType -> ("pudu_text_compare(" <> a <> ", " <> b <> ") == 0", ["text_compare"])
  CoreTupleType _ -> (tupleHelper "equal" kind <> "(" <> a <> ", " <> b <> ")", [tupleNeed "equal" kind])
  _ -> (a <> " == " <> b, [])

{-| compareValues on two members as -1, 0 or 1. A float that is neither less
    nor equal is greater, which is where NaN lands. -}
memberCompare :: CoreType -> Text -> Text -> (Text, [Text])
memberCompare kind a b = case kind of
  CoreIntegerType _ -> let helper = integerHelper kind "compare" in ("pudu_" <> helper <> "(" <> a <> ", " <> b <> ")", [helper])
  CoreFloatType _ -> ("pudu_float_lt(" <> a <> ", " <> b <> ") ? -1 : pudu_float_eq(" <> a <> ", " <> b <> ") ? 0 : 1", ["float_lt", "float_eq"])
  CoreTextType -> ("pudu_text_compare(" <> a <> ", " <> b <> ")", ["text_compare"])
  CoreTupleType _ -> (tupleHelper "compare" kind <> "(" <> a <> ", " <> b <> ")", [tupleNeed "compare" kind])
  CoreUnitType -> ("0", [])
  _ -> ("(" <> a <> " > " <> b <> ") - (" <> a <> " < " <> b <> ")", [])

cellName :: CoreType -> Text
cellName kind = case kind of
  CoreIntegerType integer | isWideInteger integer -> "wide"
  CoreIntegerType _ -> "integer"
  CoreFloatType _ -> "floating"
  CoreCharType -> "character"
  CoreTextType -> "text"
  CoreTupleType _ -> "box"
  _ -> "scalar"

number :: Int -> Text
number = Text.pack . show
