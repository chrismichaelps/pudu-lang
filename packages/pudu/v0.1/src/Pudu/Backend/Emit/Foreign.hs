{-| @Backend.Emit.Foreign — one typed wrapper per foreign declaration a
    program calls, and the call through it. A wrapper converts each frame cell
    to the C type the declaration crosses as, calls through a function pointer
    of that exact type, and converts the answer back. -}
module Pudu.Backend.Emit.Foreign (foreignCall, foreignWrappers, foreignNeeds, foreignsOf) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed, cType, released)
import Pudu.Backend.Emit.ForeignAbi (Layouts, abiType, fromAbi, mangle, recordDefinitions, recordNeeds, recordsIn, textLeaves, toAbi)
import Pudu.Backend.Emit.State (EmitState, cString, helpedFailureSite, textFailureSite, textOfInt)
import Pudu.Core (CoreClaim (..), CoreForeign (..), CoreLayout (..), CoreType (..))
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
        _ | answersText -> fmap Just (textFailureSite s2 at "E7024" (Just missingHelp))
        _ -> (s2, Nothing)
      (s4, invalid) = if answersText then fmap Just (helpedFailureSite s3 at "E7025" (symbol <> " returned text that is not valid UTF-8") invalidHelp) else (s3, Nothing)
      (s5, dead) = case [name | CoreHandleType _ name <- coreForeignParameters declared] of
        name : _ -> fmap Just (helpedFailureSite s4 at "E7022"
          ("the " <> name <> " passed to " <> symbol <> " is no longer owned") deadHelp)
        [] -> (s4, Nothing)
      (s6, none) = case nativeResult of
        CoreHandleType _ name -> fmap Just (helpedFailureSite s5 at "E7020" (symbol <> " returned a null " <> name) (if hasSlots then "an owned foreign result must name a live object" else noneHelp))
        _ -> (s5, Nothing)
      (s7, owned) = case (result, coreForeignClaim declared) of
        (CoreHandleType _ name, Just (CoreOwned False _ _)) -> fmap Just (helpedFailureSite s6 at "E7021" (symbol <> " returned a " <> name <> " already owned") ownedHelp)
        _ | hasSlots, not (null (slotReleases declared)) || releaseOf declared /= Nothing -> fmap Just (helpedFailureSite s6 at "E7021"
          (symbol <> " handed back duplicate or already owned resources") "an owned foreign value must transfer one new ownership claim")
        _ -> (s6, Nothing)
      sites = [siteText site] <> map siteText (concatMap (maybe [] pure) [noughts, missing, invalid, dead, none, owned])
   in ( s7
      , wrapperName declared <> "(" <> Text.intercalate ", " (sites <> cells) <> ")"
      , ["host_foreign"] )
 where
  result = coreForeignResult declared
  nativeResult = maybe result fst (slotResult declared)
  hasSlots = not (null (coreForeignSlotPositions declared))
  symbol = coreForeignSymbol declared
  lendsText = any carriesText (coreForeignParameters declared)
  answersText = any carriesText (case slotResult declared of
    Just (native, slots) -> native : map slotAbiType slots
    Nothing -> [result])
  siteText index = "&pudu_sites[" <> textOfInt index <> "]"
  help = "a foreign declaration names a library the platform must already have; "
    <> "install it, or check the name and the symbol against what it exports"
  noughtMessage = "text carrying a nought cannot cross a foreign boundary"
  noughtHelp = "the other side reads until the first nought, so it would see less than this text says"
  missingHelp = "a declared Str must name valid UTF-8 text"
  invalidHelp = "fix the native binding or declare a byte-oriented result instead of Str"
  deadHelp = "a foreign handle cannot be used or released after its release function has run"
  noneHelp = "a foreign handle result must name a live object"
  ownedHelp = "an owned foreign result must transfer one new ownership claim"

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
      <> (case slotResult declared of
        Just (native, slots) -> aggregateNeed "make" (coreForeignResult declared) : concatMap resultNeeds (concatMap leaves (native : map slotAbiType slots)) <> concatMap optionNeeds slots
        Nothing -> [])
      <> concat ["host_optional" : concatMap parameterNeeds (leaves kind) <> concatMap resultNeeds (leaves kind) <> recordNeeds layouts kind
                | kind@(CoreRecordType _ _) <- crossingTypes declared]
  | declared <- declarations ]
 where
  optionNeeds kind@(CoreSumType "Option" [_]) =
    [aggregateNeed "make0" kind, aggregateNeed "make1" kind, aggregateNeed "drop" kind]
  optionNeeds _ = []
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
  recordDefinitions layouts (recordsIn layouts (concatMap crossingTypes declarations))
    <> concatMap releaser (Set.toList (Set.fromList (concatMap (\declared -> maybe [] pure (releaseOf declared) <> map snd (slotReleases declared)) declarations)))
    <> concatMap emitWrapper declarations
 where
  releaser target@(_, _, _, answer) =
    [ "static pudu_foreign_cache " <> releaserName target <> "_cache = {NULL};"
    , "static void " <> releaserName target <> "(uint64_t address) {"
    , "  " <> abiType answer <> " (*function)(void *) = ((" <> abiType answer <> " (*)(void *))"
        <> releaserName target <> "_cache.function);"
    , "  (void)function((void *)(uintptr_t)address);"
    , "}", "" ]
  resolveRelease producer target@(library, version, symbol, _) =
    [ "  (void)pudu_foreign_function(site, &" <> releaserName target <> "_cache, "
        <> cString library <> ", " <> maybe "NULL" cString version <> ", " <> cString symbol <> ", "
        <> cString producer <> ");" ]
  checkText kind value = case kind of
    CoreTextType -> ["  pudu_foreign_text_check(noughts, " <> value <> ");"]
    CoreRecordType _ _ -> case Map.lookup kind layouts of
      Just (CoreRecordLayout fields) -> concat
        [ checkText field ("(" <> value <> ")->fields[" <> textOfInt index <> "]."
            <> if field == CoreTextType then "text" else "box")
        | (index, (_, field)) <- zip [0 ..] fields ]
      _ -> []
    _ -> []
  resultText kind value = case Map.lookup kind layouts of
    Just (CoreRecordLayout fields) -> concat
      [ let member = value <> ".f" <> textOfInt index
         in if field == CoreTextType then [(label, member)] else resultText field member
      | (index, (label, field)) <- zip [0 ..] fields ]
    _ -> []
  claimMode claim = case claim of
    Just (CoreOwned False _ _) -> "1"
    Just (CoreOwned True _ _) -> "2"
    _ -> "0"
  emitWrapper declared = case slotResult declared of
    Just (native, slots) -> slotWrapper declared native slots
    Nothing -> wrapper declared
  slotWrapper declared native slots =
    let result = coreForeignResult declared
        parameters = zip [0 ..] (coreForeignParameters declared)
        position = Set.fromList (coreForeignSlotPositions declared)
        nativeRelease = releaseOf declared
        releases = slotReleases declared <> [(-1, target) | Just target <- [nativeRelease]]
        destructorCount = textOfInt (length releases)
        handleNames = Set.toAscList (Set.fromList [handle | handle@(CoreHandleType _ _) <- native : map slotAbiType slots])
        handleTypes = (-1, native) : zip [0 ..] (map slotAbiType slots)
        claimLine (i, target) =
          let identity = maybe 0 (\kind -> maybe 0 (+ 1) (lookup kind (zip handleNames [0 ..]))) (lookup i handleTypes)
           in "    {(uint64_t)(uintptr_t)" <> (if i < 0 then "answer" else "slot" <> textOfInt i) <> ", " <> textOfInt identity <> ", 0, " <> releaserName target <> "},"
        claimIndex i = maybe "0" textOfInt (lookup i (zip (map fst releases) [0 ..]))
        abiSlots = [(abiType (slotAbiType kind) <> " *", "&slot" <> textOfInt i) | (i, kind) <- zip [0 ..] slots]
        lendsText = any (carriesText . snd) parameters
        handles = [i | (i, CoreHandleType _ _) <- parameters]
        held = sum [textLeaves layouts kind | (_, kind@(CoreRecordType _ _)) <- parameters]
        abiInputs = [(abiType kind, inputArgument i kind) | (i, kind) <- parameters]
        inputArgument i kind = case kind of
          CoreTextType -> "t" <> textOfInt i
          CoreRecordType _ _ -> "r" <> textOfInt i
          _ -> toAbi kind ("a" <> textOfInt i)
        textChecks = concat [checkText kind ("a" <> textOfInt i) | (i, kind) <- parameters]
        copies = concat
          [ case kind of
              CoreTextType -> ["  char *t" <> textOfInt i <> " = pudu_foreign_text_in(a" <> textOfInt i <> ");"]
              CoreRecordType _ _ -> ["  " <> abiType kind <> " r" <> textOfInt i <> " = pudu_foreign_pack_" <> suffix kind
                <> "(a" <> textOfInt i <> ", " <> (if held == 0 then "NULL, NULL" else "held, &held_count") <> ");"]
              _ -> []
          | (i, kind) <- parameters ]
        scratchDrops = ["  free(t" <> textOfInt i <> ");" | (i, CoreTextType) <- parameters]
          <> ["  for (size_t i = 0; i < held_count; ++i) free(held[i]);" | held /= 0]
        refuse condition statement = ["  if (" <> condition <> ") {"]
          <> map ("  " <>) scratchDrops <> ["    " <> statement, "    return NULL;", "  }"]
        resultLeaves = case native of
          CoreTextType -> [("result", "answer")]
          _ -> resultText native "answer"
        abiOrder = interleave position 0 abiInputs abiSlots
        slotLeaves = [(label, field)
          | (i, kind) <- zip [0 ..] slots
          , (label, field) <- case kind of
              CoreSumType "Option" [CoreTextType] -> [("", "slot" <> textOfInt i)]
              _ -> resultText kind ("slot" <> textOfInt i)]
        textSites = carriesText native || any (carriesText . slotAbiType) slots
        pointerArgs = Text.intercalate ", " (map fst abiOrder)
        call = "function(" <> Text.intercalate ", " (map snd abiOrder) <> ");"
        slotValue i kind = case kind of
          CoreRecordType _ _ -> "pudu_foreign_unpack_" <> suffix kind <> "(slot" <> textOfInt i <> ")"
          CoreSumType "Option" [CoreTextType] -> "slot" <> textOfInt i <> " == NULL ? "
            <> aggregateHelper "make1" kind <> "() : " <> aggregateHelper "make0" kind <> "(copied" <> textOfInt i <> ")"
          CoreSumType "Option" [CoreHandleType _ _] -> "held" <> textOfInt i <> " == NULL ? "
            <> aggregateHelper "make1" kind <> "() : " <> aggregateHelper "make0" kind <> "(held" <> textOfInt i <> ")"
          _ -> fromAbi kind ("slot" <> textOfInt i)
        resultArgument = case native of
          CoreUnitType -> "0"
          CoreTextType -> "native_value"
          CoreRecordType _ _ -> "native_value"
          CoreHandleType _ _ -> "native_value"
          _ -> fromAbi native "answer"
        resultArgs = resultArgument
          : ["written" <> textOfInt i | (i, _) <- zip [0 ..] slots]
     in [ "static pudu_box *" <> wrapperName declared <> "(const pudu_site *site"
            <> (if lendsText then ", const pudu_site *noughts" else "")
            <> (if textSites then ", const pudu_site *missing, const pudu_site *invalid" else "")
            <> (if null handles then "" else ", const pudu_site *dead")
            <> (if nativeRelease == Nothing then "" else ", const pudu_site *none")
            <> (if null releases then "" else ", const pudu_site *duplicate")
            <> foldMap (\(i, kind) -> ", " <> cType kind <> " a" <> textOfInt i) parameters <> ") {"
        , "  static pudu_foreign_cache cache = {NULL};"
        ]
        <> ["  (void)noughts;" | lendsText && null textChecks] <> textChecks
        <> [ "  " <> abiType native <> " (*function)(" <> pointerArgs <> ") = ("
            <> abiType native <> " (*)(" <> pointerArgs <> "))pudu_foreign_function(site, &cache, "
            <> cString (coreForeignLibrary declared) <> ", "
            <> maybe "NULL" cString (coreForeignVersion declared) <> ", "
            <> cString (coreForeignSymbol declared) <> ", NULL);"
        ]
        <> concatMap (resolveRelease (coreForeignSymbol declared) . snd) releases
        <> [ "  pudu_foreign_require(dead, a" <> textOfInt i <> ", 0);" | i <- handles ]
        <> ["  pudu_foreign_reserve(" <> destructorCount <> ");" | not (null releases)]
        <> ["  (void)missing; (void)invalid;" | textSites]
        <> [ "  " <> abiType (slotAbiType kind) <> " slot" <> textOfInt i <> " = {0};"
           | (i, kind) <- zip [0 ..] slots ]
        <> (if held == 0 then [] else ["  char *held[" <> textOfInt held <> "];", "  size_t held_count = 0;"])
        <> copies
        <> [ "  " <> (if native == CoreUnitType then "" else abiType native <> " answer = ") <> call
           ]
        <> (if null releases then [] else
             ["  pudu_foreign_claim claimed[] = {"] <> map claimLine releases
             <> ["  };", "  pudu_foreign_claim_slots(duplicate, claimed, " <> destructorCount <> ");"])
        <> concat [refuse (field <> " != NULL && !pudu_foreign_text_valid(" <> field <> ")") "pudu_fail(invalid);"
                  | (_, field) <- resultLeaves <> slotLeaves]
        <> concat [refuse (field <> " == NULL") ("pudu_foreign_missing_field(missing, "
                    <> cString (coreForeignSymbol declared) <> ", " <> cString label <> ");")
                  | (label, field) <- resultLeaves <> slotLeaves, not (Text.null label)]
        <> [line | Just _ <- [nativeRelease], line <- refuse "answer == NULL" "pudu_fail(none);"]
        <> (case native of
              CoreHandleType _ _ -> ["  pudu_box *native_value = pudu_foreign_slot_box(claimed["
                <> claimIndex (-1) <> "].address, claimed[" <> claimIndex (-1) <> "].generation);"]
              CoreTextType -> ["  pudu_text native_value = pudu_text_copy(answer, strlen(answer));"]
              CoreRecordType _ _ -> ["  pudu_box *native_value = pudu_foreign_unpack_" <> suffix native <> "(answer);"]
              _ -> [])
        <> [ "  pudu_box *held" <> textOfInt i <> " = slot" <> textOfInt i <> " == NULL ? NULL : "
              <> "pudu_foreign_slot_box(claimed[" <> claimIndex i <> "].address, claimed[" <> claimIndex i <> "].generation);"
           | (i, CoreSumType "Option" [CoreHandleType _ _]) <- zip [0 ..] slots ]
        <> [ "  pudu_text copied" <> textOfInt i <> " = slot" <> textOfInt i
              <> " == NULL ? (pudu_text){0} : pudu_text_copy(slot" <> textOfInt i <> ", strlen(slot" <> textOfInt i <> "));"
           | (i, CoreSumType "Option" [CoreTextType]) <- zip [0 ..] slots ]
        <> [ "  " <> cType kind <> " written" <> textOfInt i <> " = " <> slotValue i kind <> ";"
           | (i, kind) <- zip [0 ..] slots ]
        <> [ "  pudu_box *tuple = " <> aggregateHelper "make" result <> "(" <> Text.intercalate ", " resultArgs <> ");" ]
        <> [ "  " <> dropSlot | (i, kind) <- zip [0 ..] slots
           , let dropSlot = released kind ("written" <> textOfInt i), not (Text.null dropSlot) ]
        <> [ "  " <> released handle ("held" <> textOfInt i)
           | (i, CoreSumType "Option" [handle@(CoreHandleType _ _)]) <- zip [0 ..] slots ]
        <> [ "  pudu_text_release(copied" <> textOfInt i <> ");"
           | (i, CoreSumType "Option" [CoreTextType]) <- zip [0 ..] slots ]
        <> ["  " <> dropNative | let dropNative = released native "native_value", not (Text.null dropNative)]
        <> scratchDrops
        <> [ "  return tuple;", "}", "" ]
  interleave position index inputs slots
    | Set.member index position, slot : rest <- slots =
        slot : interleave position (index + 1) inputs rest
    | input : rest <- inputs = input : interleave position (index + 1) rest slots
    | otherwise = []
  wrapper declared =
    let parameters = zip [0 :: Int ..] (coreForeignParameters declared)
        result = coreForeignResult declared
        held = sum [textLeaves layouts kind | (_, kind@(CoreRecordType _ _)) <- parameters]
        lendsText = any (carriesText . snd) parameters
        abiParameters = if null parameters then "void" else Text.intercalate ", " [abiType kind | (_, kind) <- parameters]
        pointer = abiType result <> " (*)(" <> abiParameters <> ")"
        resolved = "((" <> pointer <> ")pudu_foreign_function(site, &cache, " <> cString (coreForeignLibrary declared) <> ", "
          <> maybe "NULL" cString (coreForeignVersion declared) <> ", " <> cString (coreForeignSymbol declared) <> ", NULL))"
        argument index kind = case kind of
          CoreTextType -> "t" <> textOfInt index
          CoreRecordType _ _ -> "r" <> textOfInt index
          _ -> toAbi kind ("a" <> textOfInt index)
        call = "function(" <> Text.intercalate ", " [argument index kind | (index, kind) <- parameters] <> ")"
        handles = [index | (index, CoreHandleType _ _) <- parameters]
        claim = coreForeignClaim declared
        release = releaseOf declared
        siteParameters = ["const pudu_site *site"] <> ["const pudu_site *noughts" | lendsText]
          <> concat [["const pudu_site *missing", "const pudu_site *invalid"] | carriesText result]
          <> ["const pudu_site *dead" | not (null handles)]
          <> concat [["const pudu_site *none"] | isHandle result]
          <> ["const pudu_site *owned" | isHandle result, Just (CoreOwned False _ _) <- [claim]]
        checks = [ "  pudu_foreign_require(dead, a" <> textOfInt index
                     <> ", " <> (if coreForeignReleases declared then "1" else "0") <> ");" | index <- handles ]
        textChecks = concat [checkText kind ("a" <> textOfInt index) | (index, kind) <- parameters]
        heldLines = if held == 0 then [] else ["  char *held[" <> textOfInt held <> "];", "  size_t held_count = 0;"]
        copies = concat
          [ case kind of
              CoreTextType -> ["  char *t" <> textOfInt index <> " = pudu_foreign_text_in(a" <> textOfInt index <> ");"]
              CoreRecordType _ _ -> ["  " <> abiType kind <> " r" <> textOfInt index <> " = pudu_foreign_pack_" <> suffix kind
                <> "(a" <> textOfInt index <> ", " <> (if held == 0 then "NULL, NULL" else "held, &held_count") <> ");"]
              _ -> []
          | (index, kind) <- parameters ]
        releases = ["  free(t" <> textOfInt index <> ");" | (index, CoreTextType) <- parameters]
          <> ["  for (size_t i = 0; i < held_count; ++i) free(held[i]);" | held /= 0]
        body = case result of
          CoreUnitType -> ["  " <> call <> ";"] <> releases <> ["  return 0;"]
          CoreTextType -> ["  const char *raw = " <> call <> ";"
            , "  if (raw == NULL || !pudu_foreign_text_valid(raw)) {"
            , "    const pudu_site *problem = raw == NULL ? missing : invalid;" ]
            <> map ("  " <>) releases
            <> [ "    pudu_fail(problem);"
               , "    return pudu_text_copy(\"\", 0);"
               , "  }"
               , "  pudu_text answer = pudu_text_copy(raw, strlen(raw));" ]
            <> releases <> ["  return answer;"]
          CoreRecordType _ _ ->
            let leaves = resultText result "raw"
                reject condition failure =
                  ["  if (" <> condition <> ") {"]
                  <> map ("  " <>) releases
                  <> ["    " <> failure, "    return NULL;", "  }"]
             in ["  " <> abiType result <> " raw = " <> call <> ";", "  (void)missing; (void)invalid;"]
                <> concat [reject (field <> " != NULL && !pudu_foreign_text_valid(" <> field <> ")") "pudu_fail(invalid);"
                          | (_, field) <- leaves]
                <> concat [reject (field <> " == NULL")
                    ("pudu_foreign_missing_field(missing, " <> cString (coreForeignSymbol declared) <> ", " <> cString label <> ");")
                          | (label, field) <- leaves]
                <> ["  pudu_box *answer = pudu_foreign_unpack_" <> suffix result <> "(raw);"]
                <> releases <> ["  return answer;"]
          CoreHandleType _ _ -> ["  void *answer = " <> call <> ";"] <> releases <>
            [ "  return pudu_foreign_handle_result(none, " <> (if any (== "const pudu_site *owned") siteParameters then "owned" else "NULL")
                <> ", " <> claimMode claim <> ", " <> maybe "NULL" releaserName release <> ", answer);" ]
          _ -> ["  " <> abiType result <> " answer = " <> call <> ";"] <> releases <> ["  return " <> fromAbi result "answer" <> ";"]
     in [ "static " <> cellType result <> " " <> wrapperName declared <> "("
            <> Text.intercalate ", " (siteParameters <> [cType kind <> " a" <> textOfInt index | (index, kind) <- parameters]) <> ") {"
        , "  static pudu_foreign_cache cache = {NULL};" ]
        <> ["  (void)noughts;" | lendsText && null textChecks]
        <> textChecks
        <> ["  " <> abiType result <> " (*function)(" <> abiParameters <> ") = " <> resolved <> ";"]
        <> maybe [] (resolveRelease (coreForeignSymbol declared)) release
        <> checks
        <> ["  pudu_foreign_reserve(1);" | Just _ <- [release]]
        <> heldLines
        <> copies
        <> body
        <> ["}", ""]
  cellType kind = if kind == CoreUnitType then "int" else cType kind
  isHandle kind = case kind of
    CoreHandleType _ _ -> True
    _ -> False
  suffix kind = Text.drop (Text.length "pudu_foreign_record_") (abiType kind)

