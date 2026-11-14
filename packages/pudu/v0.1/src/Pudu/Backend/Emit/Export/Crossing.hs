{-| @Pudu.Backend.Emit.Export.Crossing — the C shape of every type an exported
    function passes or returns, the declarations a host header carries for
    them, and the generated conversions between those shapes and cells. -}
module Pudu.Backend.Emit.Export.Crossing
  ( crossingName, crossingDeclarations, crossingPrototypes, crossingHelpers, takeCell, giveValue, crossingNeeds
  ) where

import Data.Maybe (isJust)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Aggregate (aggregateHelper, aggregateNeed, cType, released)
import Pudu.Backend.Emit.Cell (cellName)
import Pudu.Backend.Emit.ForeignAbi (Layouts, abiType, fromAbi, mangle, recordsIn, toAbi)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreLayout (..), CoreType (..), coreTypeName)
import Pudu.IntegerLiteral (IntegerKind (..))

{-| Words a C struct member may not be named; such a field gets a trailing
    underscore. -}
cKeywords :: Set Text
cKeywords = Set.fromList
  [ "alignas", "alignof", "auto", "bool", "break", "case", "char", "const", "constexpr", "continue"
  , "default", "do", "double", "else", "enum", "extern", "false", "float", "for", "goto", "if"
  , "inline", "int", "long", "nullptr", "register", "restrict", "return", "short", "signed"
  , "sizeof", "static", "static_assert", "struct", "switch", "thread_local", "true", "typedef"
  , "typeof", "union", "unsigned", "void", "volatile", "while" ]

stringType :: Text
stringType = "pudu_string"

{-| The C type a value of this type crosses as, when it crosses at all. -}
crossingName :: Layouts -> CoreType -> Maybe Text
crossingName layouts = named Set.empty
 where
  named seen kind = case kind of
    CoreIntegerType (SignedKind width) | width <= 64 -> Just (abiType kind)
    CoreIntegerType (UnsignedKind width) | width <= 64 -> Just (abiType kind)
    CoreFloatType _ -> Just (abiType kind)
    CoreBoolType -> Just (abiType kind)
    CoreTextType -> Just stringType
    CoreRecordType _ _
      | Set.notMember kind seen
      , fields@(_ : _) <- fieldsOf layouts kind
      , all (isJust . named (Set.insert kind seen) . snd) fields -> Just (recordName kind)
    _ -> Nothing

{-| The type declarations both the header and the program carry: the text
    struct when any text crosses, then each record after those it holds. -}
crossingDeclarations :: Layouts -> [CoreType] -> [Text]
crossingDeclarations layouts roots =
  [ "typedef struct { const char *bytes; size_t length; } " <> stringType <> ";" | reaches layouts CoreTextType roots ]
    <> concatMap declaration (recordsIn layouts roots)
 where
  declaration kind =
    ["typedef struct {"]
      <> [ "  " <> maybe "void" id (crossingName layouts field) <> " " <> memberName name <> ";" | (name, field) <- fieldsOf layouts kind ]
      <> ["} " <> recordName kind <> ";"]

{-| The functions a host header declares beside the exports: the release
    of text results, when a result reaches text. -}
crossingPrototypes :: Layouts -> [CoreType] -> [Text]
crossingPrototypes layouts outbound =
  [ "void pudu_string_release(" <> stringType <> " text);" | reaches layouts CoreTextType outbound ]

{-| The conversion functions the exports use: inbound for what parameters
    reach, outbound for what results reach, each only when used. -}
