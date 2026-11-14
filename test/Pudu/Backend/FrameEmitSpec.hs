{-| @Test.Backend.FrameEmitSpec — strict C checks for suspending function bodies. -}
module Pudu.Backend.FrameEmitSpec (frameEmitProperties) where

import qualified Data.Set as Set
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.ControlPrograms (controlSuccessPrograms, controlRefusalPrograms)
import Pudu.Backend.Emit (EmittedUnit (emittedSource), EntryForm (EmbeddedEntry), emitUnit)
import Pudu.Backend.Emit.Entry (embeddedHeader, embeddedHeaderName)
import Pudu.Backend.Emit.Frame (emitFrameProgram)
import Pudu.Backend.Emit.Frame.Body (emitFrameBodies)
import Pudu.Backend.Emit.Frame.Value (frameValue, slotText)
import Pudu.Backend.Emit.State (EmitState (..), emptyEmitState)
import Pudu.Backend.FunctionPrograms (functionSuccessPrograms, functionRefusalPrograms)
import Pudu.Backend.IntegerPrograms (integerSuccessPrograms, integerRefusalPrograms)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerModule)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Core (CoreType (..), CoreKeyedMethodName (KeyedWordUnion, KeyedWordSubset, KeyedWordDisjoint, KeyedWordPopCount, KeyedWordMembers))
import Pudu.Core (CoreTextMethodName (..))
import Pudu.Core.Frame
  ( FrameFault (..), FrameSlot (..), FrameSlotId (..)
  , FrameUnaryOperator (..), FrameValue (..), FrameValueShape (..) )
import Pudu.Diagnostic (hasErrors)
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, SignedKind, UnsignedKind))
import Pudu.Source (SourceName (..), emptySpan, newSource)
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, once, (===))

