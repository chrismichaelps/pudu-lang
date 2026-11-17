{-| @Backend.Emit.Foreign.Loan — preserves ABI scratch across protected
    crossings and returns mutable snapshots for caller writeback. -}
module Pudu.Backend.Emit.Foreign.Loan
  ( byValueInputs
  , extentChecks
  , foreignCallName
  , foreignCellType
  , hasMutableInputs
  , hasLiveRunInputs
  , hasRunInputs
  , inputParameter
  , loanPointer
  , loanResult
  , loanWrapper
  , mutableInputs
  , needsLoanProtection
  , pointeeType
  , unpackNativeRun
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (aggregateHelper, cType, cellName, released)
import Pudu.Backend.Emit.ForeignAbi (abiType, fromAbi, toAbi)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreForeign (..), CoreType (..))
import Pudu.Foreign.Extent (ExtentUnit (..), ForeignBound (..))
import Pudu.IntegerLiteral (IntegerKind (SignedKind))

loanWrapper :: Text -> CoreForeign -> [Text] -> [Text]
loanWrapper wrapper declared sites
  | null (coreForeignLoans declared) = []
  | otherwise =
      let siteNames = map (Text.takeWhileEnd (\c -> c /= ' ' && c /= '*')) sites
          inputNames =
            [ inputName index kind | (index, kind) <- parameters ]
          invoke = wrapper <> "(" <> Text.intercalate ", " (siteNames <> inputNames) <> ")"
          outerSites = sites <> ["const pudu_site *extent"
            | hasRunInputs declared, hasLiveRunInputs declared || not (null (coreForeignBounds declared))]
          prototype = Text.intercalate ", " (outerSites <> [cType kind <> " " <> argument index | (index, kind) <- parameters])
       in protected siteNames <> [ "static " <> foreignCellType (loanResult declared) <> " " <> foreignCallName wrapper declared
              <> "(" <> prototype <> ") {" ]
          <> ["  (void)" <> argument index <> ";" | index <- coreForeignAbsentLoans declared]
          <> concatMap sizeRun runs
          <> [line | hasRunInputs declared, line <- extentChecks declared]
          <> concatMap copyInput loans
          <> returned invoke (Text.intercalate ", " (siteNames <> inputNames)) <> ["}", ""]
 where
  parameters = zip [0 ..] (coreForeignParameters declared)
  loans = [(index, kind) | (index, kind) <- parameters, Just _ <- [lookup index (coreForeignLoans declared)]
                         , index `notElem` coreForeignAbsentLoans declared]
  finals = mutableInputs declared
  runs = [(index, element) | (index, CoreArrayType element) <- loans]
  result = coreForeignResult declared
  protectedName = foreignCallName wrapper declared <> "_protected"
  argument index = "a" <> textOfInt index
  scratch index = "loan" <> textOfInt index
  final index = "final" <> textOfInt index
  inputName index kind
    | index `elem` coreForeignAbsentLoans declared = "NULL"
    | otherwise = case (lookup index (coreForeignLoans declared), kind) of
        (Nothing, _) -> argument index
        (_, CoreArrayType _) -> scratch index
        _ -> "&" <> scratch index
  sizeRun (index, element) =
    [ "  size_t " <> runCount index <> " = pudu_array_length(" <> argument index <> ");"
    , "  if (" <> runCount index <> " > (size_t)PTRDIFF_MAX / sizeof(" <> abiType element <> ")) pudu_fail(extent);" ]
  copyInput (index, CoreArrayType element) =
    [ "  " <> abiType element <> " *" <> scratch index <> " = pudu_foreign_allocate_run("
        <> runCount index <> " * sizeof(" <> abiType element <> "));"
    , "  for (size_t i = 0; i < " <> runCount index <> "; ++i)"
    , "    " <> scratch index <> "[i] = " <> pack element (item element (argument index)) <> ";" ]
  copyInput (index, kind) =
    [ "  " <> abiType kind <> " " <> scratch index <> " = " <> pack kind (argument index) <> ";" ]
  item element array = array <> "->fields[0].items->cells[i]." <> cellName element
  pack kind source = case kind of
    CoreRecordType _ _ -> "pudu_foreign_pack_" <> recordSuffix kind <> "(" <> source <> ", NULL, NULL)"
    _ -> toAbi kind source
  copyFinal (index, CoreArrayType element) =
    unpackNativeRun element (scratch index) (runCount index) (final index)
  copyFinal (index, kind) =
    [ "  " <> cType kind <> " " <> final index <> " = " <> unpackPointee kind (scratch index) <> ";" ]
  freeRuns = ["  free(" <> scratch index <> ");" | (index, _) <- runs]
  protected siteNames
    | not (needsLoanProtection declared) = []
    | otherwise =
        let inputs = [inputParameter declared index kind | (index, kind) <- parameters]
            signature = Text.intercalate ", " (["pudu_foreign_loan *loan"] <> sites <> inputs <> [foreignCellType result <> " *out"])
            names = Text.intercalate ", " (["loan"] <> siteNames <> map (argument . fst) parameters)
         in [ "static void " <> protectedName <> "(" <> signature <> ") {"
              , "  if (setjmp(loan->escape) == 0) {" ]
              <> ["    pudu_foreign_loan_arm(loan);" | not (null runs)]
              <> [ "    *out = " <> wrapper <> "(" <> names <> ");"
              , "  }"
            , "  pudu_foreign_loan_disarm();"
            , "}", "" ]
  returned invoke given
    | not (needsLoanProtection declared) = ["  return " <> invoke <> ";"]
    | otherwise =
        [ "  pudu_foreign_loan loan = {0};"
        , "  " <> foreignCellType result <> " answer = {0};"
        , "  " <> protectedName <> "(&loan, " <> given <> ", &answer);" ]
        <> (if null finals
              then freeRuns <> ["  (void)pudu_foreign_loan_settle();", "  return answer;"]
              else preflight <> concatMap copyFinal finals <> freeRuns <> tuple)
  preflight
    | null runs = []
    | otherwise = ["  if (!loan.dispatched) {"] <> map ("  " <>) freeRuns
        <> ["    (void)pudu_foreign_loan_settle();", "    return NULL;", "  }"]
  tuple =
        [ "  pudu_box *tuple = " <> aggregateHelper "make" (loanResult declared)
              <> "(" <> Text.intercalate ", " ("answer" : map (final . fst) finals) <> ");" ]
        <> [ "  " <> dropValue | (kind, name) <- (result, "answer") : [(kind, final index) | (index, kind) <- finals]
           , let dropValue = released kind name, not (Text.null dropValue) ]
        <> ["  return tuple;"]

