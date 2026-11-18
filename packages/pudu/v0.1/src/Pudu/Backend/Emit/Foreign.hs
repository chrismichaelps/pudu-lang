{-| @Backend.Emit.Foreign — one typed wrapper per foreign declaration a
    program calls, and the call through it. A wrapper converts each frame cell
    to the C type the declaration crosses as, calls through a function pointer
    of that exact type, and converts the answer back. -}
module Pudu.Backend.Emit.Foreign (foreignCall, foreignWrappers, foreignNeeds, foreignsOf, parameterNeeds, resultNeeds) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed, cType, released)
import Pudu.Backend.Emit.Foreign.Callback
  ( NativeArgument (..), blockInvokeName, blockSignatures, callbackArgumentTypes, callbackIdentity, callbackTrampolines, nativeArguments
  , trampolineName, trampolineType )
import Pudu.Backend.Emit.Foreign.Loan
  ( byValueInputs, extentChecks, foreignCallName, foreignCellType, hasLiveRunInputs, hasMutableInputs, hasRunInputs
  , inputParameter, loanPointer, loanResult, loanWrapper, mutableInputs, needsLoanProtection
  , pointeeType, unpackNativeRun )
import Pudu.Backend.Emit.ForeignAbi
  ( Layouts, abiType, foreignHandleType, fromAbi, isOptionalHandle, mangle
  , recordDefinitions, recordNeeds, recordsIn, textLeaves, toAbi )
