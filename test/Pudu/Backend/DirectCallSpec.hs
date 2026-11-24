{-| @Test.Backend.DirectCallSpec — functions with bounded call depth run in
    frames on the C stack: which functions qualify, identical output across
    owned arguments and mixed heap and direct callers, failure locations, and
    exports entering the direct body. -}
module Pudu.Backend.DirectCallSpec (directCallProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (EmittedUnit (..), EntryForm (..), emitUnit)
import Pudu.Backend.Emit.Frame.Direct (directFunctions)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerLibrary, lowerProgram, programNativeModules)
import Pudu.Compiler.Program (compileProgram, programDiagnostics, programSources)
import Pudu.Core.Frame (FrameFault (..), FrameModule)
import Pudu.Diagnostic (diagnosticMessage)
import System.Directory (findExecutable)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, once, property, (===))

directCallProperties :: [(String, IO Property)]
directCallProperties =
  [ ("direct calls select functions with bounded call depth", testSelection)
  , ("direct calls pass signed integer arguments as C locals", once <$> testTypedCalls)
  , ("typed calls borrow aggregate projections from a live caller", once <$> testBorrowedCalls)
  , ("direct calls print what heap calls print", once <$> testOutput)
  , ("direct calls report a failure at its own site", once <$> testFailure)
  , ("direct exports enter the direct body", testExportEntry)
  ]

selectionProgram :: Text
selectionProgram = Text.unlines
  [ "module Main"
  , ""
  , "fn twice(value: Int) -> Int {"
  , "  value * 2"
  , "}"
  , ""
  , "fn quad(value: Int) -> Int {"
  , "  twice(twice(value))"
  , "}"
  , ""
  , "fn fact(value: Int) -> Int {"
  , "  if value <= 1 { 1 } else { value * fact(value - 1) }"
  , "}"
  , ""
  , "fn isEven(value: Int) -> Bool {"
  , "  if value == 0 { true } else { isOdd(value - 1) }"
  , "}"
  , ""
  , "fn isOdd(value: Int) -> Bool {"
  , "  if value == 0 { false } else { isEven(value - 1) }"
  , "}"
  , ""
  , "fn inc(value: Int) -> Int {"
  , "  value + 1"
  , "}"
  , ""
  , "fn apply(step: fn(Int) -> Int, value: Int) -> Int {"
  , "  step(value)"
  , "}"
  , ""
  , "fn main() -> Int {"
  , "  print(quad(fact(3)).toText())"
  , "  print(isEven(4).toText())"
  , "  print(apply(inc, 5).toText())"
  , "  0"
  , "}"
  ]

testSelection :: IO Property
testSelection = do
  lowered <- frameModuleOf False selectionProgram
  pure $ case lowered of
    Left problem -> counterexample problem (property False)
    Right frames ->
      let direct = directFunctions frames
          shown = show (Set.toList direct)
       in conjoin
            [ counterexample shown (property (Set.member "Main.quad" direct))
            , counterexample shown (property (all (`Set.notMember` direct) ["Main.main", "Main.fact", "Main.isEven", "Main.isOdd", "Main.apply"]))
            ]

testTypedCalls :: IO Property
testTypedCalls = do
  emitted <- emitWith ExecutableEntry program
  case emitted of
    Left problem -> pure (counterexample problem (property False))
    Right unit -> do
      observed <- runExecutable program (pure . (=== (ExitSuccess, "-7\n-9223372036854775808\n", "")))
      pure (conjoin
        [ counterexample "missing typed C entry" (property ("(int64_t pudu_a0" `Text.isInfixOf` emittedSource unit))
        , observed
        ])
 where
  program = Text.unlines
    [ "module Main"
    , "fn step(value: Int64, unused: Int64) -> Int64 {"
    , "  value / 2 + value % 2"
    , "}"
    , "fn twice(value: Int64) -> Int64 {"
    , "  step(value, 0) + step(value, 0) + 1"
    , "}"
    , "fn negate(value: Int) -> Int {"
    , "  -value"
    , "}"
    , "fn main() -> Int {"
    , "  let edge = 9223372036854775808"
    , "  let minimum: Int = -edge"
    , "  print(show(twice(-7)))"
    , "  print(show(negate(edge)))"
    , "  0"
    , "}"
    ]

testBorrowedCalls :: IO Property
testBorrowedCalls = do
  emitted <- emitWith ExecutableEntry program
  case emitted of
    Left problem -> pure (counterexample problem (property False))
    Right unit -> do
      observed <- runExecutable program (pure . (=== (ExitSuccess, "4.5\n4.0\n", "")))
      pure (conjoin
        [ counterexample "missing typed borrowed parameter" (property ("const pudu_box * pudu_a0" `Text.isInfixOf` emittedSource unit))
        , observed ])
 where
  program = Text.unlines
    [ "module Main"
    , "type Sample = { level: Float64 }"
    , "type Report = { sample: Sample }"
    , "fn read(sample: Sample) -> Float64 { sample.level + 0.5 }"
    , "fn through(report: &Report) -> Float64 { read(report.sample) }"
    , "fn main() -> Int {"
    , "  let report = Report{ sample: Sample{ level: 4.0 } }"
    , "  print(display(through(&report)))"
    , "  print(display(report.sample.level))"
    , "  0", "}" ]

