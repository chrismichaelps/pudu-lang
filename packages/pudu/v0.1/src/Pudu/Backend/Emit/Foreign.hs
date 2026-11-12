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
import Pudu.Backend.Emit.State (EmitState, cString, textFailureSite, textOfInt)
import Pudu.Core (CoreForeign (..), CoreType (..), coreTypeName)
import Pudu.Core.Frame
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| The call text at one site and the parts it needs. A failure to open the
    library or find the symbol stops at this site with E7015. -}
foreignCall :: EmitState -> Span -> CoreForeign -> [Text] -> (EmitState, Text, [Text])
foreignCall state at declared cells =
  let (after, site) = textFailureSite state at "E7015" (Just help)
   in ( after
      , wrapperName declared <> "(" <> Text.intercalate ", " (("&pudu_sites[" <> textOfInt site <> "]") : cells) <> ")"
      , "host_foreign" : concatMap conversionNeeds (coreForeignResult declared : coreForeignParameters declared) )
 where
  help = "a foreign declaration names a library the platform must already have; "
    <> "install it, or check the name and the symbol against what it exports"

{-| Every foreign declaration a module's frames call, each once. -}
foreignsOf :: FrameModule -> [CoreForeign]
foreignsOf source = Set.toList $ Set.fromList
  [ declared
  | function <- frameModuleFunctions source
  , block <- frameFunctionBlocks function
  , FrameStore _ value <- frameBlockInstructions block
  , FrameForeign declared _ <- [frameValueShape value] ]

{-| The wrapper definitions, one per declaration. -}
foreignWrappers :: [CoreForeign] -> [Text]
foreignWrappers = concatMap wrapper
 where
  wrapper declared =
    let parameters = zip [0 :: Int ..] (coreForeignParameters declared)
        result = coreForeignResult declared
        abiParameters = if null parameters then "void" else Text.intercalate ", " [abiType kind | (_, kind) <- parameters]
        pointer = abiType result <> " (*)(" <> abiParameters <> ")"
        call = "((" <> pointer <> ")pudu_foreign_function(site, &cache, " <> cString (coreForeignLibrary declared) <> ", "
          <> maybe "NULL" cString (coreForeignVersion declared) <> ", " <> cString (coreForeignSymbol declared) <> "))("
          <> Text.intercalate ", " [toAbi kind ("a" <> textOfInt index) | (index, kind) <- parameters] <> ")"
     in [ "static " <> cellType result <> " " <> wrapperName declared <> "(const pudu_site *site"
            <> Text.concat [", " <> cType kind <> " a" <> textOfInt index | (index, kind) <- parameters] <> ") {"
        , "  static pudu_foreign_cache cache = {NULL};" ]
        <> (if result == CoreUnitType
              then ["  " <> call <> ";", "  return 0;"]
              else ["  return " <> fromAbi result call <> ";"])
        <> ["}", ""]
  cellType kind = if kind == CoreUnitType then "int" else cType kind

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
  _ -> "void"

toAbi :: CoreType -> Text -> Text
toAbi kind cell = case kind of
  CoreIntegerType (SignedKind _) -> "(" <> abiType kind <> ")pudu_kernel_signed(" <> cell <> ".bits)"
  CoreIntegerType _ -> "(" <> abiType kind <> ")" <> cell <> ".bits"
  CoreFloatType Float32Width -> "(float)pudu_float_decode(" <> cell <> ")"
  CoreFloatType _ -> "pudu_float_decode(" <> cell <> ")"
  CoreBoolType -> "(uint8_t)(" <> cell <> " != 0)"
  _ -> cell

fromAbi :: CoreType -> Text -> Text
fromAbi kind value = case kind of
  CoreIntegerType (SignedKind _) -> "pudu_kernel_int((int64_t)" <> value <> ")"
  CoreIntegerType _ -> "pudu_make((uint64_t)" <> value <> ", 0)"
  CoreFloatType _ -> "pudu_float_encode((double)" <> value <> ")"
  CoreBoolType -> "(" <> value <> " != 0)"
  _ -> value

conversionNeeds :: CoreType -> [Text]
conversionNeeds kind = case kind of
  CoreIntegerType (SignedKind _) -> ["kernel_signed", "kernel_int"]
  CoreIntegerType _ -> ["make"]
  CoreFloatType _ -> ["float_decode", "float_encode"]
  _ -> []