foreignCallName :: Text -> CoreForeign -> Text
foreignCallName wrapper declared = wrapper <> (if null (coreForeignLoans declared) then "" else "_loan")

byValueInputs :: CoreForeign -> [(Int, CoreType)]
byValueInputs declared =
  [entry | entry@(index, _) <- zip [0 ..] (coreForeignParameters declared), lookup index (coreForeignLoans declared) == Nothing]

mutableInputs :: CoreForeign -> [(Int, CoreType)]
mutableInputs declared =
  [ entry | entry@(index, _) <- zip [0 ..] (coreForeignParameters declared)
          , lookup index (coreForeignLoans declared) == Just True
          , index `notElem` coreForeignAbsentLoans declared ]

hasMutableInputs :: CoreForeign -> Bool
hasMutableInputs = not . null . mutableInputs

hasRunInputs :: CoreForeign -> Bool
hasRunInputs = any isArray . coreForeignParameters
 where
  isArray CoreArrayType{} = True
  isArray _ = False

needsLoanProtection :: CoreForeign -> Bool
needsLoanProtection declared = hasMutableInputs declared || hasLiveRunInputs declared

hasLiveRunInputs :: CoreForeign -> Bool
hasLiveRunInputs declared = or
  [ index `notElem` coreForeignAbsentLoans declared
  | (index, CoreArrayType _) <- zip [0 ..] (coreForeignParameters declared) ]

loanResult :: CoreForeign -> CoreType
loanResult declared = case mutableInputs declared of
  [] -> coreForeignResult declared
  finals -> CoreTupleType (coreForeignResult declared : map snd finals)

loanPointer :: Bool -> CoreType -> Text
loanPointer exclusive kind = (if exclusive then "" else "const ") <> abiType (pointeeType kind) <> " *"

pointeeType :: CoreType -> CoreType
pointeeType (CoreArrayType element) = element
pointeeType kind = kind

runCount :: Int -> Text
runCount index = "n" <> textOfInt index

extentChecks :: CoreForeign -> [Text]
extentChecks declared =
  [ "  pudu_foreign_check_extent(extent, " <> negative kind value <> ", (uint64_t)(" <> value
      <> "), " <> capacity (boundUnit bound) target capacityKind <> ");"
  | bound <- coreForeignBounds declared
  , Just kind <- [lookup (boundLength bound) parameters]
  , let value = toAbi kind ("a" <> textOfInt (boundLength bound))
  , target <- foldr (:) [] (boundTargets bound)
  , Just capacityKind <- [lookup target parameters] ]
 where
  parameters = zip [0 ..] (coreForeignParameters declared)
  negative (CoreIntegerType (SignedKind _)) value = "(" <> value <> ") < 0"
  negative _ _ = "0"
  capacity _ index _ | index `elem` coreForeignAbsentLoans declared = "0"
  capacity unit index (CoreArrayType element) = case unit of
    ExtentElements -> runCount index
    ExtentBytes -> runCount index <> " * sizeof(" <> abiType element <> ")"
  capacity _ index _ = "a" <> textOfInt index <> "->fields[0].text.length"

inputParameter :: CoreForeign -> Int -> CoreType -> Text
inputParameter declared index kind =
  maybe (cType kind) (\exclusive -> loanPointer exclusive kind) (lookup index (coreForeignLoans declared))
    <> " a" <> textOfInt index

foreignCellType :: CoreType -> Text
foreignCellType CoreUnitType = "int"
foreignCellType kind = cType kind

recordSuffix :: CoreType -> Text
recordSuffix = Text.drop (Text.length "pudu_foreign_record_") . abiType

unpackPointee :: CoreType -> Text -> Text
unpackPointee kind source = case kind of
  CoreRecordType _ _ -> "pudu_foreign_unpack_" <> recordSuffix kind <> "(" <> source <> ")"
  _ -> fromAbi kind source

unpackNativeRun :: CoreType -> Text -> Text -> Text -> [Text]
unpackNativeRun element buffer count target =
  [ "  pudu_box *" <> target <> " = pudu_array_new(" <> count <> ");"
  , "  for (size_t i = 0; i < " <> count <> "; ++i)"
  , "    " <> target <> "->fields[0].items->cells[i]." <> cellName element
      <> " = " <> unpackPointee element (buffer <> "[i]") <> ";"
  , "  pudu_array_length(" <> target <> ") = " <> count <> ";" ]
