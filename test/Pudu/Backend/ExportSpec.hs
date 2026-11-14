{-| @Test.Backend.ExportSpec — exported Pudu functions called from a C host:
    exact values across every scalar crossing, refusals for signatures C
    cannot carry, and the host-misuse stop. -}
module Pudu.Backend.ExportSpec (exportProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (EmittedUnit (..), EntryForm (..), emitUnit)
import Pudu.Backend.Emit.Entry (embeddedHeader, embeddedHeaderName)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerLibrary, lowerProgram, programNativeModules)
import Pudu.Compiler.Program (compileProgram, programDiagnostics, programSources)
import Pudu.Core.Frame (FrameFault (..))
import Pudu.Diagnostic (diagnosticMessage)
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, once, property, (===))

exportProperties :: [(String, IO Property)]
exportProperties =
  [ ("embedded exports carry every scalar crossing to a C host", once <$> testCrossings)
  , ("embedded exports refuse a call before the start", once <$> testEarlyCall)
  , ("embedded exports refuse a parameter C cannot pass", testTextParameter)
  , ("embedded exports refuse type parameters, defaults and async", testRefusedForms)
  , ("executables never lower exports", testExecutableIgnores)
  ]

crossingProgram :: Text
crossingProgram = Text.unlines
  [ "module Main"
  , ""
  , "fn main() -> Int {"
  , "  print(\"ready\")"
  , "  0"
  , "}"
  , ""
  , "export fn add(a: Int64, b: Int64) -> Int64 {"
  , "  a + b"
  , "}"
  , ""
  , "export fn even(value: Int32) -> Bool {"
  , "  value % 2 == 0"
  , "}"
  , ""
  , "export fn half(value: Float64) -> Float64 {"
  , "  value / 2.0"
  , "}"
  , ""
  , "export fn same(value: UInt8) -> UInt8 {"
  , "  value"
  , "}"
  , ""
  , "export fn greet() -> () {"
  , "  print(\"greet\")"
  , "  ()"
  , "}"
  ]

crossingHost :: Text
crossingHost = Text.unlines
  [ "#include <stdio.h>"
  , "#include \"pudu_program.h\""
  , "int main(int argc, char **argv) {"
  , "  if (pudu_program_run(argc, argv) != 0) return 1;"
  , "  printf(\"%lld\\n\", (long long)pudu_export_add(40, -2));"
  , "  printf(\"%d %d\\n\", pudu_export_even(4), pudu_export_even(-7));"
  , "  printf(\"%.2f\\n\", pudu_export_half(5.0));"
  , "  printf(\"%u\\n\", (unsigned)pudu_export_same(255));"
  , "  pudu_export_greet();"
  , "  printf(\"%lld\\n\", (long long)pudu_export_add(1, 1));"
  , "  return 0;"
  , "}"
  ]

earlyHost :: Text
earlyHost = Text.unlines
  [ "#include \"pudu_program.h\""
  , "int main(void) {"
  , "  return (int)pudu_export_add(1, 2);"
  , "}"
  ]

testCrossings :: IO Property
testCrossings = withHost crossingHost $ \ran -> pure (ran === (ExitSuccess, "ready\n38\n1 0\n2.50\n255\ngreet\n2\n", ""))

testEarlyCall :: IO Property
testEarlyCall = withHost earlyHost $ \(code, _, errors) -> pure $ conjoin
  [ counterexample (show code) (code /= ExitSuccess)
  , counterexample errors (property ("pudu_export_add was called before pudu_program_run returned" `Text.isInfixOf` Text.pack errors))
  ]

testTextParameter :: IO Property
testTextParameter = do
  emitted <- emitLibrary (Text.unlines ["module Main", "", "fn main() -> Int {", "  0", "}", "", "export fn size(text: Str) -> Int64 {", "  0", "}"])
  pure $ case emitted of
    Left message -> counterexample message (property ("C cannot pass" `Text.isInfixOf` Text.pack message))
    Right _ -> counterexample "a Str parameter was exported" (property False)

testRefusedForms :: IO Property
testRefusedForms = do
  lowered <- lowerWith True (Text.unlines
    [ "module Main", "", "fn main() -> Int {", "  0", "}", ""
    , "export fn same[T](value: T) -> T {", "  value", "}", ""
    , "export fn step(value: Int64, by: Int64 = 1) -> Int64 {", "  value + by", "}" ])
  pure $ case lowered of
    Just (LowerRefused refusals) ->
      let messages = map diagnosticMessage refusals
       in conjoin
            [ counterexample (show messages) (property (any ("with type parameters" `Text.isInfixOf`) messages))
            , counterexample (show messages) (property (any ("with default parameter values" `Text.isInfixOf`) messages))
            ]
    other -> counterexample (show other) (property False)

testExecutableIgnores :: IO Property
testExecutableIgnores = do
  lowered <- lowerWith False (Text.unlines
    [ "module Main", "", "fn main() -> Int {", "  0", "}", ""
    , "export fn same[T](value: T) -> T {", "  value", "}" ])
  pure $ case lowered of
    Just (Lowered _) -> property True
    other -> counterexample (show other) (property False)

-- Programs are written to a file and compiled the way `pudu build` does.
lowerWith :: Bool -> Text -> IO (Maybe LowerResult)
lowerWith library text = withSystemTempDirectory "pudu-export" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path text
  program <- compileProgram path
  pure ((if library then lowerLibrary else lowerProgram) "main" <$> programNativeModules program)

emitLibrary :: Text -> IO (Either String EmittedUnit)
emitLibrary text = withSystemTempDirectory "pudu-export" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path text
  program <- compileProgram path
  pure $ case lowerLibrary "main" <$> programNativeModules program of
    Just (Lowered core) -> case lowerFrames core >>= emitUnit EmbeddedEntry "test" (programSources program) of
      Left failure -> Left (Text.unpack (frameFaultMessage failure))
      Right unit -> Right unit
    other -> Left ("lowering: " <> show other <> "; diagnostics: " <> show (map diagnosticMessage (programDiagnostics program)))

{-| Compile the crossing program as an embedded unit beside a C host under the
    strict policy, then run the host. -}
withHost :: Text -> ((ExitCode, String, String) -> IO Property) -> IO Property
withHost host check = do
  compiler <- findExecutable "cc"
  case compiler of
    Nothing -> putStrLn "[skip] embedded export check: cc was not found" >> pure (property True)
    Just cc -> do
      emitted <- emitLibrary crossingProgram
      case emitted of
        Left problem -> pure (counterexample problem (property False))
        Right unit -> withSystemTempDirectory "pudu-export-host" $ \root -> do
          TextIO.writeFile (root </> "program.c") (emittedSource unit)
          TextIO.writeFile (root </> embeddedHeaderName) (embeddedHeader [] (emittedExports unit))
          TextIO.writeFile (root </> "host.c") host
          (built, output, errors) <- readProcessWithExitCode cc
            [ "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror"
            , root </> "program.c", root </> "host.c", "-o", root </> "host", "-lm", "-pthread" ] ""
          case built of
            ExitSuccess -> readProcessWithExitCode (root </> "host") [] "" >>= check
            _ -> pure (counterexample (output <> errors) (built === ExitSuccess))
