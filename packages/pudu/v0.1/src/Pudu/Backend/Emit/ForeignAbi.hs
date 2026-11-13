{-| @Backend.Emit.ForeignAbi — the C side of every foreign crossing type: the
    type it has at the boundary, the conversions between it and a frame cell,
    and for each record a struct laid out as C lays out the declaration, with
    the functions that pack a record box into it and unpack one out of it. -}
module Pudu.Backend.Emit.ForeignAbi
  ( Layouts, abiType, toAbi, fromAbi, mangle, recordsIn, recordDefinitions, textLeaves, recordNeeds
  ) where

import Data.Char (isAsciiLower, isAsciiUpper, isDigit, ord)
import Data.List (nub)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed, cType, cellName)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreLayout (..), CoreType (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))

type Layouts = Map CoreType CoreLayout

{-| The C type a crossing type has at the boundary, as the interpreter's bridge
    hands it over; a record is its struct. -}
abiType :: CoreType -> Text
abiType kind = case kind of
  CoreIntegerType (SignedKind width) -> "int" <> textOfInt width <> "_t"
  CoreIntegerType (UnsignedKind width) -> "uint" <> textOfInt width <> "_t"
  CoreFloatType Float32Width -> "float"
  CoreFloatType _ -> "double"
  CoreBoolType -> "uint8_t"
  CoreTextType -> "const char *"
  CoreBytesType -> "const void *"
  CoreRecordType _ _ -> structName kind
  _ -> "void"

{-| A scalar cell as the C value it crosses as. -}
toAbi :: CoreType -> Text -> Text
toAbi kind cell = case kind of
  CoreIntegerType (SignedKind _) -> "(" <> abiType kind <> ")pudu_kernel_signed(" <> cell <> ".bits)"
  CoreIntegerType _ -> "(" <> abiType kind <> ")" <> cell <> ".bits"
  CoreFloatType Float32Width -> "(float)pudu_float_decode(" <> cell <> ")"
  CoreFloatType _ -> "pudu_float_decode(" <> cell <> ")"
  CoreBoolType -> "(uint8_t)(" <> cell <> " != 0)"
  CoreBytesType -> "pudu_foreign_bytes_in(" <> cell <> ")"
  _ -> cell

{-| A scalar C answer as its cell. -}
fromAbi :: CoreType -> Text -> Text
fromAbi kind value = case kind of
  CoreIntegerType (SignedKind _) -> "pudu_kernel_int((int64_t)" <> value <> ")"
  CoreIntegerType _ -> "pudu_make((uint64_t)" <> value <> ", 0)"
  CoreFloatType _ -> "pudu_float_encode((double)" <> value <> ")"
  CoreBoolType -> "(" <> value <> " != 0)"
  _ -> value

{-| Text made a C identifier fragment, distinct for distinct text. -}
mangle :: Text -> Text
mangle = Text.concatMap escape
 where
  escape c
    | isAsciiLower c || isAsciiUpper c || isDigit c = Text.singleton c
    | otherwise = Text.pack ("_" <> pad (showHex (ord c) ""))
  pad digits = replicate (2 - length digits) '0' <> digits

structName :: CoreType -> Text
structName kind = "pudu_foreign_record_" <> mangle (Text.pack (show kind))

fieldsOf :: Layouts -> CoreType -> [(Text, CoreType)]
fieldsOf layouts kind = case Map.lookup kind layouts of
  Just (CoreRecordLayout fields) -> fields
  _ -> []

{-| Every record the types reach, each after the records it holds. -}
recordsIn :: Layouts -> [CoreType] -> [CoreType]
recordsIn layouts = nub . concatMap visit
 where
  visit kind@(CoreRecordType _ _) = concatMap (visit . snd) (fieldsOf layouts kind) <> [kind]
  visit _ = []

{-| How many text leaves a crossing type holds. -}
textLeaves :: Layouts -> CoreType -> Int
textLeaves layouts kind = case kind of
  CoreTextType -> 1
  CoreRecordType _ _ -> sum (map (textLeaves layouts . snd) (fieldsOf layouts kind))
  _ -> 0

{-| The aggregate helpers unpacking a record result needs: its constructor
    and those of the records it holds, and their release. -}
recordNeeds :: Layouts -> CoreType -> [Text]
recordNeeds layouts kind = concat [[aggregateNeed "make" record, aggregateNeed "drop" record] | record <- recordsIn layouts [kind]]

{-| For each record: its struct, its pack function (box to struct, copying
    text fields through the nought check into `held`), and its unpack
    function (struct to a new box, text fields copied out and checked). -}
recordDefinitions :: Layouts -> [CoreType] -> [Text]
recordDefinitions layouts = concatMap definition
 where
  definition kind =
    let fields = zip [0 :: Int ..] (fieldsOf layouts kind)
        name = structName kind
        cell index field = "box->fields[" <> textOfInt index <> "]." <> cellName field
        packed (index, (_, field)) = case field of
          CoreTextType -> "  record.f" <> textOfInt index <> " = held[(*count)++] = pudu_foreign_text_in(noughts, " <> cell index field <> ");"
          CoreRecordType _ _ -> "  record.f" <> textOfInt index <> " = pudu_foreign_pack_" <> structSuffix field <> "(noughts, " <> cell index field <> ", held, count);"
          _ -> "  record.f" <> textOfInt index <> " = " <> toAbi field (cell index field) <> ";"
        unpacked (index, (label, field)) = "  " <> cType field <> " v" <> textOfInt index <> " = " <> case field of
          CoreTextType -> "pudu_foreign_text_field(missing, invalid, symbol, " <> quoted label <> ", record.f" <> textOfInt index <> ");"
          CoreRecordType _ _ -> "pudu_foreign_unpack_" <> structSuffix field <> "(missing, invalid, symbol, record.f" <> textOfInt index <> ");"
          _ -> fromAbi field ("record.f" <> textOfInt index) <> ";"
        released (index, (_, field)) = case field of
          CoreTextType -> ["  pudu_text_release(v" <> textOfInt index <> ");"]
          CoreRecordType _ _ -> ["  " <> aggregateHelper "drop" field <> "(v" <> textOfInt index <> ");"]
          _ -> []
     in [ "typedef struct {" ]
        <> [ "  " <> abiType field <> " f" <> textOfInt index <> ";" | (index, (_, field)) <- fields ]
        <> [ "} " <> name <> ";"
           , "PUDU_OPTIONAL static " <> name <> " pudu_foreign_pack_" <> structSuffix kind
               <> "(const pudu_site *noughts, pudu_box *box, char **held, size_t *count) {"
           , "  " <> name <> " record;"
           , "  (void)noughts; (void)held; (void)count;" ]
        <> map packed fields
        <> [ "  return record;", "}"
           , "PUDU_OPTIONAL static pudu_box *pudu_foreign_unpack_" <> structSuffix kind
               <> "(const pudu_site *missing, const pudu_site *invalid, const char *symbol, " <> name <> " record) {"
           , "  pudu_box *made;"
           , "  (void)missing; (void)invalid; (void)symbol;" ]
        <> map unpacked fields
        <> [ "  made = " <> aggregateHelper "make" kind <> "(" <> Text.intercalate ", " ["v" <> textOfInt index | (index, _) <- fields] <> ");" ]
        <> concatMap released fields
        <> [ "  return made;", "}", "" ]
  structSuffix kind = Text.drop (Text.length "pudu_foreign_record_") (structName kind)
  quoted label = "\"" <> label <> "\""