-- Owned text and records cross direct calls made from both a recursive (heap)
-- caller and a direct caller; every value is released exactly as before.
outputProgram :: Text
outputProgram = Text.unlines
  [ "module Main"
  , ""
  , "type Point = { x: Int, y: Int }"
  , ""
  , "fn label(name: Str, point: Point) -> Str {"
  , "  name + \"(\" + point.x.toText() + \",\" + point.y.toText() + \")\""
  , "}"
  , ""
  , "fn shifted(point: Point, by: Int) -> Point {"
  , "  Point { x: point.x + by, y: point.y - by }"
  , "}"
  , ""
  , "fn describe(name: Str, point: Point) -> Str {"
  , "  label(name, shifted(point, 1))"
  , "}"
  , ""
  , "fn countdown(value: Int, point: Point) -> Int {"
  , "  if value == 0 {"
  , "    0"
  , "  } else {"
  , "    print(describe(\"p\", point))"
  , "    countdown(value - 1, shifted(point, 10))"
  , "  }"
  , "}"
  , ""
  , "fn main() -> Int {"
  , "  print(describe(\"start\", Point { x: 1, y: 2 }))"
  , "  countdown(3, Point { x: 0, y: 0 })"
  , "}"
  ]

testOutput :: IO Property
testOutput = runExecutable outputProgram $ \ran ->
  pure (ran === (ExitSuccess, "start(2,1)\np(1,-1)\np(11,-11)\np(21,-21)\n", ""))

failureProgram :: Text
failureProgram = Text.unlines
  [ "module Main"
  , ""
  , "fn ratio(top: Int, bottom: Int) -> Int {"
  , "  top / bottom"
  , "}"
  , ""
  , "fn main() -> Int {"
  , "  print(ratio(6, 3).toText())"
  , "  ratio(1, 0)"
  , "}"
  ]

testFailure :: IO Property
testFailure = runExecutable failureProgram $ \(code, output, errors) -> pure $ conjoin
  [ code === ExitFailure 1
  , output === "2\n"
  , counterexample errors (property ("Main.pudu:4:" `Text.isInfixOf` Text.pack errors))
  ]

exportProgram :: Text
exportProgram = Text.unlines
  [ "module Main"
  , ""
  , "fn main() -> Int {"
  , "  0"
  , "}"
  , ""
  , "export fn add(a: Int64, b: Int64) -> Int64 {"
  , "  a + b"
  , "}"
  ]

testExportEntry :: IO Property
testExportEntry = do
  emitted <- emitWith EmbeddedEntry exportProgram
  pure $ case emitted of
    Left problem -> counterexample problem (property False)
    Right unit -> conjoin
      [ counterexample "no direct entry" (property ("pudu_result = pudu_direct_" `Text.isInfixOf` emittedSource unit))
      , counterexample "the export still pushes a heap frame" (property (not ("pudu_result = pudu_run_active()" `Text.isInfixOf` emittedSource unit)))
      ]

-- Programs are written to a file and compiled the way `pudu build` does.
frameModuleOf :: Bool -> Text -> IO (Either String FrameModule)
frameModuleOf library text = withSystemTempDirectory "pudu-direct" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path text
  program <- compileProgram path
  pure $ case (if library then lowerLibrary else lowerProgram) "main" <$> programNativeModules program of
    Just (Lowered core) -> either (Left . Text.unpack . frameFaultMessage) Right (lowerFrames core)
    other -> Left ("lowering: " <> show other <> "; diagnostics: " <> show (map diagnosticMessage (programDiagnostics program)))

emitWith :: EntryForm -> Text -> IO (Either String EmittedUnit)
emitWith form text = withSystemTempDirectory "pudu-direct" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path text
  program <- compileProgram path
  let lower = case form of
        EmbeddedEntry -> lowerLibrary
        ExecutableEntry -> lowerProgram
  pure $ case lower "main" <$> programNativeModules program of
    Just (Lowered core) -> case lowerFrames core >>= emitUnit form "test" (programSources program) of
      Left failure -> Left (Text.unpack (frameFaultMessage failure))
      Right unit -> Right unit
    other -> Left ("lowering: " <> show other <> "; diagnostics: " <> show (map diagnosticMessage (programDiagnostics program)))

{-| Compile a program as an executable under the strict policy and run it. -}
runExecutable :: Text -> ((ExitCode, String, String) -> IO Property) -> IO Property
runExecutable text check = do
  compiler <- findExecutable "cc"
  case compiler of
    Nothing -> putStrLn "[skip] direct call run: cc was not found" >> pure (property True)
    Just cc -> do
      emitted <- emitWith ExecutableEntry text
      case emitted of
        Left problem -> pure (counterexample problem (property False))
        Right unit -> withSystemTempDirectory "pudu-direct-run" $ \root -> do
          TextIO.writeFile (root </> "program.c") (emittedSource unit)
          (built, output, errors) <- readProcessWithExitCode cc
            [ "-std=c11", "-pedantic", "-Wall", "-Wextra", "-Werror", "-O2"
            , root </> "program.c", "-o", root </> "program", "-lm", "-pthread" ] ""
          case built of
            ExitSuccess -> readProcessWithExitCode (root </> "program") [] "" >>= check
            _ -> pure (counterexample (output <> errors) (built === ExitSuccess))