crossingTypes :: CoreForeign -> [CoreType]
crossingTypes declared = coreForeignParameters declared <> case slotResult declared of
  Just (native, slots) -> native : slots
  Nothing -> [coreForeignResult declared]

slotAbiType :: CoreType -> CoreType
slotAbiType (CoreSumType "Option" [kind]) = kind
slotAbiType kind = kind

slotResult :: CoreForeign -> Maybe (CoreType, [CoreType])
slotResult declared
  | not (null (coreForeignSlotPositions declared))
  , CoreTupleType (native : slots) <- coreForeignResult declared = Just (native, slots)
  | otherwise = Nothing

{-| The release an owned handle result is released through: its library, version, symbol and result. -}
slotReleases :: CoreForeign -> [(Int, (Text, Maybe Text, Text, CoreType))]
slotReleases declared =
  [ (i, (coreForeignLibrary declared, coreForeignVersion declared, symbol, result))
  | (i, Just (CoreOwned _ symbol result)) <- zip [0 ..] (coreForeignSlotClaims declared) ]

releaseOf :: CoreForeign -> Maybe (Text, Maybe Text, Text, CoreType)
releaseOf declared = case (maybe (coreForeignResult declared) fst (slotResult declared), coreForeignClaim declared) of
  (CoreHandleType _ _, Just (CoreOwned _ symbol answer)) -> Just (coreForeignLibrary declared, coreForeignVersion declared, symbol, answer)
  _ -> Nothing