import Pudu.Backend.Emit.State (EmitState, cString, cStringBytes, helpedFailureSite, textFailureSite, textOfInt)
import Pudu.Foreign.Crossing (ObjectiveCMethod (..), objectiveCInitializer)
import Pudu.Core
  ( CoreCallbackSignature (..), CoreCallbackSlot (..), CoreClaim (..), CoreForeign (..), CoreLayout (..), CoreType (..) )
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
      (s5, dead) = case [name | kind <- coreForeignParameters declared, Just (CoreHandleType _ name) <- [foreignHandleType kind]] of
        name : _ -> fmap Just (helpedFailureSite s4 at "E7022"
          ("the " <> name <> " passed to " <> symbol <> " is no longer owned") deadHelp)
        [] -> (s4, Nothing)
      (s6, none) = case nativeResult of
        CoreHandleType _ name -> fmap Just (helpedFailureSite s5 at "E7020" (symbol <> " returned a null " <> name) (if hasSlots then "an owned foreign result must name a live object" else noneHelp))
        _ -> (s5, Nothing)
      (s7, owned) = case (foreignHandleType result, coreForeignClaim declared) of
        (Just (CoreHandleType _ name), Just (CoreOwned False _ _)) -> fmap Just (helpedFailureSite s6 at "E7021" (symbol <> " returned a " <> name <> " already owned") ownedHelp)
        _ | hasSlots, not (null (slotReleases declared)) || releaseOf declared /= Nothing -> fmap Just (helpedFailureSite s6 at "E7021"
          (symbol <> " handed back duplicate or already owned resources") "an owned foreign value must transfer one new ownership claim")
        _ -> (s6, Nothing)
      (s8, resultExtent) = case coreForeignReturnedRun declared of
        Nothing -> (s7, Nothing)
        Just _ -> fmap Just (helpedFailureSite s7 at "E7028" "foreign result has an invalid buffer length or address"
          "return a live allocation of the declared length, or an allowed null with length zero")
      (s9, extent) = if null (coreForeignBounds declared) && not (hasLiveRunInputs declared) then (s8, Nothing)
        else fmap Just (helpedFailureSite s8 at "E7028" "foreign length is outside the input buffer"
          "pass a non-negative length within every related buffer")
      sites = [siteText site] <> map siteText (concatMap (maybe [] pure)
        [noughts, missing, invalid, dead, none, owned, resultExtent, extent])
   in ( s9
      , foreignCallName (wrapperName declared) declared <> "(" <> Text.intercalate ", " (sites <> cells) <> ")"
      , ["host_foreign"] )
 where
  result = coreForeignResult declared
  nativeResult = maybe result fst (slotResult declared)
  hasSlots = not (null (coreForeignSlotPositions declared))
  symbol = coreForeignSymbol declared
  lendsText = any (carriesText . snd) (byValueInputs declared)
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
  [ concatMap parameterNeeds (concatMap (leaves . pointeeType) (coreForeignParameters declared))
      <> concatMap resultNeeds (leaves (coreForeignResult declared))
      <> concatMap (resultNeeds . pointeeType . snd) (mutableInputs declared)
      <> [aggregateNeed "drop" kind | (_, kind@CoreArrayType{}) <- mutableInputs declared]
      <> ["host_foreign_loan" | needsLoanProtection declared]
      <> ["host_foreign_run" | hasLiveRunInputs declared]
      <> ["host_foreign_lease" | yieldsWithHandles declared]
      <> ["host_callback" | callbackScopeNeeded declared]
      <> ["host_objc" | coreForeignObjectiveC declared /= Nothing]
      <> ["host_foreign_block" | not (null (blockSignatures [declared]))]
      <> ["host_foreign_bounds" | not (null (coreForeignBounds declared))]
      <> concat
          [ ["array", "host_foreign_store", aggregateNeed "drop" (CoreArrayType element)]
              <> resultNeeds element <> optionNeeds native
          | Just (native, element) <- [returnedRunTypes declared] ]
      <> [aggregateNeed "make" (loanResult declared) | hasMutableInputs declared]
      <> (case slotResult declared of
        Just (native, slots) -> aggregateNeed "make" (coreForeignResult declared) : concatMap resultNeeds (concatMap leaves (native : map slotAbiType slots)) <> concatMap optionNeeds slots
        Nothing -> [])
      <> concat ["host_optional" : concatMap parameterNeeds (leaves kind) <> concatMap resultNeeds (leaves kind) <> recordNeeds layouts kind
                | kind@(CoreRecordType _ _) <- crossingTypes declared]
      <> ["host_foreign_sqlite" | coreForeignLibrary declared == "pudu_sqlite"]
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
foreignWrappers :: Layouts -> [CoreForeign] -> [CoreCallbackSignature] -> [CoreType] -> [Text]
foreignWrappers layouts declarations signatures results =
  recordDefinitions layouts (recordsIn layouts (concatMap crossingTypes declarations <> concatMap callbackArgumentTypes signatures))
    <> concatMap releaser (Set.toList (Set.fromList (concatMap (\declared -> maybe [] pure (releaseOf declared) <> map snd (slotReleases declared)) declarations)))
    <> callbackTrampolines layouts signatures (blockSignatures declarations) results
    <> concatMap emitWrapper declarations
 where
  releaser target@(_, _, _, answer) =
    [ "static pudu_foreign_cache " <> releaserName target <> "_cache = {NULL};"
    , "static void " <> releaserName target <> "(uint64_t address) {"
    , "  " <> abiType answer <> " (*function)(void *) = (" <> abiType answer <> " (*)(void *))"
        <> "pudu_foreign_cached(&" <> releaserName target <> "_cache);"
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
  handleInputs parameters = [(index, kind) | (index, kind) <- parameters, isHandle kind]
  handleInput index kind =
    let argument = "a" <> textOfInt index
        present = argument <> "->fields[0].scalar == 0"
        handle = if isOptionalHandle kind then argument <> "->fields[1].box" else argument
        condition = if isOptionalHandle kind then "if (" <> present <> ") " else ""
     in (condition, handle)
  requireHandle consume (index, kind) =
    let (condition, handle) = handleInput index kind
     in "  " <> condition <> "pudu_foreign_require(dead, " <> handle <> ", " <> (if consume then "1" else "0") <> ");"
  leaseHandles declared acquire =
    [ "  " <> condition <> "pudu_foreign_handle_lease(" <> handle <> ", " <> (if acquire then "1" else "0") <> ");"
    | yieldsWithHandles declared
    , (index, kind) <- handleInputs (zip [0 ..] (coreForeignParameters declared))
    , index /= 0 || not (initializesReceiver declared)
    , let (condition, handle) = handleInput index kind ]
  receiverChecks declared handles
    | not (initializesReceiver declared) = []
    | otherwise =
        ["  pudu_foreign_check_receiver(dead, a0);"]
        <> [ "  " <> condition <> "if (pudu_foreign_same_claim(a0, " <> handle <> ")) pudu_fail(dead);"
           | (index, kind) <- handles, index /= 0
           , let (condition, handle) = handleInput index kind ]
  optionHandle kind output value =
    [ "  pudu_box *" <> output <> " = " <> value <> " == NULL ? "
        <> aggregateHelper "make1" kind <> "() : " <> aggregateHelper "make0" kind <> "(" <> value <> ");"
    ] <> ["  " <> released handle value | Just handle <- [foreignHandleType kind]]
  discardResults declared = case slotResult declared of
    Nothing ->
      [discardResult (coreForeignResult declared) "answer" | releaseOf declared /= Nothing]
    Just (native, slots) ->
      [discardResult native "answer->fields[0].box"
      | releaseOf declared /= Nothing, coreForeignReturnedRun declared == Nothing]
        <> [ discardResult kind ("answer->fields[" <> textOfInt (index + 1) <> "].box")
           | (index, kind) <- zip [0 ..] slots, Just _ <- [lookup index (slotReleases declared)] ]
  discardResult kind value
    | isOptionalHandle kind =
        "if (" <> value <> "->fields[0].scalar == 0) "
          <> discardGeneration (value <> "->fields[1].box")
    | otherwise = discardGeneration value
  discardGeneration value = "pudu_foreign_discard_generation(" <> value <> "->fields[1].floating);"
  emitWrapper declared = dispatched <> loanWrapper (wrapperName declared) declared sites
   where
    (sites, crossed) = case slotResult declared of
      Just (native, slots) -> slotWrapper declared native slots
      Nothing -> wrapper declared
    dispatched
      | not (callbackScopeNeeded declared) = crossed
      | otherwise = delivering declared crossed

  -- A Pudu argument as the C type and value it crosses as. A callback token
  -- crosses as its declaration's trampoline; its context crosses beside it.
  inputCrossing declared index kind = case kind of
    _ | Just exclusive <- lookup index (coreForeignLoans declared) ->
      (loanPointer exclusive kind, "a" <> textOfInt index)
    CoreCallbackType owner _ | Just signature <- callbackFor declared owner -> (trampolineType signature, trampolineName signature)
    CoreTextType -> (abiType kind, "t" <> textOfInt index)
    CoreRecordType _ _ -> (abiType kind, "r" <> textOfInt index)
    _ -> (abiType kind, toAbi kind ("a" <> textOfInt index))
  callbackFor declared owner = lookup owner
    [(coreCallbackOwner (coreCallbackSignature slot), coreCallbackSignature slot) | slot <- coreForeignCallbacks declared]
  nativeOrder declared inputs slots =
    let crossed =
          [ case argument of
              NativeInput index -> inputs !! index
              NativeSlot index -> slots !! index
              NativeContext index -> ("void *", "(void *)a" <> textOfInt index)
              NativeTrampoline signature -> (trampolineType signature, trampolineName signature)
              -- The literal lives until the wrapper returns; a callee that keeps it copies it.
              NativeBlock index signature -> ("void *", "(void *)&(pudu_foreign_block){_NSConcreteStackBlock, 0, 0, (void *)"
                <> blockInvokeName signature <> ", &pudu_foreign_block_shape, (uintptr_t)a" <> textOfInt index <> "}")
          | argument <- nativeArguments declared ]
        selector = ("void *", "pudu_objc_selector(&objc)")
     in case coreForeignObjectiveC declared of
          Just ObjectiveCMethod{objectiveCClass = Just _} ->
            ("void *", "pudu_objc_receiver(&objc)") : selector : crossed
          Just _ -> case crossed of
            receiver : rest -> receiver : selector : rest
            [] -> []
          Nothing -> crossed
  functionCache declared = case coreForeignObjectiveC declared of
    Nothing -> "  static pudu_foreign_cache cache = {NULL};"
    Just _ -> "  static pudu_objc_cache objc = {0};"
  resolveFunction declared result =
    let library = cString (coreForeignLibrary declared)
        version = maybe "NULL" cString (coreForeignVersion declared)
        symbol = cString (coreForeignSymbol declared)
        identity = Text.intercalate ", " [library, version, symbol]
        structure = case result of
          CoreRecordType{} -> "sizeof(" <> abiType result <> ")"
          _ -> "0"
     in case coreForeignObjectiveC declared of
          Nothing -> "pudu_foreign_function(site, &cache, " <> identity <> ", NULL)"
          Just method -> "pudu_objc_prepare(site, &objc, " <> identity <> ", "
            <> maybe "NULL" cString (objectiveCClass method) <> ", " <> structure <> ")"
  -- With callbacks, the native call runs outside the run gate, inside a
  -- failure scope a callback's failure is recorded in.
  nativeCall declared order
    | not (callbackScopeNeeded declared) = "function(" <> Text.intercalate ", " (map snd order) <> ")"
    | otherwise = wrapperName declared <> "_native(scope, function" <> foldMap ((", " <>) . snd) order <> ")"
  afterNative declared statement =
    ["  pudu_foreign_loan_disarm();" | hasLiveRunInputs declared]
    <> ["  pudu_foreign_transfer_receiver(a0);" | initializesReceiver declared]
    <> leaseHandles declared True
    <> ["  " <> statement <> ";"]
    <> leaseHandles declared False
    <> (if needsLoanProtection declared
          then ["  loan->dispatched = 1;", "  pudu_foreign_loan_arm(loan);"]
          else [])
  loanParameter declared = ["pudu_foreign_loan *loan" | needsLoanProtection declared]
  extentParameter declared =
    ["const pudu_site *extent" | not (hasRunInputs declared) && not (null (coreForeignBounds declared))]
  directExtentChecks declared = [line | not (hasRunInputs declared), line <- extentChecks declared]
  nativeShim declared answer order
    | not (callbackScopeNeeded declared) = []
    | otherwise =
        let types = if null order then "void" else Text.intercalate ", " (map fst order)
            named = [(kind, "x" <> textOfInt index) | (index, (kind, _)) <- zip [0 :: Int ..] order]
            invoked = "function(" <> Text.intercalate ", " (map snd named) <> ");"
         in [ "static " <> answer <> " " <> wrapperName declared <> "_native(pudu_callback_scope *scope, "
                <> answer <> " (*function)(" <> types <> ")" <> foldMap (\(kind, name) -> ", " <> kind <> " " <> name) named <> ") {"
            , "  pudu_callback_outbound_begin(scope);" ]
            <> (if answer == "void"
                  then ["  " <> invoked, "  pudu_callback_outbound_end(scope);", "}"]
                  else ["  " <> answer <> " answer = " <> invoked, "  pudu_callback_outbound_end(scope);", "  return answer;", "}"])
  -- The crossing runs under a scope of its own; the wrapper the call site
  -- names holds the callback tokens for the call and, once the crossing has
  -- settled its ownership, delivers the first failure a callback raised.
  delivering declared crossed = case break (Text.isInfixOf (wrapperName declared <> "(")) crossed of
    (shim, header : rest)
      | (front, afterName) <- Text.breakOn (wrapperName declared <> "(") header
      , Just parameters <- Text.stripSuffix ") {" (Text.drop (Text.length (wrapperName declared) + 1) afterName) ->
          let answer = Text.strip (Text.drop (Text.length "static ") front)
              names = map (Text.takeWhileEnd (\c -> c /= ' ' && c /= '*') . Text.strip) (Text.splitOn ", " parameters)
              retired = "cannot call " <> coreForeignSymbol declared <> " in " <> coreForeignLibrary declared
                <> ": a callback token is no longer registered"
              tokens = [ (index, signature)
                       | (index, CoreCallbackType owner _) <- zip [0 :: Int ..] (coreForeignParameters declared)
                       , Just signature <- [callbackFor declared owner] ]
              cleanup = wrapperName declared <> "_cleanup"
              cleanupType = cleanup <> "_state"
              capture = needsLoanProtection declared
              dropBox = released (coreForeignResult declared) "answer"
              dropResult = discardResults declared <> [dropBox | not (Text.null dropBox)]
           in shim
                <> [front <> wrapperName declared <> "_crossing(pudu_callback_scope *scope, " <> parameters <> ") {"]
                <> rest
                <> (if capture then
                      [ "typedef struct { pudu_callback_scope *scope; pudu_callback_entry *leases[" <> textOfInt (max 1 (length tokens)) <> "]; } " <> cleanupType <> ";"
                      , "static void " <> cleanup <> "(void *value) {"
                      , "  " <> cleanupType <> " *held = value;"
                      ] <> ["  for (size_t i = 0; i < " <> textOfInt (length tokens)
                          <> "; ++i) if (held->leases[i] != NULL) pudu_callback_unlease(held->leases[i]);" | not (null tokens)]
                      <> ["  if (held->scope->failed) pudu_text_release(held->scope->failure);", "}"] else [])
                <> [ header
                   , "  pudu_callback_scope scope = {0};" ]
                <> (if capture then
                      [ "  " <> cleanupType <> " held = {.scope = &scope};"
                      , "  loan->cleanup = " <> cleanup <> ";"
                      , "  loan->cleanup_data = &held;" ] else [])
                <> concat
                   [ [ "  pudu_callback_entry *lease" <> textOfInt index <> " = pudu_callback_lease(a" <> textOfInt index
                         <> ", &" <> callbackIdentity signature <> ");"
                     , "  if (lease" <> textOfInt index <> " == NULL) {" ]
                     <> ["    pudu_callback_unlease(lease" <> textOfInt prior <> ");"
                        | not capture, (prior, _) <- take ordinal tokens]
                     <> ["    pudu_fail_message(site, " <> cString retired
                         <> ", " <> textOfInt (cStringBytes retired) <> ");", "  }"]
                     <> ["  held.leases[" <> textOfInt ordinal <> "] = lease" <> textOfInt index <> ";" | capture]
                   | (ordinal, (index, signature)) <- zip [0 ..] tokens ]
                <> [ "  " <> answer <> " answer = " <> wrapperName declared <> "_crossing(&scope, " <> Text.intercalate ", " names <> ");" ]
                <> [ "  if (lease" <> textOfInt index <> " != NULL) pudu_callback_unlease(lease" <> textOfInt index <> ");" | (index, _) <- tokens ]
                <> ["  loan->cleanup = NULL;" | capture]
                <> (if null dropResult then [] else
                      ["  if (scope.failed) {"] <> map ("    " <>) dropResult <> ["  }"])
                <> [ "  if (scope.failed) pudu_callback_deliver(site, &scope);"
                   , "  return answer;"
                   , "}", "" ]
    _ -> crossed
  slotWrapper declared native slots =
    let result = coreForeignResult declared
        run = coreForeignReturnedRun declared
        nativeAbi = maybe native snd run
        parameters = zip [0 ..] (coreForeignParameters declared)
        nativeRelease = releaseOf declared
        releases = slotReleases declared <> [(-1, target) | Just target <- [nativeRelease]]
        destructorCount = textOfInt (length releases)
        handleTypes =
          [(index, handle) | (index, kind) <- (-1, nativeAbi) : zip [0 ..] slots, Just handle <- [foreignHandleType kind]]
        handleNames = Set.toAscList (Set.fromList (map snd handleTypes))
        counted = case coreForeignClaim declared of
          Just (CoreOwned True _ _) -> True
          _ -> False
        claimLine (i, target) =
          let identity = maybe 0 (\kind -> maybe 0 (+ 1) (lookup kind (zip handleNames [0 ..]))) (lookup i handleTypes)
              countedFlag = if i < 0 && counted then "1" else "0"
           in "    {(uint64_t)(uintptr_t)" <> (if i < 0 then "answer" else "slot" <> textOfInt i)
                <> ", " <> textOfInt identity <> ", " <> countedFlag <> ", " <> releaserName target <> ", 0},"
        claimIndex i = maybe "0" textOfInt (lookup i (zip (map fst releases) [0 ..]))
        abiSlots = [(abiType (slotAbiType kind) <> " *", "&slot" <> textOfInt i) | (i, kind) <- zip [0 ..] slots]
        ordinary = byValueInputs declared
        lendsText = any (carriesText . snd) ordinary
        handles = handleInputs parameters
        held = sum [textLeaves layouts kind | (_, kind@(CoreRecordType _ _)) <- ordinary]
        abiInputs = [inputCrossing declared i kind | (i, kind) <- parameters]
        textChecks = concat [checkText kind ("a" <> textOfInt i) | (i, kind) <- ordinary]
        copies = concat
          [ case kind of
              CoreTextType -> ["  char *t" <> textOfInt i <> " = pudu_foreign_text_in(a" <> textOfInt i <> ");"]
              CoreRecordType _ _ -> ["  " <> abiType kind <> " r" <> textOfInt i <> " = pudu_foreign_pack_" <> suffix kind
                <> "(a" <> textOfInt i <> ", " <> (if held == 0 then "NULL, NULL" else "held, &held_count") <> ");"]
              _ -> []
          | (i, kind) <- ordinary ]
        scratchDrops = ["  free(t" <> textOfInt i <> ");" | (i, CoreTextType) <- parameters]
          <> ["  for (size_t i = 0; i < held_count; ++i) free(held[i]);" | held /= 0]
        refuse cleanup condition statement = ["  if (" <> condition <> ") {"]
          <> map ("  " <>) (scratchDrops <> cleanup) <> ["    " <> statement, "    return NULL;", "  }"]
        discardClaims = ["  pudu_foreign_discard_slots(claimed, " <> destructorCount <> ");" | not (null releases)]
        resultLeaves = case native of
          CoreTextType -> [("result", "answer")]
          _ -> resultText native "answer"
        abiOrder = nativeOrder declared abiInputs abiSlots
        slotLeaves = [(label, field)
          | (i, kind) <- zip [0 ..] slots
          , (label, field) <- case kind of
              CoreSumType "Option" [CoreTextType] -> [("", "slot" <> textOfInt i)]
              _ -> resultText kind ("slot" <> textOfInt i)]
        textSites = carriesText native || any (carriesText . slotAbiType) slots
        pointerArgs = Text.intercalate ", " (map fst abiOrder)
        call = nativeCall declared abiOrder
        slotValue i kind = case kind of
          CoreRecordType _ _ -> "pudu_foreign_unpack_" <> suffix kind <> "(slot" <> textOfInt i <> ")"
          CoreSumType "Option" [CoreTextType] -> "slot" <> textOfInt i <> " == NULL ? "
            <> aggregateHelper "make1" kind <> "() : " <> aggregateHelper "make0" kind <> "(copied" <> textOfInt i <> ")"
          CoreSumType "Option" [CoreHandleType _ _] -> "held" <> textOfInt i <> " == NULL ? "
            <> aggregateHelper "make1" kind <> "() : " <> aggregateHelper "make0" kind <> "(held" <> textOfInt i <> ")"
          _ -> fromAbi kind ("slot" <> textOfInt i)
        resultArgument = case native of
          _ | run /= Nothing -> "native_value"
          CoreUnitType -> "0"
          CoreTextType -> "native_value"
          CoreRecordType _ _ -> "native_value"
          _ | isHandle native -> "native_value"
          _ -> fromAbi native "answer"
        resultArgs = resultArgument
          : ["written" <> textOfInt i | (i, _) <- zip [0 ..] slots]
        siteParameters = ["const pudu_site *site"] <> ["const pudu_site *noughts" | lendsText]
          <> concat [["const pudu_site *missing", "const pudu_site *invalid"] | textSites]
          <> ["const pudu_site *dead" | not (null handles)]
          <> ["const pudu_site *none" | isHandle native && not (isOptionalHandle native)]
          <> ["const pudu_site *duplicate" | not (null releases)]
          <> ["const pudu_site *result_extent" | run /= Nothing]
          <> extentParameter declared
        decodeRun = concat
          [ let countSlot = "slot" <> textOfInt index
                optional = case native of
                  CoreSumType "Option" [_] -> True
                  _ -> False
                negative = case kind of
                  CoreIntegerType (SignedKind _) -> [countSlot <> " < 0"]
                  _ -> []
                noBuffer = if optional then "answer == NULL && run_count != 0" else "answer == NULL"
                overflow =
                  [ "run_count > (uint64_t)PTRDIFF_MAX / sizeof(" <> abiType element <> ")"
                  , "run_count > ((size_t)PTRDIFF_MAX - sizeof(pudu_items)) / sizeof(pudu_cell)" ]
                buffer = "((const " <> abiType element <> " *)answer)"
                build = unpackNativeRun element buffer "(size_t)run_count" "result_array"
                  <> ["  pudu_foreign_discard_generation(claimed[" <> claimIndex (-1) <> "].generation);"]
                boxed
                  | optional = ["  pudu_box *native_value;", "  if (answer == NULL) {",
                      "    native_value = " <> aggregateHelper "make1" native <> "();", "  } else {"]
                      <> map ("  " <>) build
                      <> ["    native_value = " <> aggregateHelper "make0" native <> "(result_array);",
                          "    " <> released (CoreArrayType element) "result_array", "  }"]
                  | otherwise = build <> ["  pudu_box *native_value = result_array;"]
             in ["  uint64_t run_count = (uint64_t)" <> countSlot <> ";"]
                  <> refuse discardClaims (Text.intercalate " || " (negative <> ["(" <> noBuffer <> ")"] <> overflow))
                    "pudu_fail(result_extent);"
                  <> boxed
          | Just (index, _) <- [run]
          , Just kind <- [lookup index (zip [0 ..] slots)]
          , Just (_, element) <- [returnedRunTypes declared] ]
     in (siteParameters, nativeShim declared (abiType nativeAbi) abiOrder
        <> [ "static pudu_box *" <> wrapperName declared <> "("
            <> Text.intercalate ", " (loanParameter declared <> siteParameters <> [inputParameter declared i kind | (i, kind) <- parameters]) <> ") {"
        , functionCache declared
        ]
        <> ["  (void)noughts;" | lendsText && null textChecks] <> textChecks
        <> directExtentChecks declared
        <> [ "  " <> abiType nativeAbi <> " (*function)(" <> pointerArgs <> ") = ("
            <> abiType nativeAbi <> " (*)(" <> pointerArgs <> "))" <> resolveFunction declared nativeAbi <> ";"
        ]
        <> concatMap (resolveRelease (coreForeignSymbol declared) . snd) releases
        <> map (requireHandle False) handles
        <> receiverChecks declared handles
        <> ["  pudu_foreign_reserve(" <> destructorCount <> ");" | not (null releases)]
        <> ["  (void)missing; (void)invalid;" | textSites]
        <> [ "  " <> abiType (slotAbiType kind) <> " slot" <> textOfInt i <> " = {0};"
           | (i, kind) <- zip [0 ..] slots ]
        <> (if held == 0 then [] else ["  char *held[" <> textOfInt held <> "];", "  size_t held_count = 0;"])
        <> copies
        <> afterNative declared ((if native == CoreUnitType then "" else abiType nativeAbi <> " answer = ") <> call)
        <> (if null releases then [] else
             ["  pudu_foreign_claim claimed[] = {"] <> map claimLine releases
             <> ["  };"] <> refuse [] ("!pudu_foreign_claim_slots(claimed, " <> destructorCount <> ")") "pudu_fail(duplicate);")
        <> concat [refuse discardClaims (field <> " != NULL && !pudu_foreign_text_valid(" <> field <> ")") "pudu_fail(invalid);"
                  | (_, field) <- resultLeaves <> slotLeaves]
        <> concat [refuse discardClaims (field <> " == NULL") ("pudu_foreign_missing_field(missing, "
                    <> cString (coreForeignSymbol declared) <> ", " <> cString label <> ");")
                  | (label, field) <- resultLeaves <> slotLeaves, not (Text.null label)]
        <> [line | isHandle native && not (isOptionalHandle native), line <- refuse discardClaims "answer == NULL" "pudu_fail(none);"]
        <> decodeRun
        <> (case native of
              _ | run /= Nothing -> []
              _ | isHandle native ->
                  let generation = case nativeRelease of
                        Just _ -> "claimed[" <> claimIndex (-1) <> "].generation"
                        Nothing -> "0"
                      boxed = "pudu_foreign_slot_box((uint64_t)(uintptr_t)answer, " <> generation <> ")"
                   in if isOptionalHandle native
                        then ["  pudu_box *held_result = answer == NULL ? NULL : " <> boxed <> ";"]
                          <> optionHandle native "native_value" "held_result"
                        else ["  pudu_box *native_value = " <> boxed <> ";"]
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
        <> [ "  return tuple;", "}", "" ])
  wrapper declared =
    let parameters = zip [0 :: Int ..] (coreForeignParameters declared)
        result = coreForeignResult declared
        ordinary = byValueInputs declared
        held = sum [textLeaves layouts kind | (_, kind@(CoreRecordType _ _)) <- ordinary]
        lendsText = any (carriesText . snd) ordinary
        order = nativeOrder declared [inputCrossing declared index kind | (index, kind) <- parameters] []
        abiParameters = if null order then "void" else Text.intercalate ", " (map fst order)
        pointer = abiType result <> " (*)(" <> abiParameters <> ")"
        resolved = "((" <> pointer <> ")" <> resolveFunction declared result <> ")"
        call = nativeCall declared order
        handles = handleInputs parameters
        claim = coreForeignClaim declared
        release = releaseOf declared
        siteParameters = ["const pudu_site *site"] <> ["const pudu_site *noughts" | lendsText]
          <> concat [["const pudu_site *missing", "const pudu_site *invalid"] | carriesText result]
          <> ["const pudu_site *dead" | not (null handles)]
          <> ["const pudu_site *none" | isHandle result && not (isOptionalHandle result)]
          <> ["const pudu_site *owned" | isHandle result, Just (CoreOwned False _ _) <- [claim]]
          <> extentParameter declared
        checks = map (requireHandle (coreForeignReleases declared)) handles <> receiverChecks declared handles
        textChecks = concat [checkText kind ("a" <> textOfInt index) | (index, kind) <- ordinary]
        heldLines = if held == 0 then [] else ["  char *held[" <> textOfInt held <> "];", "  size_t held_count = 0;"]
        copies = concat
          [ case kind of
              CoreTextType -> ["  char *t" <> textOfInt index <> " = pudu_foreign_text_in(a" <> textOfInt index <> ");"]
              CoreRecordType _ _ -> ["  " <> abiType kind <> " r" <> textOfInt index <> " = pudu_foreign_pack_" <> suffix kind
                <> "(a" <> textOfInt index <> ", " <> (if held == 0 then "NULL, NULL" else "held, &held_count") <> ");"]
              _ -> []
          | (index, kind) <- ordinary ]
        releases = ["  free(t" <> textOfInt index <> ");" | (index, CoreTextType) <- parameters]
          <> ["  for (size_t i = 0; i < held_count; ++i) free(held[i]);" | held /= 0]
        body = case result of
          CoreUnitType -> afterNative declared call <> releases <> ["  return 0;"]
          CoreTextType -> afterNative declared ("const char *raw = " <> call)
            <> [ "  if (raw == NULL || !pudu_foreign_text_valid(raw)) {"
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
             in afterNative declared (abiType result <> " raw = " <> call)
                <> ["  (void)missing; (void)invalid;"]
                <> concat [reject (field <> " != NULL && !pudu_foreign_text_valid(" <> field <> ")") "pudu_fail(invalid);"
                          | (_, field) <- leaves]
                <> concat [reject (field <> " == NULL")
                    ("pudu_foreign_missing_field(missing, " <> cString (coreForeignSymbol declared) <> ", " <> cString label <> ");")
                          | (label, field) <- leaves]
                <> ["  pudu_box *answer = pudu_foreign_unpack_" <> suffix result <> "(raw);"]
                <> releases <> ["  return answer;"]
          _ | isHandle result ->
                let optional = isOptionalHandle result
                    none = if optional then "NULL" else "none"
                    owned = if any (== "const pudu_site *owned") siteParameters then "owned" else "NULL"
                    boxed = "pudu_foreign_handle_result(" <> none <> ", " <> owned <> ", " <> claimMode claim
                      <> ", " <> maybe "NULL" releaserName release <> ", answer)"
                 in afterNative declared ("void *answer = " <> call) <> releases <>
                      (if optional
                        then ["  pudu_box *held_result = answer == NULL ? NULL : " <> boxed <> ";"]
                          <> optionHandle result "native_value" "held_result" <> ["  return native_value;"]
                        else ["  return " <> boxed <> ";"])
          _ -> afterNative declared (abiType result <> " answer = " <> call) <> releases <> ["  return " <> fromAbi result "answer" <> ";"]
     in (siteParameters, nativeShim declared (abiType result) order
        <> [ "static " <> foreignCellType result <> " " <> wrapperName declared <> "("
            <> Text.intercalate ", " (loanParameter declared <> siteParameters <> [inputParameter declared index kind | (index, kind) <- parameters]) <> ") {"
        , functionCache declared ]
        <> ["  (void)noughts;" | lendsText && null textChecks]
        <> textChecks
        <> directExtentChecks declared
        <> ["  " <> abiType result <> " (*function)(" <> abiParameters <> ") = " <> resolved <> ";"]
        <> maybe [] (resolveRelease (coreForeignSymbol declared)) release
        <> checks
        <> ["  pudu_foreign_reserve(1);" | Just _ <- [release]]
        <> heldLines
        <> copies
        <> body
        <> ["}", ""])
  isHandle kind = foreignHandleType kind /= Nothing
  suffix kind = Text.drop (Text.length "pudu_foreign_record_") (abiType kind)

initializesReceiver :: CoreForeign -> Bool
initializesReceiver declared =
  maybe False objectiveCInitializer (coreForeignObjectiveC declared)
    && foreignHandleType (maybe (coreForeignResult declared) fst (slotResult declared)) /= Nothing

callbackScopeNeeded :: CoreForeign -> Bool
callbackScopeNeeded declared = coreForeignCanReenter declared || not (null (coreForeignCallbacks declared))

yieldsWithHandles :: CoreForeign -> Bool
yieldsWithHandles declared =
  callbackScopeNeeded declared
    && any ((/= Nothing) . foreignHandleType) (coreForeignParameters declared)

crossingTypes :: CoreForeign -> [CoreType]
crossingTypes declared = map pointeeType (coreForeignParameters declared)
  <> [element | Just (_, element) <- [returnedRunTypes declared]] <> case slotResult declared of
  Just (native, slots) -> native : slots
  Nothing -> [coreForeignResult declared]

returnedRunTypes :: CoreForeign -> Maybe (CoreType, CoreType)
returnedRunTypes declared = do
  _ <- coreForeignReturnedRun declared
  (native, _) <- slotResult declared
  case native of
    CoreArrayType element -> Just (native, element)
    CoreSumType "Option" [CoreArrayType element] -> Just (native, element)
    _ -> Nothing

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
releaseOf declared = case (foreignHandleType nativeAbi, coreForeignClaim declared) of
  (Just _, Just (CoreOwned _ symbol answer)) -> Just (coreForeignLibrary declared, coreForeignVersion declared, symbol, answer)
  _ -> Nothing
 where
  native = maybe (coreForeignResult declared) fst (slotResult declared)
  nativeAbi = maybe native snd (coreForeignReturnedRun declared)

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
  CoreSumType "Option" [CoreHandleType _ _] -> ["host_foreign_store"]
  _ -> []

{-| The parts converting an answer back to its cell. -}
resultNeeds :: CoreType -> [Text]
resultNeeds kind = case kind of
  CoreIntegerType (SignedKind _) -> ["kernel_int"]
  CoreIntegerType _ -> ["make"]
  CoreFloatType _ -> ["float_encode"]
  CoreTextType -> ["host_foreign_text_out"]
  CoreHandleType _ _ -> ["host_foreign_store"]
  CoreSumType "Option" [handle@CoreHandleType{}] ->
    ["host_foreign_store", aggregateNeed "make0" kind, aggregateNeed "make1" kind,
      aggregateNeed "drop" kind, aggregateNeed "drop" handle]
  _ -> []
