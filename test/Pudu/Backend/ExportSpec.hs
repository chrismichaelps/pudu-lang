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
  , ("embedded exports refuse type parameters", testRefusedForms)
  , ("embedded exports run defaulted and async bodies", once <$> testDefaultedAndAsync)
  , ("executables never lower exports", testExecutableIgnores)
  , ("embedded exports carry text, records and Result to a C host", once <$> testRichCrossings)
  , ("embedded exports refuse host text that is not UTF-8", once <$> testInvalidText)
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
testCrossings = withHost crossingProgram crossingHost $ \ran -> pure (ran === (ExitSuccess, "ready\n38\n1 0\n2.50\n255\ngreet\n2\n", ""))

testEarlyCall :: IO Property
testEarlyCall = withHost crossingProgram earlyHost $ \(code, _, errors) -> pure $ conjoin
  [ counterexample (show code) (code /= ExitSuccess)
  , counterexample errors (property ("pudu_export_add was called before pudu_program_run returned" `Text.isInfixOf` Text.pack errors))
  ]

testTextParameter :: IO Property
testTextParameter = do
  emitted <- emitLibrary (Text.unlines ["module Main", "", "fn main() -> Int {", "  0", "}", "", "export fn size(values: Array[Int64]) -> Int64 {", "  0", "}"])
  pure $ case emitted of
    Left message -> counterexample message (property ("C cannot pass" `Text.isInfixOf` Text.pack message))
    Right _ -> counterexample "an Array parameter was exported" (property False)

testRefusedForms :: IO Property
testRefusedForms = do
  lowered <- lowerWith True (Text.unlines
    [ "module Main", "", "fn main() -> Int {", "  0", "}", ""
    , "export fn same[T](value: T) -> T {", "  value", "}" ])
  pure $ case lowered of
    Just (LowerRefused [refusal]) ->
      let message = diagnosticMessage refusal
       in counterexample (show message) (property ("with type parameters" `Text.isInfixOf` message))
    other -> counterexample (show other) (property False)

testDefaultedAndAsync :: IO Property
testDefaultedAndAsync = withHost program host $ \ran ->
  pure (ran === (ExitSuccess, "11\n21\n7\n24\nawaited\n0 15\nawaited\n1 rejected\n", ""))
 where
  program = Text.unlines
    [ "module Main"
    , "fn main() -> Int {"
    , "  print(show(step(2, 3)))"
    , "  print(show(step(2, 3, 10)))"
    , "  print(show(step(2, 3, 5, 2)))"
    , "  0"
    , "}"
    , "export fn step(first: Int64 = 100, required: Int64, next: Int64 = first + required, last: Int64 = next + 1) -> Int64 {"
    , "  next + last"
    , "}"
    , "async fn add(value: Int64) -> Result[Int64, Str] {"
    , "  print(\"awaited\")"
    , "  if value > 0 { Ok(value + 5) } else { Err(\"rejected\") }"
    , "}"
    , "export async fn run(value: Int64 = 10) -> Result[Int64, Str] {"
    , "  Ok(add(value).await)"
    , "}"
    ]
  host = Text.unlines
    [ "#include <stdio.h>"
    , "#include \"pudu_program.h\""
    , "int main(int argc, char **argv) {"
    , "  int64_t value = 0;"
    , "  pudu_string error;"
    , "  if (pudu_program_run(argc, argv) != 0) return 1;"
    , "  printf(\"%lld\\n\", (long long)pudu_export_step(1, 2, 10, 14));"
    , "  int status = pudu_export_run(10, &value, &error);"
    , "  printf(\"%d %lld\\n\", status, (long long)value);"
    , "  status = pudu_export_run(0, &value, &error);"
    , "  printf(\"%d %.*s\\n\", status, (int)error.length, error.bytes);"
    , "  pudu_string_release(error);"
    , "  return 0;"
    , "}"
    ]

testExecutableIgnores :: IO Property
testExecutableIgnores = do
  lowered <- lowerWith False (Text.unlines
    [ "module Main", "", "fn main() -> Int {", "  0", "}", ""
    , "export fn same[T](value: T) -> T {", "  value", "}" ])
  pure $ case lowered of
    Just (Lowered _) -> property True
    other -> counterexample (show other) (property False)