releaserName :: (Text, Maybe Text, Text, CoreType) -> Text
releaserName target = "pudu_foreign_release_" <> mangle (Text.pack (show target))

{-| A name that is a C identifier and differs for every declaration. -}
wrapperName :: CoreForeign -> Text
wrapperName declared = "pudu_foreign_" <> mangle (Text.pack (show declared))

carriesText :: CoreType -> Bool
carriesText kind = case kind of
  CoreTextType -> True
  CoreRecordType _ _ -> True
  _ -> False

{-| The parts converting a cell to the C type it crosses as. -}
parameterNeeds :: CoreType -> [Text]
parameterNeeds kind = case kind of
  CoreIntegerType (SignedKind _) -> ["kernel_signed"]
  CoreFloatType _ -> ["float_decode"]
  CoreTextType -> ["host_foreign_text_in"]
  CoreBytesType -> ["host_foreign_bytes"]
  CoreHandleType _ _ -> ["host_foreign_store"]
  _ -> []

{-| The parts converting an answer back to its cell. -}
resultNeeds :: CoreType -> [Text]
resultNeeds kind = case kind of
  CoreIntegerType (SignedKind _) -> ["kernel_int"]
  CoreIntegerType _ -> ["make"]
  CoreFloatType _ -> ["float_encode"]
  CoreTextType -> ["host_foreign_text_out"]
  CoreHandleType _ _ -> ["host_foreign_store"]
  _ -> []
