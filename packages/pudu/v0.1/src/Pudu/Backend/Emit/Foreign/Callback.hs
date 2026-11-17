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
  ( CoreCallbackFallback (..), CoreCallbackOperation (..), CoreCallbackSignature (..), CoreCallbackSlot (..)
  , CoreForeign (..), CoreLayout (..), CoreType (..), CoreVariant (..) )
import Pudu.Core.Frame
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))

{-| One position of a foreign function's native parameter list: a Pudu
    argument by index, an output slot by index, or a callback context, named
    by the index of the Pudu argument carrying its token. -}
data NativeArgument
  = NativeInput !Int
  | NativeSlot !Int
  | NativeContext !Int
  deriving stock (Eq, Show)

{-| The native parameter order of a declaration. Output slots and callback
    contexts occupy their declared positions; the Pudu arguments fill the
    rest in order. -}
nativeArguments :: CoreForeign -> [NativeArgument]
nativeArguments declared = walk 0 0 0
 where
  slots = Set.fromList (coreForeignSlotPositions declared)
  contexts = Map.fromList
    [ (coreCallbackContextIndex slot, coreCallbackFunctionIndex slot) | slot <- coreForeignCallbacks declared ]
  blocked position = Set.member position slots || Map.member position contexts
  total = length (coreForeignParameters declared) + Set.size slots + Map.size contexts
  inputAt position = length [() | earlier <- [0 .. position - 1], not (blocked earlier)]
  walk position input slot
    | position >= total = []
    | Set.member position slots = NativeSlot slot : walk (position + 1) input (slot + 1)
    | Just function <- Map.lookup position contexts = NativeContext (inputAt function) : walk (position + 1) input slot
    | otherwise = NativeInput input : walk (position + 1) (input + 1) slot

{-| Every callback signature a module's frames register or cross, each once. -}
callbackSignaturesOf :: FrameModule -> [CoreCallbackSignature]
callbackSignaturesOf source = Set.toList $ Set.fromList $
  [ signature | FrameCallback (CoreCallbackRegister signature) _ <- shapes source ]
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
trampolineName signature = "pudu_trampoline_" <> mangleKey (coreCallbackOwner signature)

trampolineType :: CoreCallbackSignature -> Text
trampolineType signature = "pudu_trampoline_type_" <> mangleKey (coreCallbackOwner signature)

unregisterHelper :: CoreType -> Text
unregisterHelper kind = "pudu_callback_unregister_" <> mangle kind

{-| A registration or an unregistration as the value stored in its slot. -}
callbackOperation :: CoreCallbackOperation -> CoreType -> FrameSlot -> Text -> (Text, [Text])
callbackOperation operation result operand cell = case operation of
  CoreCallbackRegister signature ->
    let handler = frameSlotType operand
     in ( "pudu_callback_register(&" <> callbackIdentity signature <> ", " <> cell <> ", "
            <> aggregateHelper "drop" handler <> ")"
        , ["host_callback", aggregateNeed "drop" handler] )
  CoreCallbackUnregister -> (unregisterHelper result <> "(" <> cell <> ")", ["host_callback"])

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
callbackTrampolines :: Layouts -> [CoreCallbackSignature] -> [CoreType] -> [Text]
callbackTrampolines layouts signatures results =
  concatMap trampoline signatures <> concatMap unregistration results
 where
  trampoline signature =
    let key = mangleKey (coreCallbackOwner signature)
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
        cellLines =
          [ "  cells[" <> textOfInt position <> "]." <> cellName kind <> " = " <> argumentCell kind ("call->p" <> textOfInt index) <> ";"
          | (position, (index, kind)) <- zip [0 :: Int ..] values ]
        releases =
          [ "  " <> statement
          | (position, (_, kind)) <- zip [0 :: Int ..] values
          , let statement = released kind ("cells[" <> textOfInt position <> "]." <> cellName kind)
          , not (Text.null statement) ]
     in [ "static const char " <> callbackIdentity signature <> " = 0;"
        , "typedef " <> answer <> " (*" <> trampolineType signature <> ")(" <> typeList <> ");"
        , "typedef struct {" ]
        <> [ "  " <> abiOf kind <> " p" <> textOfInt index <> ";" | (index, kind) <- parameters ]
        <> [ "  " <> answer <> " answer;" | result /= CoreUnitType ]
        <> [ "  int unused;" | null parameters && result == CoreUnitType ]
        <> [ "} " <> call <> ";"
           , "static void " <> body <> "(pudu_box *handler, void *raw) {"
           , "  " <> call <> " *call = raw;"
           , "  pudu_cell cells[" <> textOfInt (max 1 cells) <> "];" ]
        <> [ "  (void)call;" | null values && result == CoreUnitType ]
        <> cellLines
        <> [ "  pudu_cell answer = pudu_run_callback(handler, cells, " <> textOfInt cells <> ", NULL);" ]
        <> (if result == CoreUnitType then ["  (void)answer;"]
              else ["  call->answer = " <> toAbi result ("answer." <> cellName result) <> ";"])
        <> releases
        <> [ "}"
           , "static " <> answer <> " " <> trampolineName signature <> "("
               <> (if null declared then "void" else Text.intercalate ", " declared) <> ") {"
           , "  " <> call <> " call;"
           , "  memset(&call, 0, sizeof call);" ]
        <> [ "  call.p" <> textOfInt index <> " = p" <> textOfInt index <> ";" | (index, Just _) <- parameters ]
        <> [ "  if (!pudu_callback_invoke((uintptr_t)" <> context <> ", &" <> callbackIdentity signature
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
