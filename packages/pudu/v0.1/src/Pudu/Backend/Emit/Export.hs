{-| @Pudu.Backend.Emit.Export — one C function per exported Pudu function of
    an embedded library, entered through the frame engine on the thread that
    started the program. -}
module Pudu.Backend.Emit.Export (ExportSection (..), exportSection) where

import Data.List (nub)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (cellName)
import Pudu.Backend.Emit.Foreign (parameterNeeds, resultNeeds)
import Pudu.Backend.Emit.ForeignAbi (abiType, fromAbi, mangle, toAbi)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreType (..))
import Pudu.Core.Frame (FrameFault (..), FrameFunction (..), FrameSlot (..))
import Pudu.IntegerLiteral (IntegerKind (..))

{-| @Backend.Emit.Export.Section — the wrappers, the prototypes a header
    declares, and the runtime parts their conversions select. -}
data ExportSection = ExportSection
  { exportCode :: ![Text]
  , exportPrototypes :: ![Text]
  , exportNeeds :: ![Text]
  }
  deriving stock (Eq, Show)

{-| The wrappers for the exports named by key, over the indexed frame
    functions; an export in the direct set is one C call to its stack-frame
    entry. A module without exports yields an empty section. -}
exportSection :: Set Text -> [(Int, FrameFunction)] -> [Text] -> Either FrameFault ExportSection
exportSection _ _ [] = Right (ExportSection [] [] [])
exportSection direct indexed keys = do
  found <- traverse locate keys
  wrappers <- traverse (wrapper direct) found
  pure ExportSection
    { exportCode = admission <> concatMap fst wrappers
    , exportPrototypes = map snd wrappers
    , exportNeeds = nub (concat [concatMap resultNeeds (parameterTypes function) <> parameterNeeds (frameFunctionResult function) | (_, function) <- found])
    }
 where
  locate key = case [entry | entry@(_, function) <- indexed, frameFunctionName function == key] of
    [entry] -> Right entry
    _ -> Left (FrameFault Nothing ("the exported function '" <> key <> "' without a lowered body"))

parameterTypes :: FrameFunction -> [CoreType]
parameterTypes = map frameSlotType . frameFunctionParameters

-- The runtime belongs to the thread that completed the start; a call is a plain
-- frame run under the same hooks the entry installs.
admission :: [Text]
admission =
  [ "static _Noreturn void pudu_export_misuse(const char *name, const char *problem) {"
  , "  (void)fprintf(stderr, \"pudu: pudu_export_%s was called %s\\n\", name, problem);"
  , "  abort();"
  , "}"
  , "static void pudu_export_enter(const char *name) {"
  , "  if (!atomic_load_explicit(&pudu_program_ready, memory_order_acquire))"
  , "    pudu_export_misuse(name, \"before pudu_program_run returned\");"
  , "  if (!pthread_equal(pudu_program_owner, pthread_self()))"
  , "    pudu_export_misuse(name, \"from a thread other than the one that ran pudu_program_run\");"
  , "  if (pudu_active_frame != NULL) pudu_export_misuse(name, \"while Pudu is running a call\");"
  , "  /* Pudu writes its descriptors directly; what the host already buffered"
  , "     goes first, so both interleave in call order. */"
  , "  (void)fflush(stdout);"
  , "  (void)fflush(stderr);"
  , "  pudu_cleanup_hook = pudu_unwind_frames;"
  , "  pudu_blame_hook = pudu_blamed_site;"
  , "  pudu_frame_depth = 1;"
  , "}"
  , "static void pudu_export_leave(void) {"
  , "  pudu_cleanup_hook = NULL;"
  , "  pudu_blame_hook = NULL;"
  , "  pudu_program_flush();"
  , "}"
  ]

wrapper :: Set Text -> (Int, FrameFunction) -> Either FrameFault ([Text], Text)
wrapper direct (identity, function) = do
  mapM_ (crossing "parameter") (frameFunctionParameters function)
  result <- resultType
  let name = mangle (Text.takeWhileEnd (/= '.') (frameFunctionName function))
      parameters = zip [0 :: Int ..] (parameterTypes function)
      count = length parameters
      argument index = "p" <> textOfInt index
      signature = result <> " pudu_export_" <> name <> "("
        <> (if null parameters then "void" else Text.intercalate ", " [abiType kind <> " " <> argument index | (index, kind) <- parameters])
        <> ")"
      arguments
        | count == 0 = "NULL"
        | otherwise = "pudu_arguments"
      called
        | Set.member (frameFunctionName function) direct =
            [ "  pudu_result = pudu_direct_" <> textOfInt identity <> "(" <> arguments <> ");" ]
        | otherwise =
            [ "  pudu_active_frame = pudu_new_frame(" <> textOfInt identity <> ", " <> arguments <> ", " <> textOfInt count <> ");"
            , "  pudu_result = pudu_run_active();" ]
      returned = case frameFunctionResult function of
        CoreUnitType -> ["  (void)pudu_result;"]
        kind -> ["  return " <> toAbi kind ("pudu_result." <> cellName kind) <> ";"]
      body =
        [ signature <> ";"
        , signature <> " {" ]
        <> [ "  pudu_cell pudu_arguments[" <> textOfInt count <> "];" | count > 0 ]
        <> [ "  pudu_cell pudu_result;"
           , "  pudu_export_enter(\"" <> name <> "\");" ]
        <> [ "  pudu_arguments[" <> textOfInt index <> "]." <> cellName kind <> " = " <> fromAbi kind (argument index) <> ";"
           | (index, kind) <- parameters ]
        <> called
        <> [ "  pudu_export_leave();" ]
        <> returned
        <> ["}"]
  pure (body, signature <> ";")
 where
  resultType = case frameFunctionResult function of
    CoreUnitType -> Right "void"
    kind
      | crosses kind -> Right (abiType kind)
      | otherwise -> Left (FrameFault Nothing ("an exported function returning a value C cannot receive: '" <> frameFunctionName function <> "'"))
  crossing role slot
    | crosses (frameSlotType slot) = Right ()
    | otherwise = Left (FrameFault (Just (frameSlotSpan slot)) ("an exported function " <> role <> " C cannot pass"))

-- The scalar shapes a C caller passes and receives by value.
crosses :: CoreType -> Bool
crosses kind = case kind of
  CoreIntegerType (SignedKind width) -> width <= 64
  CoreIntegerType (UnsignedKind width) -> width <= 64
  CoreFloatType _ -> True
  CoreBoolType -> True
  _ -> False
