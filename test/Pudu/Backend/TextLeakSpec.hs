{-| @Test.Backend.TextLeakSpec — every text program frees what it allocates. -}
module Pudu.Backend.TextLeakSpec (textLeakProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Backend.TextMethodPrograms (textMethodSuccessPrograms)
import Pudu.Backend.CharPrograms (charSuccessPrograms)
import Pudu.Backend.TuplePrograms (tupleSuccessPrograms)
import Pudu.Backend.RecordPrograms (recordSuccessPrograms)
import Pudu.Backend.SumPrograms (sumSuccessPrograms)
import Pudu.Backend.ModulePrograms (constantPrograms)
import Pudu.Backend.ReferencePrograms (referenceSuccessPrograms)
import Pudu.Backend.MethodPrograms (methodSuccessPrograms)
import Pudu.Backend.GenericPrograms (genericSuccessPrograms)
import Pudu.Backend.TryPrograms (trySuccessPrograms)
import Pudu.Backend.ForPrograms (forSuccessPrograms)
import Pudu.Backend.ClosurePrograms (closureSuccessPrograms)
import Pudu.Backend.ArrayPrograms (arraySuccessPrograms)
import Pudu.Backend.TextPrograms (textSuccessPrograms)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), compiledNativeModule, lowerProgram)
import Pudu.Diagnostic (hasErrors)
import Pudu.Source (SourceName (..), newSource)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

textLeakProperties :: [(String, IO Property)]
textLeakProperties = [("native text programs release every allocation", testLeaks)]

testLeaks :: IO Property
testLeaks = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "text leak checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-text-leaks" $ \root -> do
      outcomes <- traverse (check cc root) (textSuccessPrograms <> textMethodSuccessPrograms <> charSuccessPrograms <> tupleSuccessPrograms <> recordSuccessPrograms <> sumSuccessPrograms <> constantPrograms <> referenceSuccessPrograms <> methodSuccessPrograms <> genericSuccessPrograms <> trySuccessPrograms <> forSuccessPrograms <> closureSuccessPrograms <> arraySuccessPrograms)
      putStrLn ("[text leaks] executed " <> show (length outcomes) <> " counted programs")
      pure (conjoin outcomes)
 where
  check cc root (label, text, expected) = do
    source <- newSource (SourceName "Main.pudu") text
    checked <- runCompile source
    case (hasErrors (compileDiagnostics checked), compileModule checked) of
      (False, Just parsed) -> case lowerProgram "main" [compiledNativeModule parsed checked] of
        Lowered core -> case lowerFrames core >>= emitProgram "text-leak-test" [source] of
          Left failure -> pure (counterexample (label <> ": " <> show failure) (False === True))
          Right emitted -> do
            let path = root </> "leaks.c"
                binary = root </> "leaks"
            TextIO.writeFile path (instrument <> emitted <> trailer)
            (built, output, errors) <- readProcessWithExitCode cc
              ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", "-Wno-unused-function", path, "-o", binary] ""
            if built /= ExitSuccess || not (null output && null errors)
              then pure (counterexample (label <> ": " <> show built <> output <> errors) (False === True))
              else do
                (status, out, err) <- readProcessWithExitCode binary [] ""
                pure $ counterexample (label <> ": " <> show (status, err)) $ conjoin
                  [status === ExitSuccess, Text.pack out === expected, err === ""]
        other -> pure (counterexample (label <> ": " <> show other) (False === True))
      _ -> pure (counterexample (label <> ": " <> show (compileDiagnostics checked)) (False === True))

{-| Counts every live heap block, frames and text alike, and fails the process
    at exit if any is still held. -}
instrument :: Text
instrument = Text.unlines
  [ "#include <stdlib.h>", "#include <stdio.h>"
  , "static size_t test_live = 0;"
  , "static void *test_malloc(size_t bytes) {"
  , "  void *answer = malloc(bytes); if(answer != NULL) ++test_live; return answer; }"
  , "static void *test_calloc(size_t count, size_t bytes) {"
  , "  void *answer = calloc(count,bytes); if(answer != NULL) ++test_live; return answer; }"
  , "static void test_free(void *pointer) {"
  , "  if(pointer != NULL) { if(test_live == 0) _Exit(98); --test_live; } free(pointer); }"
  , "static void test_check(void) { if(test_live != 0) { fprintf(stderr, \"leaked %zu blocks\\n\", test_live); _Exit(97); } }"
  , "#define malloc test_malloc", "#define calloc test_calloc", "#define free test_free"
  , "#define main pudu_test_program"
  ]

trailer :: Text
trailer = Text.unlines
  [ "#undef main", "int main(void) {"
  , "  if(atexit(test_check) != 0) abort();", "  return pudu_test_program();", "}" ]
