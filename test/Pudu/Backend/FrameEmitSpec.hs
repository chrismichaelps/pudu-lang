{-| @Test.Backend.FrameEmitSpec — strict C checks for suspending function bodies. -}
module Pudu.Backend.FrameEmitSpec (frameEmitProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.ControlPrograms (controlSuccessPrograms, controlRefusalPrograms)
import Pudu.Backend.Emit.Frame (frameUsesWideCells)
import Pudu.Backend.Runtime.Frame (frameTypes)
import Pudu.Backend.Emit.Frame.Body (emitFrameBodies)
import Pudu.Backend.Emit.Frame.Value (frameValue, slotText)
import Pudu.Backend.Emit.State (EmitState (..), emptyEmitState, renderSites, textOfInt)
import Pudu.Backend.FunctionPrograms (functionSuccessPrograms, functionRefusalPrograms)
import Pudu.Backend.IntegerPrograms (integerSuccessPrograms, integerRefusalPrograms)
import Pudu.Backend.Runtime (RuntimePart (..), runtimeParts)
import Pudu.Backend.Runtime.Integer (integerRuntimeDependencies)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Core (CoreType (..))
import Pudu.Core.Frame
  ( FrameFault (..), FrameModule (..), FrameSlot (..), FrameSlotId (..)
  , FrameUnaryOperator (..), FrameValue (..), FrameValueShape (..) )
import Pudu.Diagnostic (hasErrors)
import Pudu.IntegerLiteral (IntegerKind (SignedKind))
import Pudu.Source (SourceName (..), emptySpan, newSource)
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

frameEmitProperties :: [(String, IO Property)]
frameEmitProperties =
  [ ("frame body emission rejects invalid slot representations", testSlots)
  , ("frame body emission suspends nested calls without C recursion", testCalls)
  , ("frame body emission compiles native corpora as strict C11", testBodies)
  ]

testSlots :: IO Property
testSlots = do
  source <- newSource (SourceName "frames.pudu") "slots"
  let at = emptySpan source
      slot identity kind = FrameSlot (FrameSlotId identity) "slot" kind at
      rejected input = case slotText input of
        Left failure -> frameFaultSpan failure === Just at
        Right text -> counterexample (Text.unpack text) (False === True)
  pure $ conjoin
    [ rejected (slot (-1) CoreBoolType), rejected (slot 0 CoreTextType)
    , rejected (slot 0 CoreNeverType)
    , slotText (slot 3 CoreUnitType) === Right "frame->slots[3].scalar"
    , let kind = CoreIntegerType (SignedKind 256)
       in case frameValue (emptyEmitState [source])
            (FrameValue at kind (FrameUnary FrameNegate (slot 0 kind))) of
            Left failure -> frameFaultSpan failure === Just at
            Right _ -> counterexample "unsupported descriptor was emitted" (False === True)
    ]

testBodies :: IO Property
testBodies = do
  compiler <- findExecutable "cc"
  case compiler of
    Nothing -> putStrLn "[skip] frame body C11 checks: cc was not found" >> pure (True === True)
    Just cc -> withSystemTempDirectory "pudu-frame-bodies" $ \root -> do
      results <- traverse (check cc root) programs
      putStrLn ("[frame bodies] checked " <> show (length programs) <> " strict C11 translations")
      pure (conjoin results)
  where
    programs = functionSuccessPrograms <> functionRefusalPrograms
      <> controlSuccessPrograms <> controlRefusalPrograms
      <> [(name, source) | (name, source, _) <- integerSuccessPrograms] <> integerRefusalPrograms
    check cc root (name, text) = do
      source <- newSource (SourceName "Main.pudu") text
      checked <- runCompile source
      case (hasErrors (compileDiagnostics checked), compileModule checked) of
        (False, Just parsed) -> case lowerProgram "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
          Lowered core -> case lowerFrames core of
            Left failure -> pure (counterexample (show failure) (False === True))
            Right frames -> case emitFrameBodies (emptyEmitState [source]) frames of
              Left failure -> pure (counterexample (name <> ": " <> show failure) (False === True))
              Right (emitted, roots) -> do
                let cpath = root </> "frames.c"
                    selected = close (Set.union roots (Set.fromList (["prelude", "integer_value", "site"] <> ["wide_value" | frameUsesWideCells frames])))
                    runtime = concat [runtimePartLines part | part <- runtimeParts, Set.member (runtimePartName part) selected]
                    generated = runtime <> renderSites (reverse (emitSites emitted)) <> frameTypes (frameUsesWideCells frames)
                      <> reverse (emitOutput emitted) <> dispatch (length (frameModuleFunctions frames)) (Set.member "fail" selected)
                TextIO.writeFile cpath (Text.unlines generated)
                (status, output, errors) <- readProcessWithExitCode cc
                  ["-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", "-c", cpath, "-o", root </> "frames.o"] ""
                pure $ counterexample (name <> ": " <> output <> errors) $ conjoin
                  [status === ExitSuccess, output === "", errors === ""]
          other -> pure (counterexample (name <> ": " <> show other) (False === True))
        _ -> pure (counterexample (name <> ": " <> show (compileDiagnostics checked)) (False === True))
    close = foldl' visit Set.empty . Set.toList
    visit found part
      | Set.member part found = found
      | otherwise = foldl' visit (Set.insert part found) (integerRuntimeDependencies part)

testCalls :: IO Property
testCalls = do
  source <- newSource (SourceName "Main.pudu")
    "module Main\nfn one() -> Int { 1 }\nfn sum(a: Int, b: Int) -> Int { a + b }\nfn main() -> Int { sum(one(), one()) }\n"
  checked <- runCompile source
  pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> case lowerProgram "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
      Lowered core -> case lowerFrames core >>= emitFrameBodies (emptyEmitState [source]) of
        Right (emitted, _) ->
          let output = reverse (emitOutput emitted)
              bodyNames = filter (Text.isInfixOf "pudu_body_") output
           in conjoin
                [ length bodyNames === 3
                , counterexample (show bodyNames) (all (Text.isPrefixOf "static pudu_step pudu_body_") bodyNames)
                , length (filter (Text.isInfixOf ".kind = PUDU_CALL") output) === 3
                , length (filter (Text.isInfixOf "frame->arguments[") output) === 2
                , length (filter (Text.isInfixOf ".has_destination = 1") output) === 3
                ]
        Left failure -> counterexample (show failure) (False === True)
      other -> counterexample (show other) (False === True)
    _ -> counterexample (show (compileDiagnostics checked)) (False === True)

dispatch :: Int -> Bool -> [Text]
dispatch count hasFailure =
  [ "pudu_step test_invoke(size_t function, pudu_frame *frame, size_t depth) {"
  , "  pudu_step step;", "  (void)depth;", "  switch (function) {" ]
  <> ["  case " <> textOfInt index <> ": step = pudu_body_" <> textOfInt index <> "(frame); break;" | index <- [0 .. count - 1]]
  <> ["  default: return (pudu_step){.kind = PUDU_INVALID};", "  }"]
  <> ["  if (step.kind == PUDU_CALL && depth > " <> textOfInt callDepthLimit <> ") pudu_fail(step.call_site);" | hasFailure]
  <> ["  return step;", "}"]
