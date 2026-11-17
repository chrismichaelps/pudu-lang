{-| @Pudu.Backend.Emit.Foreign.Callback — the native side of foreign
    callbacks. Each callback declaration a program registers or crosses gets
    one typed C trampoline: a foreign library calls it with the declared
    arguments and the context it was handed, and the trampoline admits the
    call through the registration store, converts the arguments into cells
    under the run gate, and runs the registered handler. A call the store
    refuses answers the declaration's fallback. -}
module Pudu.Backend.Emit.Foreign.Callback
  ( NativeArgument (..)
  , nativeArguments
  , callbackSignaturesOf
  , callbackUnregisterResults
  , callbackTrampolines
  , callbackNeeds
  , callbackArgumentTypes
  , callbackOperation
  , callbackIdentity
  , trampolineName
  , trampolineType
  , blockInvokeName
  , blockSignatures
  , delegateConstructorName
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed, cellName, mangle, mangleKey, released)
import Pudu.Backend.Emit.ForeignAbi (Layouts, abiType, fromAbi, toAbi)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core
  ( CoreCallbackFallback (..), CoreCallbackOperation (..), CoreCallbackSignature (..), CoreCallbackSlot (..), CoreDelegate (..)
  , CoreForeign (..), CoreLayout (..), CoreType (..), CoreVariant (..) )
import Pudu.Core.Frame
import Pudu.Foreign.Callback (CallbackPlacement (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))

{-| One position of a foreign function's native parameter list: a Pudu
    argument by index, an output slot by index, or a callback context, named
    by the index of the Pudu argument carrying its token. -}
data NativeArgument
  = NativeInput !Int
  | NativeSlot !Int
  | NativeContext !Int
  | NativeTrampoline !CoreCallbackSignature
  | NativeBlock !Int !CoreCallbackSignature
  deriving stock (Eq, Show)

{-| The native parameter order of a declaration. Output slots and callback
    contexts occupy their declared positions; the Pudu arguments fill the
    rest in order. -}
nativeArguments :: CoreForeign -> [NativeArgument]
nativeArguments declared = walk 0 0 0
 where
  slots = Set.fromList (coreForeignSlotPositions declared)
  callbacks = coreForeignCallbacks declared
  contexts = Map.fromList
    [(context, function) | slot <- callbacks, PairedCallback function context <- [coreCallbackPlacement slot]]
  projections = Map.fromList
    [(function, coreCallbackSignature slot) | slot <- callbacks, StaticTrampoline function <- [coreCallbackPlacement slot]]
  registrations = Set.fromList
    [context | slot <- callbacks, RegistrationContext context <- [coreCallbackPlacement slot]]
  blocks = Map.fromList
    [(position, coreCallbackSignature slot) | slot <- callbacks, BlockCallback position <- [coreCallbackPlacement slot]]
  blocked position = Set.member position slots || Map.member position contexts || Map.member position projections
  total = length (coreForeignParameters declared) + Set.size slots + Map.size contexts + Map.size projections
  inputAt position = length [() | earlier <- [0 .. position - 1], not (blocked earlier)]
  walk position input slot
    | position >= total = []
    | Set.member position slots = NativeSlot slot : walk (position + 1) input (slot + 1)
    | Just function <- Map.lookup position contexts = NativeContext (inputAt function) : walk (position + 1) input slot
    | Just signature <- Map.lookup position projections = NativeTrampoline signature : walk (position + 1) input slot
    | Set.member position registrations = NativeContext input : walk (position + 1) (input + 1) slot
    | Just signature <- Map.lookup position blocks = NativeBlock input signature : walk (position + 1) (input + 1) slot
    | otherwise = NativeInput input : walk (position + 1) (input + 1) slot

{-| Every callback signature a module's frames register or cross, each once. -}
callbackSignaturesOf :: FrameModule -> [CoreCallbackSignature]
callbackSignaturesOf source = Set.toList $ Set.fromList $
  [ signature | FrameCallback operation _ <- shapes source
    , signature <- case operation of
        CoreCallbackRegister single -> [single]
        CoreCallbackRegisterGroup group _ -> [group]
        CoreCallbackUnregister -> []
        CoreDelegateNew delegate -> map snd (coreDelegateMethods delegate) ]
    <> [ coreCallbackSignature slot | FrameForeign declared _ <- shapes source, slot <- coreForeignCallbacks declared ]

{-| The result types of every `unregister` a module's frames perform. -}
callbackUnregisterResults :: FrameModule -> [CoreType]
callbackUnregisterResults source = Set.toList $ Set.fromList
  [ frameValueType value
  | function <- frameModuleFunctions source
  , block <- frameFunctionBlocks function
  , FrameStore _ value <- frameBlockInstructions block
  , FrameCallback CoreCallbackUnregister _ <- [frameValueShape value] ]

shapes :: FrameModule -> [FrameValueShape]
shapes source =
  [ frameValueShape value
  | function <- frameModuleFunctions source
  , block <- frameFunctionBlocks function
  , FrameStore _ value <- frameBlockInstructions block ]

callbackIdentity :: CoreCallbackSignature -> Text
callbackIdentity signature = "pudu_callback_identity_" <> mangleKey (coreCallbackOwner signature)

trampolineName :: CoreCallbackSignature -> Text
trampolineName signature = "pudu_trampoline_" <> trampolineKey signature

trampolineType :: CoreCallbackSignature -> Text
trampolineType signature = "pudu_trampoline_type_" <> trampolineKey signature

trampolineKey :: CoreCallbackSignature -> Text
trampolineKey signature =
  mangleKey (coreCallbackOwner signature <> maybe "" (("." <>) . snd) (coreCallbackProjection signature))

blockInvokeName :: CoreCallbackSignature -> Text
blockInvokeName signature = "pudu_block_invoke_" <> trampolineKey signature

{-| The signatures these declarations hand over as blocks, each once. -}
blockSignatures :: [CoreForeign] -> [CoreCallbackSignature]
blockSignatures declarations = Set.toList $ Set.fromList
  [ coreCallbackSignature slot
  | declared <- declarations
  , slot <- coreForeignCallbacks declared
  , BlockCallback _ <- [coreCallbackPlacement slot] ]

delegateConstructorName :: CoreDelegate -> Text
delegateConstructorName delegate = "pudu_delegate_new_" <> mangleKey (coreDelegateClass delegate)

unregisterHelper :: CoreType -> Text
unregisterHelper kind = "pudu_callback_unregister_" <> mangle kind

{-| A registration or an unregistration as the value stored in its slot. -}
callbackOperation :: CoreCallbackOperation -> CoreType -> FrameSlot -> Text -> (Text, [Text])
callbackOperation operation result operand cell = case operation of
  CoreCallbackRegister signature ->
    let handler = frameSlotType operand
     in ( "pudu_callback_register(&" <> callbackIdentity signature <> ", " <> cell <> ", "
            <> aggregateHelper "drop" handler <> ", NULL, 0)"
        , ["host_callback", aggregateNeed "drop" handler] )
  CoreCallbackRegisterGroup signature fields ->
    let handler = frameSlotType operand
        offsets = "(const size_t[]){" <> Text.intercalate ", " (map textOfInt fields) <> "}"
     in ( "pudu_callback_register(&" <> callbackIdentity signature <> ", " <> cell <> ", "
            <> aggregateHelper "drop" handler <> ", " <> offsets <> ", " <> textOfInt (length fields) <> ")"
        , ["host_callback", aggregateNeed "drop" handler] )
  CoreCallbackUnregister -> (unregisterHelper result <> "(" <> cell <> ")", ["host_callback"])
  CoreDelegateNew delegate ->
    (delegateConstructorName delegate <> "(" <> cell <> ")", ["host_callback", "host_objc_delegate"])

{-| The store and the conversions the trampolines and unregistrations use
    beyond the scalar crossings, which the foreign wrappers' needs cover. -}
callbackNeeds :: Layouts -> [CoreCallbackSignature] -> [CoreType] -> [Text]
callbackNeeds layouts signatures results =
  ["host_callback" | not (null signatures) || not (null results)]
    <> concatMap argumentNeeds (concatMap callbackArgumentTypes signatures)
    <> concatMap resultNeeds results
 where
  argumentNeeds kind = case kind of
    CoreTextType -> ["text_copy", "text_release"]
    CoreBytesType -> ["bytes_wrap", "text_copy", aggregateNeed "drop" kind]
    CoreHandleType _ _ -> [aggregateNeed "drop" kind]
    CoreRecordType _ _ -> [aggregateNeed "drop" kind]
    _ -> []
  resultNeeds kind = case Map.lookup kind layouts of
    Just (CoreSumLayout variants) ->
      [aggregateNeed ("make" <> textOfInt tag) kind | (tag, _) <- zip [0 :: Int ..] variants]
    _ -> []

callbackArgumentTypes :: CoreCallbackSignature -> [CoreType]
callbackArgumentTypes signature = [kind | Just kind <- coreCallbackArguments signature]

{-| The identity of each callback declaration, its trampoline and the
    unregistration helpers. An argument is held in its native form until the
    store admits the call; it becomes a cell only under the run gate, and a
    cell it owns is released after the handler returns. -}
callbackTrampolines :: Layouts -> [CoreCallbackSignature] -> [CoreCallbackSignature] -> [CoreType] -> [Text]
callbackTrampolines layouts signatures blocks results =
  identities <> byteExtentHelper <> concatMap trampoline signatures <> concatMap blockInvoke blocks
    <> concatMap unregistration results
 where
  -- The block arrives first, where the trampoline takes its context.
  blockInvoke signature =
    let parameters = drop 1 (zip [0 :: Int ..] (coreCallbackArguments signature))
        abiOf = maybe "void *" abiType
        declared = "void *block" : [abiOf kind <> " p" <> textOfInt index | (index, kind) <- parameters]
        forwarded = "(void *)((const pudu_foreign_block *)block)->key" : ["p" <> textOfInt index | (index, _) <- parameters]
        answer = abiType (coreCallbackResult signature)
        returning = if coreCallbackResult signature == CoreUnitType then "  " else "  return "
     in [ "static " <> answer <> " " <> blockInvokeName signature <> "(" <> Text.intercalate ", " declared <> ") {"
        , returning <> trampolineName signature <> "(" <> Text.intercalate ", " forwarded <> ");"
        , "}", "" ]
  identities =
    [ "static const char " <> identity <> " = 0;"
    | identity <- Set.toList (Set.fromList (map callbackIdentity signatures)) ]
  byteExtentHelper
    | all (null . coreCallbackByteLengths) signatures = []
    | otherwise =
        [ "static int pudu_callback_valid_bytes(const void *data, uint64_t bytes) {"
        , "  return bytes <= (uint64_t)PTRDIFF_MAX - sizeof(pudu_text_owner) && (data != NULL || bytes == 0);"
        , "}", "" ]
  trampoline signature =
    let key = trampolineKey signature
        parameters = zip [0 :: Int ..] (coreCallbackArguments signature)
        result = coreCallbackResult signature
        call = "pudu_callback_call_" <> key
        body = "pudu_callback_body_" <> key
        abiOf = maybe "void *" abiType
        declared = [abiOf kind <> " p" <> textOfInt index | (index, kind) <- parameters]
        typeList = if null parameters then "void" else Text.intercalate ", " (map (abiOf . snd) parameters)
        values = [(index, kind) | (index, Just kind) <- parameters]
        context = case [index | (index, Nothing) <- parameters] of
          index : _ -> "p" <> textOfInt index
          [] -> "NULL"
        answer = abiType result
        cells = length values
        lengths = Map.fromList (coreCallbackByteLengths signature)
        native index = "call->p" <> textOfInt index
        byteCount index = "(uint64_t)" <> native index
        checkRun (run, count) =
          "  if (!pudu_callback_valid_bytes(" <> native run <> ", " <> byteCount count <> "))"
        toCell index kind = case Map.lookup index lengths of
          Just count -> "pudu_bytes_wrap(pudu_text_copy(" <> native index <> " == NULL ? \"\" : "
            <> "(const char *)" <> native index <> ", (size_t)" <> byteCount count <> "))"
          Nothing -> argumentCell kind (native index)
        cellLines =
          [ "  cells[" <> textOfInt position <> "]." <> cellName kind <> " = " <> toCell index kind <> ";"
          | (position, (index, kind)) <- zip [0 :: Int ..] values ]
        releases =
          [ "  " <> statement
          | (position, (_, kind)) <- zip [0 :: Int ..] values
          , let statement = released kind ("cells[" <> textOfInt position <> "]." <> cellName kind)
          , not (Text.null statement) ]
     in [ "typedef " <> answer <> " (*" <> trampolineType signature <> ")(" <> typeList <> ");"
        , "typedef struct {" ]
        <> [ "  " <> abiOf kind <> " p" <> textOfInt index <> ";" | (index, kind) <- parameters ]
        <> [ "  " <> answer <> " answer;" | result /= CoreUnitType ]
        <> [ "  int unused;" | null parameters && result == CoreUnitType ]
        <> [ "} " <> call <> ";"
           , "static void " <> body <> "(pudu_box *handler, void *raw) {"
           , "  " <> call <> " *call = raw;"
           , "  pudu_cell cells[" <> textOfInt (max 1 cells) <> "];" ]
        <> [ "  (void)call;" | null values && result == CoreUnitType ]
        <> (if Map.null lengths then [] else
              [ "  static const pudu_site site = {.code = \"E7017\", .file = \"<foreign callback>\", .line = 1, .column = 1};"
              , "  static const char message[] = \"invalid input to a foreign callback\";" ]
              <> concatMap (\run -> [checkRun run, "    pudu_fail_message(&site, message, sizeof message - 1);"])
                   (Map.toList lengths))
        <> cellLines
        <> [ "  pudu_cell answer = pudu_run_callback(handler, cells, " <> textOfInt cells <> ", NULL);" ]
        <> (if result == CoreUnitType then ["  (void)answer;"]
              else ["  call->answer = " <> toAbi result ("answer." <> cellName result) <> ";"])
        <> releases
        <> [ "}"
           , "PUDU_OPTIONAL static " <> answer <> " " <> trampolineName signature <> "("
               <> (if null declared then "void" else Text.intercalate ", " declared) <> ") {"
           , "  " <> call <> " call;"
           , "  memset(&call, 0, sizeof call);" ]
        <> [ "  call.p" <> textOfInt index <> " = p" <> textOfInt index <> ";" | (index, Just _) <- parameters ]
        <> [ "  if (!pudu_callback_invoke((uintptr_t)" <> context <> ", &" <> callbackIdentity signature
               <> ", " <> maybe "SIZE_MAX" (textOfInt . fst) (coreCallbackProjection signature)
               <> ", " <> body <> ", &call))"
           , "    return" <> fallback result (coreCallbackFallback signature) <> ";" ]
        <> [ if result == CoreUnitType then "  return;" else "  return call.answer;"
           , "}", "" ]
  argumentCell kind native = case kind of
    CoreTextType -> "pudu_text_copy(" <> native <> " == NULL ? \"\" : " <> native <> ", "
      <> native <> " == NULL ? 0 : strlen(" <> native <> "))"
    CoreHandleType _ _ -> "pudu_foreign_slot_box((uint64_t)(uintptr_t)" <> native <> ", 0)"
    CoreRecordType _ _ -> "pudu_foreign_unpack_" <> Text.drop (Text.length "pudu_foreign_record_") (abiType kind) <> "(" <> native <> ")"
    _ -> fromAbi kind native
  fallback result held = case (result, held) of
    (CoreUnitType, _) -> ""
    (_, CallbackFallbackBool flag) -> if flag then " 1" else " 0"
    (CoreFloatType width, CallbackFallbackFloat bits) ->
      let double = "((union { uint64_t bits; double value; }){.bits = UINT64_C(0x" <> Text.pack (showHex bits "") <> ")}).value"
       in " " <> (if width == Float32Width then "(float)" else "") <> double
    (CoreIntegerType (SignedKind _), CallbackFallbackInteger value)
      | value < 0 -> " (" <> abiType result <> ")(-INT64_C(" <> Text.pack (show (negate value - 1)) <> ") - 1)"
      | otherwise -> " (" <> abiType result <> ")INT64_C(" <> Text.pack (show value) <> ")"
    (_, CallbackFallbackInteger value) -> " (" <> abiType result <> ")UINT64_C(" <> Text.pack (show value) <> ")"
    _ -> " 0"
  unregistration kind = case Map.lookup kind layouts of
    Just (CoreSumLayout variants)
      | [(okTag, ok)] <- named "Ok" variants
      , [(errTag, _)] <- named "Err" variants ->
          [ "static pudu_box *" <> unregisterHelper kind <> "(uintptr_t key) {"
          , "  pudu_text failure;"
          , "  if (pudu_callback_unregister(key, &failure))"
          , "    return " <> aggregateHelper ("make" <> textOfInt okTag) kind <> "("
              <> Text.intercalate ", " ["0" | _ <- coreVariantFields ok] <> ");"
          , "  pudu_box *answer = " <> aggregateHelper ("make" <> textOfInt errTag) kind <> "(failure);"
          , "  pudu_text_release(failure);"
          , "  return answer;"
          , "}", "" ]
    _ -> []
  named name variants = [(tag, variant) | (tag, variant) <- zip [0 :: Int ..] variants, coreVariantName variant == name]
