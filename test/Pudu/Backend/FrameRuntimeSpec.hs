{-| @Test.Backend.FrameRuntimeSpec — production frame allocation and panic cleanup. -}
module Pudu.Backend.FrameRuntimeSpec (frameRuntimeProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Diagnostic (hasErrors)
import Pudu.Source (SourceName (..), newSource)
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

frameRuntimeProperties :: [(String, IO Property)]
frameRuntimeProperties =
  [ ("frame allocator frees normal returns and failed allocations", testAllocations)
  , ("frame allocator unwinds source panics and rejects size overflow", testPanics)
  ]

testAllocations :: IO Property
testAllocations = withCompiler $ \cc root -> conjoin <$> traverse (check cc root)
  [ (0, "3\n2\n1\n0\n", ExitFailure 7)
  , (1, "", ExitFailure 1), (2, "", ExitFailure 1)
  , (3, "3\n", ExitFailure 1), (5, "3\n2\n1\n", ExitFailure 1)
  ]
  where
    source = Text.unlines
      [ "module Main", "fn recurse(n: Int) -> Int {", "  print(display(n))"
      , "  if n == 0 { return 7 }", "  return recurse(n - 1)", "}"
      , "fn main() -> Int { recurse(3) }" ]
    check cc root (attempt, expected, status) = do
      result <- execute cc root source attempt id
      pure $ counterexample (show result) $ result === Right
        (status, expected, if attempt == 0 then "" else "pudu: memory allocation failed\n")

testPanics :: IO Property
testPanics = withCompiler $ \cc root -> do
  divide <- execute cc root "module Main\nfn crash() -> Int { 1 / 0 }\nfn main() -> Int { crash() }\n" 0 id
  depth <- execute cc root "module Main\nfn recurse(n: Int) -> Int { recurse(n + 1) }\nfn main() -> Int { recurse(0) }\n" 0 id
  addition <- execute cc root "module Main\nfn main() -> Int { 0 }\n" 0
    (Text.replace "{1, 0, 0, 0, NULL" "{SIZE_MAX, 1, 0, 0, NULL")
  multiplication <- execute cc root "module Main\nfn main() -> Int { 0 }\n" 0
    (Text.replace "{1, 0, 0, 0, NULL" "{SIZE_MAX / sizeof(pudu_cell), 0, 0, 0, NULL")
  pure $ conjoin
    [ panic "E7004" divide, panic "E7002" depth
    , addition === Right (ExitFailure 1, "", "pudu: memory allocation failed\n")
    , multiplication === Right (ExitFailure 1, "", "pudu: memory allocation failed\n")
    ]
  where
    panic code result = counterexample (show result) $ case result of
      Right (status, output, errors) -> conjoin
        [ status === ExitFailure 1, output === ""
        , counterexample "wrong runtime failure or leaked frame" (Text.isInfixOf ("error[" <> code <> "]") errors)
        ]
      Left _ -> False === True

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  compiler <- findExecutable "cc"
  case compiler of
    Nothing -> putStrLn "[skip] frame allocator checks: cc was not found" >> pure (True === True)
    Just cc -> withSystemTempDirectory "pudu-frame-runtime" (action cc)

execute :: FilePath -> FilePath -> Text -> Int -> (Text -> Text)
  -> IO (Either String (ExitCode, Text, Text))
execute cc root sourceText failAt transform = do
  source <- newSource (SourceName "Main.pudu") sourceText
  checked <- runCompile source
  case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> case lowerProgram "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
      Lowered core -> case lowerFrames core >>= emitProgram "frame-test" [source] of
        Left failure -> pure (Left (show failure))
        Right emitted -> do
          let cpath = root </> "Main.c"
              binary = root </> "Main"
          TextIO.writeFile cpath (Text.unlines (instrument failAt) <> transform emitted <> trailer)
          (built, output, errors) <- readProcessWithExitCode cc
            ["-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", cpath, "-o", binary] ""
          if built /= ExitSuccess || not (null output && null errors)
            then pure (Left (show built <> output <> errors))
            else do
              (status, out, err) <- readProcessWithExitCode binary [] ""
              pure (Right (status, Text.pack out, Text.pack err))
      other -> pure (Left (show other))
    _ -> pure (Left (show (compileDiagnostics checked)))

instrument :: Int -> [Text]
instrument attempt =
  [ "#include <stdlib.h>", "#include <stdio.h>"
  , "static size_t test_live = 0, test_attempt = 0;"
  , "static void *test_calloc(size_t count, size_t bytes) {"
  , "  void *answer; ++test_attempt;"
  , "  if (test_attempt == " <> Text.pack (show attempt) <> ") return NULL;"
  , "  answer = calloc(count, bytes); if (answer != NULL) ++test_live; return answer;"
  , "}"
  , "static void test_free(void *pointer) {"
  , "  if (pointer != NULL) { if (test_live == 0) _Exit(98); --test_live; } free(pointer);"
  , "}"
  , "static void test_check(void) { if (test_live != 0) { fputs(\"leaked frame\\n\", stderr); _Exit(97); } }"
  , "#define calloc test_calloc", "#define free test_free", "#define main pudu_test_program"
  ]

trailer :: Text
trailer = Text.unlines
  [ "#undef main", "int main(void) {"
  , "  if (atexit(test_check) != 0) abort(); return pudu_test_program();", "}" ]
