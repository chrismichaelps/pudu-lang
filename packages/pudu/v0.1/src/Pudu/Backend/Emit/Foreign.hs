{-| @Backend.Emit.Foreign — one typed wrapper per foreign declaration a
    program calls, and the call through it. A wrapper converts each frame cell
    to the C type the declaration crosses as, calls through a function pointer
    of that exact type, and converts the answer back. -}
module Pudu.Backend.Emit.Foreign (foreignCall, foreignWrappers, foreignNeeds, foreignsOf) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (cType)
import Pudu.Backend.Emit.ForeignAbi (Layouts, abiType, fromAbi, mangle, recordDefinitions, recordNeeds, recordsIn, textLeaves, toAbi)
import Pudu.Backend.Emit.State (EmitState, cString, helpedFailureSite, textFailureSite, textOfInt)
import Pudu.Core (CoreForeign (..), CoreLayout (..), CoreType (..), coreTypeName)
import Pudu.Core.Frame
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| The call text at one site and the parts it needs. A failure to open the
    library or find the symbol stops at this site with E7015; text that cannot
    cross stops with E7017 before the call, and a text result that is missing
    or not UTF-8 stops with E7024 or E7025 after it, each in the interpreter's
    words. A text field of a record result names its field when it is missing. -}
foreignCall :: EmitState -> Span -> CoreForeign -> [Text] -> (EmitState, Text, [Text])
foreignCall state at declared cells =
  let (s1, site) = textFailureSite state at "E7015" (Just help)
      (s2, noughts) = if lendsText then fmap Just (helpedFailureSite s1 at "E7017" noughtMessage noughtHelp) else (s1, Nothing)
      (s3, missing) = case result of
        CoreTextType -> fmap Just (helpedFailureSite s2 at "E7024" (symbol <> " returned no text for result") missingHelp)
        CoreRecordType _ _ -> fmap Just (textFailureSite s2 at "E7024" (Just missingHelp))
        _ -> (s2, Nothing)
      (s4, invalid) = if answersText then fmap Just (helpedFailureSite s3 at "E7025" (symbol <> " returned text that is not valid UTF-8") invalidHelp) else (s3, Nothing)
      sites = [siteText site] <> map siteText (maybe [] pure noughts <> maybe [] pure missing <> maybe [] pure invalid)
   in ( s4
      , wrapperName declared <> "(" <> Text.intercalate ", " (sites <> cells) <> ")"
      , ["host_foreign"] )
 where
  result = coreForeignResult declared
  symbol = coreForeignSymbol declared
  lendsText = any carriesText (coreForeignParameters declared)
  answersText = carriesText result
  carriesText kind = case kind of
    CoreTextType -> True
    CoreRecordType _ _ -> True
    _ -> False
  siteText index = "&pudu_sites[" <> textOfInt index <> "]"
  help = "a foreign declaration names a library the platform must already have; "
    <> "install it, or check the name and the symbol against what it exports"
  noughtMessage = "text carrying a nought cannot cross a foreign boundary"
  noughtHelp = "the other side reads until the first nought, so it would see less than this text says"
  missingHelp = "a declared Str must name valid UTF-8 text"
  invalidHelp = "fix the native binding or declare a byte-oriented result instead of Str"

{-| Every foreign declaration a module's frames call, each once. -}
foreignsOf :: FrameModule -> [CoreForeign]
foreignsOf source = Set.toList $ Set.fromList
  [ declared
  | function <- frameModuleFunctions source
  , block <- frameFunctionBlocks function
  , FrameStore _ value <- frameBlockInstructions block
  , FrameForeign declared _ <- [frameValueShape value] ]

{-| The parts and aggregate helpers the wrappers of these declarations use:
    each leaf's conversion, the text helpers, and the constructors and
    releases of every record crossed, whose pack and unpack functions are
    both written. -}
foreignNeeds :: Layouts -> [CoreForeign] -> [Text]
foreignNeeds layouts declarations = concat
  [ concatMap parameterNeeds (concatMap leaves (coreForeignParameters declared))
      <> concatMap resultNeeds (leaves (coreForeignResult declared))
      <> concat ["host_optional" : concatMap parameterNeeds (leaves kind) <> concatMap resultNeeds (leaves kind) <> recordNeeds layouts kind
                | kind@(CoreRecordType _ _) <- coreForeignResult declared : coreForeignParameters declared]
  | declared <- declarations ]
 where
  leaves kind = case Map.lookup kind layouts of
    Just (CoreRecordLayout fields) | CoreRecordType _ _ <- kind -> concatMap (leaves . snd) fields
    _ -> [kind]

{-| The record structs the declarations cross, then their wrappers. Text
    arguments, direct or in record fields, are copied with a closing nought
    for the call and released after it; a text result is copied out of the
    library's storage first, since it may point into an argument (as `strchr`
    does), and the library keeps that storage. -}