crossingHelpers :: Layouts -> [CoreType] -> [CoreType] -> [Text]
crossingHelpers layouts inbound outbound =
  concat [textIn | reaches layouts CoreTextType inbound]
    <> concat [textOut | reaches layouts CoreTextType outbound]
    <> concatMap take' (recordsIn layouts inbound)
    <> concatMap give (recordsIn layouts outbound)
 where
  textIn =
    [ "/* Host text is checked and copied; the host keeps its bytes. */"
    , "static pudu_text pudu_export_text_in(const char *name, " <> stringType <> " text) {"
    , "  if (text.bytes == NULL && text.length != 0) pudu_export_misuse(name, \"with text that has no bytes\");"
    , "  if (text.length != 0 && !pudu_utf8_valid((const unsigned char *)text.bytes, text.length))"
    , "    pudu_export_misuse(name, \"with text that is not UTF-8\");"
    , "  return pudu_text_copy(text.bytes, text.length);"
    , "}" ]
  textOut =
    [ "/* A text result is the host's: an owned, terminated copy. */"
    , "static " <> stringType <> " pudu_export_text_out(pudu_text text) {"
    , "  char *copy = malloc(text.length + 1);"
    , "  if (copy == NULL) pudu_memory_failure();"
    , "  if (text.length != 0) memcpy(copy, text.bytes, text.length);"
    , "  copy[text.length] = 0;"
    , "  return (" <> stringType <> "){copy, text.length};"
    , "}"
    , "void pudu_string_release(" <> stringType <> " text);"
    , "void pudu_string_release(" <> stringType <> " text) {"
    , "  free((void *)text.bytes);"
    , "}" ]
  take' kind =
    let fields = zip [0 :: Int ..] (fieldsOf layouts kind)
        local index = "v" <> textOfInt index
        named = any (needsName . snd . snd) fields
     in [ "static pudu_box *pudu_export_take_" <> suffix kind <> "(const char *name, " <> recordName kind <> " value) {"
        , "  pudu_box *made;" ]
        <> [ "  (void)name;" | not named ]
        <> [ "  " <> cType field <> " " <> local index <> " = " <> takeCell field "name" ("value." <> memberName fieldName) <> ";"
           | (index, (fieldName, field)) <- fields ]
        <> [ "  made = " <> aggregateHelper "make" kind <> "(" <> Text.intercalate ", " [local index | (index, _) <- fields] <> ");" ]
        -- The constructor retained each member; these references are ours.
        <> [ "  " <> released field (local index) | (index, (_, field)) <- fields, released field "" /= "" ]
        <> [ "  return made;", "}" ]
  give kind =
    [ "static " <> recordName kind <> " pudu_export_give_" <> suffix kind <> "(pudu_box *box) {"
    , "  " <> recordName kind <> " value;" ]
    <> [ "  value." <> memberName fieldName <> " = " <> giveValue field ("box->fields[" <> textOfInt index <> "]." <> cellName field) <> ";"
       | (index, (fieldName, field)) <- zip [0 :: Int ..] (fieldsOf layouts kind) ]
    <> [ "  return value;", "}" ]
  needsName field = field == CoreTextType || isRecord field

{-| A cell for a host value, owned by the caller of the conversion. `name`
    is the C expression naming the export, for a misuse message. -}
takeCell :: CoreType -> Text -> Text -> Text
takeCell kind name value = case kind of
  CoreTextType -> "pudu_export_text_in(" <> name <> ", " <> value <> ")"
  CoreRecordType _ _ -> "pudu_export_take_" <> suffix kind <> "(" <> name <> ", " <> value <> ")"
  _ -> fromAbi kind value

{-| The host value of a cell; the cell keeps its own reference. -}
giveValue :: CoreType -> Text -> Text
giveValue kind cell = case kind of
  CoreTextType -> "pudu_export_text_out(" <> cell <> ")"
  CoreRecordType _ _ -> "pudu_export_give_" <> suffix kind <> "(" <> cell <> ")"
  _ -> toAbi kind cell

{-| The runtime parts and aggregate helpers the conversions select. -}
crossingNeeds :: Layouts -> [CoreType] -> [CoreType] -> [Text]
crossingNeeds layouts inbound outbound =
  concat [["text_copy", "utf8_valid"] | reaches layouts CoreTextType inbound]
    <> concat [["memory_failure"] | reaches layouts CoreTextType outbound]
    <> concat [[aggregateNeed "make" kind, aggregateNeed "drop" kind] | kind <- recordsIn layouts inbound]

fieldsOf :: Layouts -> CoreType -> [(Text, CoreType)]
fieldsOf layouts kind = case Map.lookup kind layouts of
  Just (CoreRecordLayout fields) -> fields
  _ -> []

-- Whether a type is among the roots or a field of a record they reach.
reaches :: Layouts -> CoreType -> [CoreType] -> Bool
reaches layouts wanted roots =
  wanted `elem` roots || any ((== wanted) . snd) (concatMap (fieldsOf layouts) (recordsIn layouts roots))

isRecord :: CoreType -> Bool
isRecord CoreRecordType {} = True
isRecord _ = False

recordName :: CoreType -> Text
recordName kind = "pudu_" <> suffix kind

suffix :: CoreType -> Text
suffix kind = case kind of
  CoreRecordType name arguments -> mangle (Text.takeWhileEnd (/= '.') name) <> foldMap (("_" <>) . mangle . coreTypeName) arguments
  _ -> mangle (coreTypeName kind)

memberName :: Text -> Text
memberName name
  | Set.member name cKeywords = name <> "_"
  | otherwise = mangle name
