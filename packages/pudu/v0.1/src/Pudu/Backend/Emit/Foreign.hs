{-| @Backend.Emit.Foreign — one typed wrapper per foreign declaration a
    program calls, and the call through it. A wrapper converts each frame cell
    to the C type the declaration crosses as, calls through a function pointer
    of that exact type, and converts the answer back. -}
module Pudu.Backend.Emit.Foreign (foreignCall, foreignWrappers, foreignsOf) where

import Data.Char (isAsciiLower, isAsciiUpper, isDigit, ord)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import Pudu.Backend.Emit.Cell (cType)
import Pudu.Backend.Emit.State (EmitState, cString, helpedFailureSite, textFailureSite, textOfInt)
import Pudu.Core (CoreForeign (..), CoreType (..), coreTypeName)
import Pudu.Core.Frame
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| The call text at one site and the parts it needs. A failure to open the
    library or find the symbol stops at this site with E7015; text that cannot
    cross stops with E7017 before the call, and a text result that is missing
    or not UTF-8 stops with E7024 or E7025 after it, each in the interpreter's
    words. -}
foreignCall :: EmitState -> Span -> CoreForeign -> [Text] -> (EmitState, Text, [Text])
foreignCall state at declared cells =
  let (s1, site) = textFailureSite state at "E7015" (Just help)
      (s2, noughts) = if hasText then fmap Just (helpedFailureSite s1 at "E7017" noughtMessage noughtHelp) else (s1, Nothing)
      (s3, missing) = if textResult then fmap Just (helpedFailureSite s2 at "E7024" (symbol <> " returned no text for result") missingHelp) else (s2, Nothing)
      (s4, invalid) = if textResult then fmap Just (helpedFailureSite s3 at "E7025" (symbol <> " returned text that is not valid UTF-8") invalidHelp) else (s3, Nothing)
      sites = [siteText site] <> map siteText (maybe [] pure noughts <> maybe [] pure missing <> maybe [] pure invalid)
   in ( s4
      , wrapperName declared <> "(" <> Text.intercalate ", " (sites <> cells) <> ")"
      , "host_foreign" : resultNeeds (coreForeignResult declared) <> concatMap parameterNeeds (coreForeignParameters declared) )
 where
  symbol = coreForeignSymbol declared
  hasText = CoreTextType `elem` coreForeignParameters declared
  textResult = coreForeignResult declared == CoreTextType
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

{-| The wrapper definitions, one per declaration. Text arguments are copied
    with a closing nought for the call and released after it; a text result
    is copied out of the library's storage first, since it may point into an
    argument (as `strchr` does), and the library keeps that storage. -}
foreignWrappers :: [CoreForeign] -> [Text]
foreignWrappers = concatMap wrapper
 where
  wrapper declared =
    let parameters = zip [0 :: Int ..] (coreForeignParameters declared)
        result = coreForeignResult declared
        texts = [index | (index, CoreTextType) <- parameters]
        abiParameters = if null parameters then "void" else Text.intercalate ", " [abiType kind | (_, kind) <- parameters]
        pointer = abiType result <> " (*)(" <> abiParameters <> ")"
        resolved = "((" <> pointer <> ")pudu_foreign_function(site, &cache, " <> cString (coreForeignLibrary declared) <> ", "
          <> maybe "NULL" cString (coreForeignVersion declared) <> ", " <> cString (coreForeignSymbol declared) <> "))"
        argument index kind = case kind of
          CoreTextType -> "t" <> textOfInt index
          _ -> toAbi kind ("a" <> textOfInt index)
        call = "function(" <> Text.intercalate ", " [argument index kind | (index, kind) <- parameters] <> ")"
        siteParameters = ["const pudu_site *site"] <> ["const pudu_site *noughts" | not (null texts)]
          <> concat [["const pudu_site *missing", "const pudu_site *invalid"] | result == CoreTextType]
        copies = ["  char *t" <> textOfInt index <> " = pudu_foreign_text_in(noughts, a" <> textOfInt index <> ");" | index <- texts]
        releases = ["  free(t" <> textOfInt index <> ");" | index <- texts]
        body = case result of
          CoreUnitType -> ["  " <> call <> ";"] <> releases <> ["  return 0;"]
          CoreTextType -> ["  pudu_text answer = pudu_foreign_text_out(missing, invalid, " <> call <> ");"] <> releases <> ["  return answer;"]
          _ -> ["  " <> abiType result <> " answer = " <> call <> ";"] <> releases <> ["  return " <> fromAbi result "answer" <> ";"]
     in [ "static " <> cellType result <> " " <> wrapperName declared <> "("
            <> Text.intercalate ", " (siteParameters <> [cType kind <> " a" <> textOfInt index | (index, kind) <- parameters]) <> ") {"
        , "  static pudu_foreign_cache cache = {NULL};" ]
        <> copies
        <> ["  " <> pointer' result abiParameters <> " = " <> resolved <> ";"]
        <> body
        <> ["}", ""]
  cellType kind = if kind == CoreUnitType then "int" else cType kind
  pointer' result abiParameters = abiType result <> " (*function)(" <> abiParameters <> ")"

{-| A name that is a C identifier and differs for every declaration. -}
wrapperName :: CoreForeign -> Text
wrapperName declared = "pudu_foreign_" <> Text.concatMap escape key
 where
  key = Text.intercalate "|" ([coreForeignLibrary declared, maybe "" id (coreForeignVersion declared), coreForeignSymbol declared]
    <> map coreTypeName (coreForeignParameters declared) <> [coreTypeName (coreForeignResult declared)])
  escape c
    | isAsciiLower c || isAsciiUpper c || isDigit c = Text.singleton c
    | otherwise = Text.pack ("_" <> pad (showHex (ord c) ""))
  pad digits = replicate (2 - length digits) '0' <> digits

{-| The C type a crossing type has at the boundary, as the interpreter's bridge hands it over. -}
abiType :: CoreType -> Text
abiType kind = case kind of
  CoreIntegerType (SignedKind width) -> "int" <> textOfInt width <> "_t"
  CoreIntegerType (UnsignedKind width) -> "uint" <> textOfInt width <> "_t"
  CoreFloatType Float32Width -> "float"
  CoreFloatType _ -> "double"
  CoreBoolType -> "uint8_t"
  CoreTextType -> "const char *"
  CoreBytesType -> "const void *"
  _ -> "void"

toAbi :: CoreType -> Text -> Text
toAbi kind cell = case kind of
  CoreIntegerType (SignedKind _) -> "(" <> abiType kind <> ")pudu_kernel_signed(" <> cell <> ".bits)"
  CoreIntegerType _ -> "(" <> abiType kind <> ")" <> cell <> ".bits"
  CoreFloatType Float32Width -> "(float)pudu_float_decode(" <> cell <> ")"
  CoreFloatType _ -> "pudu_float_decode(" <> cell <> ")"
  CoreBoolType -> "(uint8_t)(" <> cell <> " != 0)"
  CoreBytesType -> "pudu_foreign_bytes_in(" <> cell <> ")"
  _ -> cell

fromAbi :: CoreType -> Text -> Text
fromAbi kind value = case kind of
  CoreIntegerType (SignedKind _) -> "pudu_kernel_int((int64_t)" <> value <> ")"
  CoreIntegerType _ -> "pudu_make((uint64_t)" <> value <> ", 0)"
  CoreFloatType _ -> "pudu_float_encode((double)" <> value <> ")"
  CoreBoolType -> "(" <> value <> " != 0)"
  _ -> value

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
