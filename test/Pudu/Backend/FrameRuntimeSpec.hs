{-| @Test.Backend.FrameRuntimeSpec — production frame allocation and panic cleanup. -}
module Pudu.Backend.FrameRuntimeSpec (frameRuntimeProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerModule)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Diagnostic (hasErrors)
import Pudu.Source (SourceName (..), newSource)
import System.Directory (findExecutable)
import System.Environment (getEnvironment, getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (CreateProcess (env), proc, readCreateProcessWithExitCode, readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

frameRuntimeProperties :: [(String, IO Property)]
frameRuntimeProperties =
  [ ("frame allocator frees normal returns and failed allocations", testAllocations)
  , ("dynamic diagnostics release surviving payload copies", testDiagnosticCopies)
  , ("dynamic diagnostic payload bounds and empty views preserve cleanup", testDiagnosticBounds)
  , ("aggregate joining rejects overflowing separator and label lengths", testJoinOverflow)
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

testDiagnosticCopies :: IO Property
testDiagnosticCopies = withCompiler $ \cc root -> conjoin <$> traverse (check cc root)
  [ ("E7001", "cannot apply - to a builtin", Nothing,
      "let invalid = -print\n print(show(invalid))")
  , ("E7008", "a builtin cannot be a set member", Just "use a value the language can order",
      "let invalid = setOf([print])\n print(show(invalid))")
  , ("E7004", "slice range out of bounds", Just "it has 1 elements",
      "let items = [1]\n let invalid = items[0..2]\n print(show(invalid))")
  , ("E7004", "slice range out of bounds", Just "it has 2 elements",
      "let text = \"hé\"\n let invalid = text[0..3]\n print(invalid)")
  ]
 where
  check cc root (code, message, help, body) = do
    let source = "module Main\nfn main() -> Int { print(\"before\")\n " <> body <> "\n 0 }\n"
        path = root </> "Main.pudu"
    TextIO.writeFile path source
    result <- execute cc root source 0 id
    oracle <- getExecutablePath
    inherited <- getEnvironment
    parity <- traverse (\engine -> do
      let settings = [("PUDU_EVAL", engine), ("NO_COLOR", "1")]
          process = (proc oracle ["--native-output-oracle", path])
            {env = Just (settings <> filter (\(name, _) -> name `notElem` map fst settings) inherited)}
      (status, output, errors) <- readCreateProcessWithExitCode process ""
      pure $ counterexample (engine <> ": " <> show result) $
        result === Right (status, Text.pack output, Text.pack errors)) ["compiled", "tree"]
    pure $ conjoin (parity <> [counterexample (show result) $ case result of
      Right (status, output, errors) -> conjoin
        [ status === ExitFailure 1, output === "before\n"
        , Text.isInfixOf ("error[" <> code <> "]: " <> message) errors === True
        , maybe True (`Text.isInfixOf` errors) help === True
        , Text.isInfixOf "leaked frame" errors === False
        ]
      Left _ -> False === True])

testDiagnosticBounds :: IO Property
testDiagnosticBounds = withCompiler $ \cc root -> do
  overflow <- injected cc root
    "pudu_fail_text_help(NULL, (pudu_text){NULL, SIZE_MAX, NULL}, (pudu_text){NULL, 1, NULL});"
  empty <- injected cc root
    "pudu_fail_text_help(&pudu_sites[0], (pudu_text){NULL, 0, NULL}, (pudu_text){NULL, 0, NULL});"
  pure $ conjoin
    [ overflow === Right (ExitFailure 1, "", "pudu: memory allocation failed\n")
    , counterexample (show empty) $ case empty of
        Right (status, output, errors) -> conjoin
          [ status === ExitFailure 1, output === ""
          , Text.isInfixOf "error[" errors === True
          , Text.isInfixOf "   = help: \n" errors === True
          , Text.isInfixOf "leaked frame" errors === False ]
        Left _ -> False === True
    ]
 where
  injected cc root probe = execute cc root
    "module Main\nfn main() -> Int { let items = [1]\n print(show(items[0..2]))\n 0 }\n" 0
    (Text.replace "int main(void) {" ("int main(void) { " <> probe))

testJoinOverflow :: IO Property
testJoinOverflow = withCompiler $ \cc root -> conjoin <$> traverse (check cc root)
  [ "pudu_text parts[2] = {{NULL, 0, NULL}, {NULL, SIZE_MAX, NULL}}; (void)pudu_text_join(\"\", NULL, parts, 2, \"\");"
  , "pudu_text parts[1] = {{NULL, SIZE_MAX, NULL}}; const char *labels[1] = {\":\"}; (void)pudu_text_join(\"\", labels, parts, 1, \"\");"
  ]
 where
  check cc root probe = do
    result <- execute cc root "module Main\nfn main() -> (Int, Int) { (1, 2) }\n" 0
      (Text.replace "int main(void) {" ("int main(void) { " <> probe))
    pure $ counterexample (show result) $ result === Right
      (ExitFailure 1, "", "pudu: memory allocation failed\n")

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "frame runtime checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-frame-runtime" (action cc)

execute :: FilePath -> FilePath -> Text -> Int -> (Text -> Text)
  -> IO (Either String (ExitCode, Text, Text))
execute cc root sourceText failAt transform = do
  source <- newSource (SourceName (Text.pack (root </> "Main.pudu"))) sourceText
  checked <- runCompile source
  case (hasErrors (compileDiagnostics checked), compileModule checked) of
    (False, Just parsed) -> case lowerModule "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
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
  , "static void *test_malloc(size_t bytes) {"
  , "  void *answer = malloc(bytes); if (answer != NULL) ++test_live; return answer;"
  , "}"
  , "static void *test_calloc(size_t count, size_t bytes) {"
  , "  void *answer; ++test_attempt;"
  , "  if (test_attempt == " <> Text.pack (show attempt) <> ") return NULL;"
  , "  answer = calloc(count, bytes); if (answer != NULL) ++test_live; return answer;"
  , "}"
  , "static void test_free(void *pointer) {"
  , "  if (pointer != NULL) { if (test_live == 0) _Exit(98); --test_live; } free(pointer);"
  , "}"
  , "static void test_check(void) { if (test_live != 0) { fputs(\"leaked frame\\n\", stderr); _Exit(97); } }"
  , "#define malloc test_malloc", "#define calloc test_calloc", "#define free test_free", "#define main pudu_test_program"
  ]

trailer :: Text
trailer = Text.unlines
  [ "#undef main", "int main(void) {"
  , "  (void)test_malloc; if (atexit(test_check) != 0) abort(); return pudu_test_program();", "}" ]