richProgram :: Text
richProgram = Text.unlines
  [ "module Main"
  , ""
  , "type Point = { x: Int64, y: Int64 }"
  , "type Named = { label: Str, at: Point }"
  , ""
  , "fn main() -> Int {"
  , "  print(\"ready\")"
  , "  0"
  , "}"
  , ""
  , "export fn shout(text: Str) -> Str {"
  , "  text + \"!\""
  , "}"
  , ""
  , "export fn moved(point: Point, by: Int64) -> Point {"
  , "  Point { x: point.x + by, y: point.y + by }"
  , "}"
  , ""
  , "export fn describe(item: Named) -> Str {"
  , "  item.label + \"@\" + item.at.x.toText()"
  , "}"
  , ""
  , "export fn tag(item: Named) -> Named {"
  , "  Named { label: item.label + \"+\", at: item.at }"
  , "}"
  , ""
  , "export fn half(value: Int64) -> Result[Int64, Str] {"
  , "  if value % 2 == 0 { Ok(value / 2) } else { Err(\"odd \" + value.toText()) }"
  , "}"
  , ""
  , "export fn check(value: Int64) -> Result[(), Str] {"
  , "  if value > 0 { Ok(()) } else { Err(\"not positive\") }"
  , "}"
  ]

richHost :: Text
richHost = Text.unlines
  [ "#include <stdio.h>"
  , "#include <string.h>"
  , "#include \"pudu_program.h\""
  , "static pudu_string text(const char *bytes) { pudu_string made = { bytes, strlen(bytes) }; return made; }"
  , "int main(int argc, char **argv) {"
  , "  pudu_string loud, described, failure, refused;"
  , "  pudu_Point start = { 1, 2 }, moved;"
  , "  pudu_Named pin, tagged;"
  , "  int64_t halved = 0;"
  , "  int status;"
  , "  if (pudu_program_run(argc, argv) != 0) return 1;"
  , "  loud = pudu_export_shout(text(\"hi\"));"
  , "  printf(\"%.*s %zu %d\\n\", (int)loud.length, loud.bytes, loud.length, loud.bytes[loud.length] == 0);"
  , "  pudu_string_release(loud);"
  , "  moved = pudu_export_moved(start, 10);"
  , "  printf(\"%lld %lld\\n\", (long long)moved.x, (long long)moved.y);"
  , "  pin.label = text(\"pin\");"
  , "  pin.at.x = 3;"
  , "  pin.at.y = 4;"
  , "  described = pudu_export_describe(pin);"
  , "  printf(\"%.*s\\n\", (int)described.length, described.bytes);"
  , "  pudu_string_release(described);"
  , "  tagged = pudu_export_tag(pin);"
  , "  printf(\"%.*s %lld\\n\", (int)tagged.label.length, tagged.label.bytes, (long long)tagged.at.y);"
  , "  pudu_string_release(tagged.label);"
  , "  status = pudu_export_half(8, &halved, &failure);"
  , "  printf(\"%d %lld\\n\", status, (long long)halved);"
  , "  status = pudu_export_half(7, &halved, &failure);"
  , "  printf(\"%d %.*s\\n\", status, (int)failure.length, failure.bytes);"
  , "  pudu_string_release(failure);"
  , "  printf(\"%d\\n\", pudu_export_half(6, NULL, NULL));"
  , "  status = pudu_export_check(1, &refused);"
  , "  printf(\"%d\", status);"
  , "  status = pudu_export_check(0, &refused);"
  , "  printf(\" %d %.*s\\n\", status, (int)refused.length, refused.bytes);"
  , "  pudu_string_release(refused);"
  , "  return 0;"
  , "}"
  ]

invalidHost :: Text
invalidHost = Text.unlines
  [ "#include \"pudu_program.h\""
  , "int main(int argc, char **argv) {"
  , "  pudu_string broken = { \"\\xff\", 1 };"
  , "  if (pudu_program_run(argc, argv) != 0) return 1;"
  , "  pudu_string_release(pudu_export_shout(broken));"
  , "  return 0;"
  , "}"
  ]

testRichCrossings :: IO Property
testRichCrossings = withHost richProgram richHost $ \ran ->
  pure (ran === (ExitSuccess, "ready\nhi! 3 1\n11 12\npin@3\npin+ 4\n0 4\n1 odd 7\n0\n0 1 not positive\n", ""))

testInvalidText :: IO Property
testInvalidText = withHost richProgram invalidHost $ \(code, _, errors) -> pure $ conjoin
  [ counterexample (show code) (code /= ExitSuccess)
  , counterexample errors (property ("pudu_export_shout was called with text that is not UTF-8" `Text.isInfixOf` Text.pack errors))
  ]

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

{-| Compile a program as an embedded unit beside a C host under the
    strict policy, then run the host. -}
withHost :: Text -> Text -> ((ExitCode, String, String) -> IO Property) -> IO Property
withHost program host check = do
  compiler <- findExecutable "cc"
  case compiler of
    Nothing -> putStrLn "[skip] embedded export check: cc was not found" >> pure (property True)
    Just cc -> do
      emitted <- emitLibrary program
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