foreignWrappers :: Layouts -> [CoreForeign] -> [Text]
foreignWrappers layouts declarations =
  recordDefinitions layouts (recordsIn layouts (concat [coreForeignResult declared : coreForeignParameters declared | declared <- declarations]))
    <> concatMap wrapper declarations
 where
  wrapper declared =
    let parameters = zip [0 :: Int ..] (coreForeignParameters declared)
        result = coreForeignResult declared
        held = sum [textLeaves layouts kind | (_, kind@(CoreRecordType _ _)) <- parameters]
        lendsText = any (carriesText . snd) parameters
        abiParameters = if null parameters then "void" else Text.intercalate ", " [abiType kind | (_, kind) <- parameters]
        pointer = abiType result <> " (*)(" <> abiParameters <> ")"
        resolved = "((" <> pointer <> ")pudu_foreign_function(site, &cache, " <> cString (coreForeignLibrary declared) <> ", "
          <> maybe "NULL" cString (coreForeignVersion declared) <> ", " <> cString (coreForeignSymbol declared) <> "))"
        argument index kind = case kind of
          CoreTextType -> "t" <> textOfInt index
          CoreRecordType _ _ -> "r" <> textOfInt index
          _ -> toAbi kind ("a" <> textOfInt index)
        call = "function(" <> Text.intercalate ", " [argument index kind | (index, kind) <- parameters] <> ")"
        siteParameters = ["const pudu_site *site"] <> ["const pudu_site *noughts" | lendsText]
          <> concat [["const pudu_site *missing", "const pudu_site *invalid"] | carriesText result]
        heldLines = if held == 0 then [] else ["  char *held[" <> textOfInt held <> "];", "  size_t held_count = 0;"]
        copies = concat
          [ case kind of
              CoreTextType -> ["  char *t" <> textOfInt index <> " = pudu_foreign_text_in(noughts, a" <> textOfInt index <> ");"]
              CoreRecordType _ _ -> ["  " <> abiType kind <> " r" <> textOfInt index <> " = pudu_foreign_pack_" <> suffix kind
                <> "(" <> (if lendsText then "noughts" else "NULL") <> ", a" <> textOfInt index <> ", " <> (if held == 0 then "NULL, NULL" else "held, &held_count") <> ");"]
              _ -> []
          | (index, kind) <- parameters ]
        releases = ["  free(t" <> textOfInt index <> ");" | (index, CoreTextType) <- parameters]
          <> ["  for (size_t i = 0; i < held_count; ++i) free(held[i]);" | held /= 0]
        body = case result of
          CoreUnitType -> ["  " <> call <> ";"] <> releases <> ["  return 0;"]
          CoreTextType -> ["  pudu_text answer = pudu_foreign_text_out(missing, invalid, " <> call <> ");"] <> releases <> ["  return answer;"]
          CoreRecordType _ _ -> [ "  pudu_box *answer = pudu_foreign_unpack_" <> suffix result <> "(missing, invalid, "
            <> cString (coreForeignSymbol declared) <> ", " <> call <> ");"] <> releases <> ["  return answer;"]
          _ -> ["  " <> abiType result <> " answer = " <> call <> ";"] <> releases <> ["  return " <> fromAbi result "answer" <> ";"]
     in [ "static " <> cellType result <> " " <> wrapperName declared <> "("
            <> Text.intercalate ", " (siteParameters <> [cType kind <> " a" <> textOfInt index | (index, kind) <- parameters]) <> ") {"
        , "  static pudu_foreign_cache cache = {NULL};" ]
        <> heldLines
        <> copies
        <> ["  " <> abiType result <> " (*function)(" <> abiParameters <> ") = " <> resolved <> ";"]
        <> body
        <> ["}", ""]
  cellType kind = if kind == CoreUnitType then "int" else cType kind
  carriesText kind = case kind of
    CoreTextType -> True
    CoreRecordType _ _ -> True
    _ -> False
  suffix kind = Text.drop (Text.length "pudu_foreign_record_") (abiType kind)

{-| A name that is a C identifier and differs for every declaration. -}
wrapperName :: CoreForeign -> Text
wrapperName declared = "pudu_foreign_" <> mangle key
 where
  key = Text.intercalate "|" ([coreForeignLibrary declared, maybe "" id (coreForeignVersion declared), coreForeignSymbol declared]
    <> map coreTypeName (coreForeignParameters declared) <> [coreTypeName (coreForeignResult declared)])

{-| The parts converting a cell to the C type it crosses as. -}
parameterNeeds :: CoreType -> [Text]
parameterNeeds kind = case kind of
  CoreIntegerType (SignedKind _) -> ["kernel_signed"]
  CoreFloatType _ -> ["float_decode"]
  CoreTextType -> ["host_foreign_text"]
  CoreBytesType -> ["host_foreign_bytes"]
  _ -> []

{-| The parts converting an answer back to its cell. -}
resultNeeds :: CoreType -> [Text]
resultNeeds kind = case kind of
  CoreIntegerType (SignedKind _) -> ["kernel_int"]
  CoreIntegerType _ -> ["make"]
  CoreFloatType _ -> ["float_encode"]
  CoreTextType -> ["host_foreign_text"]
  _ -> []