frameEmitProperties :: [(String, IO Property)]
frameEmitProperties =
  [ ("frame body emission rejects invalid slot representations", testSlots)
  , ("native word-map frame helpers reject mismatched carriers", testWordMapSlots)
  , ("native text-view methods reject mismatched carriers", testTextViewSlots)
  , ("frame body emission suspends nested calls without C recursion", testCalls)
  , ("frame body emission compiles native corpora as strict C11", testBodies)
  , ("embedded native entry returns status, flushes, and runs once per process", once <$> testEmbeddedEntry)
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
    [ rejected (slot (-1) CoreBoolType), slotText (slot 0 CoreTextType) === Right "frame->slots[0].text"
    , rejected (slot 0 CoreNeverType)
    , slotText (slot 3 CoreUnitType) === Right "frame->slots[3].scalar"
    , let kind = CoreIntegerType (SignedKind 256)
       in case frameValue (emptyEmitState [source])
            (FrameValue at kind (FrameUnary FrameNegate (slot 0 kind))) of
            Left failure -> frameFaultSpan failure === Just at
            Right _ -> counterexample "unsupported descriptor was emitted" (False === True)
    ]

testWordMapSlots :: IO Property
testWordMapSlots = do
  source <- newSource (SourceName "wordmaps.pudu") "maps"
  let at = emptySpan source
      word = CoreMapType CoreTextType (CoreIntegerType (UnsignedKind 64))
      signed = CoreMapType CoreTextType (CoreIntegerType (SignedKind 64))
      slot n kind = FrameSlot (FrameSlotId n) "map" kind at
      unsigned = CoreIntegerType (UnsignedKind 64)
      wide = CoreIntegerType (UnsignedKind 128)
      members = CoreArrayType unsigned
      chunks = CoreMapType unsigned unsigned
      rejected (name, receiver, arguments, result) =
        case frameValue (emptyEmitState [source])
          (FrameValue at result (FrameKeyedMethod name (slot 0 receiver) (zipWith slot [1..] arguments))) of
          Left failure -> frameFaultSpan failure === Just at
          Right _ -> counterexample ("a word helper reinterpreted another carrier: " <> show name) (False === True)
  pure $ conjoin $ map rejected
    ([(KeyedWordUnion, left, [right], result)
     | (left, right, result) <- [(signed, signed, signed), (word, signed, word), (word, word, CoreBoolType)]] <>
     [(name, receiver, arguments, result)
     | name <- [KeyedWordSubset, KeyedWordDisjoint]
     , (receiver, arguments, result) <-
        [(signed, [signed], CoreBoolType), (word, [signed], CoreBoolType)
        ,(word, [], CoreBoolType), (word, [word, word], CoreBoolType)
        ,(word, [word], unsigned), (CoreBoolType, [word], CoreBoolType)]] <>
     [(KeyedWordPopCount, receiver, arguments, result)
     | (receiver, arguments, result) <-
        [(signed, [], wide), (word, [word], wide), (word, [], unsigned), (CoreBoolType, [], wide)]] <>
     [(KeyedWordMembers, receiver, arguments, result)
     | (receiver, arguments, result) <-
        [(word, [], members), (signed, [], members), (chunks, [chunks], members)
        ,(chunks, [], CoreArrayType (CoreIntegerType (SignedKind 64))), (chunks, [], wide)]])

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
        (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
          Lowered core -> case lowerFrames core of
            Left failure -> pure (counterexample (show failure) (False === True))
            -- The whole program as the backend writes it: a corpus that
            -- prints carries Result aggregates, which need their runtime too.
            Right frames -> case emitFrameProgram "test" [source] frames of
              Left failure -> pure (counterexample (name <> ": " <> show failure) (False === True))
              Right generated -> do
                let cpath = root </> "frames.c"
                TextIO.writeFile cpath generated
                (status, output, errors) <- readProcessWithExitCode cc
                  ["-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", "-c", cpath, "-o", root </> "frames.o"] ""
                pure $ counterexample (name <> ": " <> output <> errors) $ conjoin
                  [status === ExitSuccess, output === "", errors === ""]
          other -> pure (counterexample (name <> ": " <> show other) (False === True))
        _ -> pure (counterexample (name <> ": " <> show (compileDiagnostics checked)) (False === True))

testEmbeddedEntry :: IO Property
testEmbeddedEntry = do
  compiler <- findExecutable "cc"
  case compiler of
    Nothing -> putStrLn "[skip] embedded entry C11 check: cc was not found" >> pure (True === True)
    Just cc -> withSystemTempDirectory "pudu-embedded-entry" $ \root -> do
      source <- newSource (SourceName "Main.pudu")
        "module Main\nfn main() -> Int {\n  print(\"pudu\")\n  7\n}\n"
      checked <- runCompile source
      case (hasErrors (compileDiagnostics checked), compileModule checked) of
        (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
          Lowered core -> case lowerFrames core >>= emitUnit EmbeddedEntry "test" [source] of
            Left failure -> pure (counterexample (show failure) (False === True))
            Right unit -> do
              let generated = root </> "program.c"
                  host = root </> "host.c"
                  executable = root </> "host"
              TextIO.writeFile generated (emittedSource unit)
              TextIO.writeFile (root </> embeddedHeaderName) (embeddedHeader [])
              TextIO.writeFile host (Text.unlines
                [ "#include <stdio.h>"
                , "#include \"pudu_program.h\""
                , "int main(int argc, char **argv) {"
                , "  if (pudu_program_run(argc, argv) != 7) return 1;"
                , "  if (pudu_program_run(argc, argv) != PUDU_PROGRAM_ALREADY_STARTED) return 2;"
                , "  puts(\"host\");"
                , "  return 0;"
                , "}"
                ])
              (built, output, errors) <- readProcessWithExitCode cc
                ["-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", generated, host, "-o", executable] ""
              case built of
                ExitSuccess -> do
                  ran <- readProcessWithExitCode executable [] ""
                  pure (ran === (ExitSuccess, "pudu\nhost\n", ""))
                _ -> pure (counterexample (output <> errors) (built === ExitSuccess))
          other -> pure (counterexample (show other) (False === True))
        _ -> pure (counterexample (show (compileDiagnostics checked)) (False === True))

testCalls :: IO Property
testCalls = do
  source <- newSource (SourceName "Main.pudu")
    "module Main\nfn one() -> Int { 1 }\nfn sum(a: Int, b: Int) -> Int { a + b }\nfn main() -> Int { sum(one(), one()) }\n"
  checked <- runCompile source
  pure $ case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
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


{-| Valid descriptors select exactly one root; malformed carriers never reach C. -}
testTextViewSlots :: IO Property
testTextViewSlots = do
  source <- newSource (SourceName "text-views.pudu") "views"
  let at = emptySpan source
      number = CoreIntegerType PlatformSigned
      slot n kind = FrameSlot (FrameSlotId n) "operand" kind at
      emitted name receiver arguments result = frameValue (emptyEmitState [source])
        (FrameValue at result (FrameTextMethod name (slot 0 receiver) (zipWith slot [1..] arguments)))
      refused name receiver arguments result = case emitted name receiver arguments result of
        Left failure -> frameFaultSpan failure === Just at
        Right _ -> counterexample ("invalid text-view carrier: " <> show name) (False === True)
      descriptors =
        [(TextByteSize, [], number, "text_byte_size")
        ,(TextByteIndexValid, [number], CoreBoolType, "text_byte_index_valid")
        ,(TextByteRead, [number], CoreIntegerType (UnsignedKind 8), "text_byte_at")
        ,(TextByteSliceValid, [number, number], CoreBoolType, "text_byte_slice_valid")
        ,(TextByteSlice, [number, number], CoreTextType, "text_byte_slice")
        ,(TextByteFind, [CoreTextType, number], number, "text_byte_find")
        ,(TextByteFindLast, [CoreTextType], number, "text_byte_find_last")
        ,(TextScalarRead, [number], CoreCharType, "text_scalar_at")
        ,(TextScalarWidth, [number], number, "text_scalar_width")]
      valid = [case emitted name CoreTextType arguments result of
          Right (_, _, roots) -> roots === Set.singleton helper
          Left failure -> counterexample (show failure) (False === True)
        | (name, arguments, result, helper) <- descriptors]
      invalid = [refused name receiver arguments result
        | (name, parameters, output, _) <- descriptors
        , (receiver, arguments, result) <-
          [(CoreBoolType, parameters, output), (CoreTextType, parameters, CoreUnitType)
          ,(CoreTextType, parameters <> [number], output)] <>
          [(CoreTextType, drop 1 parameters, output) | not (null parameters)] <>
          [(CoreTextType, CoreBoolType : drop 1 parameters, output) | not (null parameters)]]
  pure (conjoin (valid <> invalid))
