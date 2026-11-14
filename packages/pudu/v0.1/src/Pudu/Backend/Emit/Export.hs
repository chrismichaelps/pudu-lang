{-| @Pudu.Backend.Emit.Export — one C function per exported Pudu function of
    an embedded library, entered on the thread that started the program, with
    the crossings of [[Backend Export Crossing]] and a status for `Result`. -}
module Pudu.Backend.Emit.Export (ExportSection (..), exportSection) where

import Data.List (nub)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Aggregate (aggregateNeed, isAggregate, released)
import Pudu.Backend.Emit.Cell (cellName)
import Pudu.Backend.Emit.Export.Crossing (crossingDeclarations, crossingHelpers, crossingPrototypes, crossingName, crossingNeeds, giveValue, takeCell)
import Pudu.Backend.Emit.Foreign (parameterNeeds, resultNeeds)
import Pudu.Backend.Emit.ForeignAbi (Layouts, mangle)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core (CoreLayout (..), CoreType (..), CoreVariant (..))
import Pudu.Core.Frame (FrameFault (..), FrameFunction (..), FrameSlot (..))

{-| @Backend.Emit.Export.Section — the wrappers, the declarations a header
    carries (types, then prototypes), and the runtime parts and aggregate
    helpers their conversions select. -}
data ExportSection = ExportSection
  { exportCode :: ![Text]
  , exportPrototypes :: ![Text]
  , exportNeeds :: ![Text]
  }
  deriving stock (Eq, Show)

-- | What an export returns: one value (or `()`), or a `Result` reported as a
-- status with its sum type, the `Ok` index, and both payload types.
data Returned
  = Plain !CoreType
  | Outcome !CoreType !Int !CoreType !CoreType

{-| The wrappers for the exports named by key, over the indexed frame
    functions and the module's layouts; an export in the direct set is one C
    call to its stack-frame entry. A module without exports yields an empty
    section. -}
exportSection :: Layouts -> Set Text -> [(Int, FrameFunction)] -> [Text] -> Either FrameFault ExportSection
exportSection _ _ _ [] = Right (ExportSection [] [] [])
exportSection layouts direct indexed keys = do
  found <- traverse locate keys
  shaped <- traverse (\entry@(_, function) -> (,) entry <$> returnedOf layouts function) found
  wrappers <- traverse (wrapper layouts direct) shaped
  let inbound = nub (concatMap (parameterTypes . snd) found)
      outbound = nub (concatMap (payloads . snd) shaped)
      declarations = crossingDeclarations layouts (nub (inbound <> outbound))
      scalars = filter (not . owned) (inbound <> outbound)
  pure ExportSection
    { exportCode = declarations <> admission <> crossingHelpers layouts inbound outbound <> concatMap fst wrappers
    , exportPrototypes = declarations <> crossingPrototypes layouts outbound <> map snd wrappers
    , exportNeeds = nub (concatMap resultNeeds scalars <> concatMap parameterNeeds scalars
        <> crossingNeeds layouts inbound outbound <> concatMap (releases . snd) shaped)
    }
 where
  locate key = case [entry | entry@(_, function) <- indexed, frameFunctionName function == key] of
    [entry] -> Right entry
    _ -> Left (FrameFault Nothing ("the exported function '" <> key <> "' without a lowered body"))
  payloads (Plain kind) = [kind | kind /= CoreUnitType]
  payloads (Outcome _ _ ok failure) = filter (/= CoreUnitType) [ok, failure]
  releases (Plain kind) = [aggregateNeed "drop" kind | isAggregate kind]
  releases (Outcome sum' _ _ _) = [aggregateNeed "drop" sum']

parameterTypes :: FrameFunction -> [CoreType]
parameterTypes = map frameSlotType . frameFunctionParameters

owned :: CoreType -> Bool
owned kind = kind == CoreTextType || isAggregate kind

-- A `Result` is the two-variant sum whose variants are `Ok` and `Err`, each
-- with one payload; any other result must cross as a value.
returnedOf :: Layouts -> FrameFunction -> Either FrameFault Returned
returnedOf layouts function = case frameFunctionResult function of
  CoreUnitType -> Right (Plain CoreUnitType)
  kind@(CoreSumType _ _)
    | Just (CoreSumLayout variants) <- Map.lookup kind layouts
    , [(okIndex, ok), (_, failure)] <- outcome variants -> do
        mapM_ payload [ok, failure]
        Right (Outcome kind okIndex ok failure)
  kind
    | Just _ <- crossingName layouts kind -> Right (Plain kind)
    | otherwise -> Left (FrameFault Nothing ("an exported function returning a value C cannot receive: '" <> frameFunctionName function <> "'"))
 where
  outcome variants =
    case ( [(index, single variant) | (index, variant) <- zip [0 ..] variants, coreVariantName variant == "Ok"]
         , [(index, single variant) | (index, variant) <- zip [0 ..] variants, coreVariantName variant == "Err"] ) of
      ([(okIndex, Just ok)], [(failIndex, Just failure)]) | length variants == 2 -> [(okIndex, ok), (failIndex, failure)]
      _ -> []
  single variant = case coreVariantFields variant of
    [(_, kind)] -> Just kind
    _ -> Nothing
  payload CoreUnitType = Right ()
  payload kind
    | Just _ <- crossingName layouts kind = Right ()
    | otherwise = Left (FrameFault Nothing ("an exported function whose Result payload C cannot receive: '" <> frameFunctionName function <> "'"))

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

