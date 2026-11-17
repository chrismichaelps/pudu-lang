{-| @Pudu.Backend.Emit.Foreign.Delegate — Objective-C classes a program defines
    at run time. Each method is a C function taking the object and selector
    where its group member's trampoline takes the context; it reads the
    registration key from the object's extra bytes and enters the trampoline.
    A constructor defines the class on first use and claims a new instance as
    an owned handle released through the runtime's release message. -}
module Pudu.Backend.Emit.Foreign.Delegate
  ( delegatesOf
  , delegateDefinitions
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Foreign.Callback (callbackIdentity, delegateConstructorName, trampolineName)
import Pudu.Backend.Emit.ForeignAbi (abiType)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreCallbackOperation (..), CoreCallbackSignature (..), CoreDelegate (..), CoreType (..))
import Pudu.Core.Frame
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..))

{-| Every delegate a module's frames construct, each once. -}
delegatesOf :: FrameModule -> [CoreDelegate]
delegatesOf source = Set.toList $ Set.fromList
  [ delegate
  | function <- frameModuleFunctions source
  , block <- frameFunctionBlocks function
  , FrameStore _ value <- frameBlockInstructions block
  , FrameCallback (CoreDelegateNew delegate) _ <- [frameValueShape value] ]

delegateDefinitions :: [CoreDelegate] -> [Text]
delegateDefinitions delegates =
  concatMap method (Map.elems members) <> concatMap constructor delegates
 where
  members = Map.fromList
    [ (methodName signature, signature) | delegate <- delegates, (_, signature) <- coreDelegateMethods delegate ]
  method signature =
    let parameters = drop 1 (zip [0 :: Int ..] (coreCallbackArguments signature))
        abiOf = maybe "void *" abiType
        declared = "void *self" : "void *command" : [abiOf kind <> " p" <> textOfInt index | (index, kind) <- parameters]
        forwarded = "(void *)pudu_delegate_key(self)" : ["p" <> textOfInt index | (index, _) <- parameters]
        returning = if coreCallbackResult signature == CoreUnitType then "  " else "  return "
     in [ "static " <> abiType (coreCallbackResult signature) <> " " <> methodName signature
            <> "(" <> Text.intercalate ", " declared <> ") {"
        , "  (void)command;"
        , returning <> trampolineName signature <> "(" <> Text.intercalate ", " forwarded <> ");"
        , "}", "" ]
  constructor delegate =
    let methods = coreDelegateMethods delegate
        count = textOfInt (length methods)
        quoted text = "\"" <> text <> "\""
        list items = "{" <> Text.intercalate ", " items <> "}"
        className = coreDelegateClass delegate
     in [ "static pudu_box *" <> delegateConstructorName delegate <> "(uintptr_t key) {"
        , "  static const pudu_site site = {.file = \"<foreign delegate>\", .line = 1, .column = 1, .code = \"E7001\","
        , "    .message = \"delegate " <> className <> " could not be created\","
        , "    .help = \"a delegate needs an Apple platform and a live token of its callback group\"};"
        , "  static void *type = NULL;"
        , "  static const char *const selectors[] = " <> list (map (quoted . fst) methods) <> ";"
        , "  static const char *const encodings[] = " <> list (map (quoted . encoding . snd) methods) <> ";"
        , "  void *const methods[] = " <> list ["(void *)" <> methodName signature | (_, signature) <- methods] <> ";"
        , "  pudu_foreign_reserve(1);"
        , "  pudu_callback_entry *entry = pudu_callback_lease(key, &" <> callbackIdentity (coreDelegateGroup delegate) <> ");"
        , "  if (entry == NULL) pudu_fail(&site);"
        , "  if (type == NULL) type = pudu_delegate_class(&site, " <> quoted className <> ", " <> count
            <> ", selectors, methods, encodings);"
        , "  void *object = type == NULL ? NULL : pudu_delegate_instance(&site, type, key);"
        , "  pudu_callback_unlease(entry);"
        , "  return pudu_foreign_handle_result(&site, &site, 1, pudu_delegate_release, object);"
        , "}", "" ]
  methodName signature = "pudu_delegate_method_" <> Text.drop (Text.length "pudu_trampoline_") (trampolineName signature)

{-| The Objective-C type encoding of a method: result, object, selector, then
    each argument. The checker admits no record argument. -}
encoding :: CoreCallbackSignature -> Text
encoding signature =
  part (coreCallbackResult signature) <> "@:" <> foldMap part [kind | Just kind <- drop 1 (coreCallbackArguments signature)]
 where
  part kind = case kind of
    CoreIntegerType (SignedKind 8) -> "c"
    CoreIntegerType (SignedKind 16) -> "s"
    CoreIntegerType (SignedKind 32) -> "i"
    CoreIntegerType (UnsignedKind 8) -> "C"
    CoreIntegerType (UnsignedKind 16) -> "S"
    CoreIntegerType (UnsignedKind 32) -> "I"
    CoreIntegerType (UnsignedKind _) -> "Q"
    CoreIntegerType PlatformUnsigned -> "Q"
    CoreIntegerType _ -> "q"
    CoreFloatType Float32Width -> "f"
    CoreFloatType _ -> "d"
    CoreBoolType -> "B"
    CoreTextType -> "*"
    CoreHandleType _ _ -> "@"
    CoreUnitType -> "v"
    _ -> "^v"