wrapper :: Layouts -> Set Text -> ((Int, FrameFunction), Returned) -> Either FrameFault ([Text], Text)
wrapper layouts direct ((identity, function), returned) = do
  parameterTypes' <- traverse crossing (frameFunctionParameters function)
  let name = mangle (Text.takeWhileEnd (/= '.') (frameFunctionName function))
      quoted = "\"" <> name <> "\""
      parameters = zip [0 :: Int ..] (parameterTypes function)
      count = length parameters
      argument index = "p" <> textOfInt index
      cell kind index = "pudu_arguments[" <> textOfInt index <> "]." <> cellName kind
      outcomePointers = case returned of
        Outcome _ _ ok failure ->
          [typed ok <> " *pudu_value" | ok /= CoreUnitType] <> [typed failure <> " *pudu_error" | failure /= CoreUnitType]
        Plain _ -> []
      declared = [ctype <> " " <> argument index | (index, ctype) <- zip [0 :: Int ..] parameterTypes'] <> outcomePointers
      resultType = case returned of
        Plain CoreUnitType -> "void"
        Plain kind -> typed kind
        Outcome {} -> "int"
      signature = resultType <> " pudu_export_" <> name <> "("
        <> (if null declared then "void" else Text.intercalate ", " declared) <> ")"
      arguments
        | count == 0 = "NULL"
        | otherwise = "pudu_arguments"
      called
        | Set.member (frameFunctionName function) direct =
            [ "  pudu_result = pudu_direct_" <> textOfInt identity <> "(" <> arguments <> ");" ]
        | otherwise =
            [ "  pudu_active_frame = pudu_new_frame(" <> textOfInt identity <> ", " <> arguments <> ", " <> textOfInt count <> ");"
            , "  pudu_result = pudu_run_active();" ]
      -- The callee's frame took its own reference to each owned argument.
      releasedArguments = [ "  " <> released kind (cell kind index) | (index, kind) <- parameters, owned kind ]
      result = "pudu_result." <> cellName (resultOf returned)
      finished = case returned of
        Plain CoreUnitType -> ["  (void)pudu_result;"]
        Plain kind
          | owned kind ->
              [ "  {"
              , "    " <> typed kind <> " pudu_value = " <> giveValue kind result <> ";"
              , "    " <> released kind result
              , "    return pudu_value;"
              , "  }" ]
          | otherwise -> ["  return " <> giveValue kind result <> ";"]
        Outcome sum' okIndex ok failure ->
          [ "  {"
          , "    pudu_box *pudu_outcome = pudu_result.box;"
          , "    int pudu_status = pudu_outcome->fields[0].scalar == " <> textOfInt okIndex <> " ? 0 : 1;" ]
          <> [ "    if (pudu_status == 0 && pudu_value != NULL) *pudu_value = " <> giveValue ok (payloadCell ok) <> ";" | ok /= CoreUnitType ]
          <> [ "    if (pudu_status != 0 && pudu_error != NULL) *pudu_error = " <> giveValue failure (payloadCell failure) <> ";" | failure /= CoreUnitType ]
          <> [ "    " <> released sum' "pudu_outcome"
             , "    return pudu_status;"
             , "  }" ]
      body =
        [ signature <> ";"
        , signature <> " {" ]
        <> [ "  pudu_cell pudu_arguments[" <> textOfInt count <> "];" | count > 0 ]
        <> [ "  pudu_cell pudu_result;"
           , "  pudu_export_enter(" <> quoted <> ");" ]
        <> [ "  " <> cell kind index <> " = " <> takeCell kind quoted (argument index) <> ";" | (index, kind) <- parameters ]
        <> called
        <> [ "  pudu_export_leave();" ]
        <> releasedArguments
        <> finished
        <> ["}"]
  pure (body, signature <> ";")
 where
  typed kind = maybe "void" id (crossingName layouts kind)
  crossing slot = case crossingName layouts (frameSlotType slot) of
    Just ctype -> Right ctype
    Nothing -> Left (FrameFault (Just (frameSlotSpan slot)) "an exported function parameter C cannot pass")
  payloadCell kind = "pudu_outcome->fields[1]." <> cellName kind
  resultOf (Plain kind) = kind
  resultOf (Outcome sum' _ _ _) = sum'
