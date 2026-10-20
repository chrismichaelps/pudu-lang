{-| @Test.Backend.NativeSpec — native execution held to the tree interpreter,
    byte for byte.

    For each conformance program this runs the program in-process through the
    evaluator and as a real compiled executable through [[Pudu.Backend.Toolchain]],
    and compares standard output, rendered diagnostic text, and exit status.
    This is the test that makes "the interpreter is the semantic oracle" a
    checked fact rather than a design intention. When no C compiler is found
    the execution checks are skipped with an explicit note; they are never
    silently passed.
-}
module Pudu.Backend.NativeSpec (backendNativeProperties) where

import Control.Exception (IOException, finally, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.ControlPrograms (controlSuccessPrograms, controlRefusalPrograms)
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Backend.FloatPrograms (floatSuccessPrograms, floatRefusalPrograms)
import Pudu.Backend.IntegerPrograms (integerSuccessPrograms, integerRefusalPrograms)
import Pudu.Backend.TextMethodPrograms (textMethodSuccessPrograms, textMethodRefusalPrograms)
import Pudu.Backend.CharPrograms (charSuccessPrograms, charRefusalPrograms)
import Pudu.Backend.TuplePrograms (tupleSuccessPrograms, tupleRefusalPrograms)
import Pudu.Backend.TextPrograms (textSuccessPrograms, textRefusalPrograms)
import Pudu.Backend.FunctionPrograms (functionSuccessPrograms, functionRefusalPrograms)
import Pudu.Backend.Toolchain
  ( ToolchainFailure (..)
  , ToolchainRequest (..)
  , compileNative
  )
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram)
import Pudu.Compiler.Program
  ( ProgramResult
  , compileProgram
  , programDependencies
  , programDiagnostics
  , programFolded
  , programIntegerKinds
  , programSources
  , rootCompileResult
  )
import Pudu.Diagnostic
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticMessage
  , diagnosticSpan
  , hasErrors
  )
import qualified Pudu.Diagnostic.Native as Native
import Pudu.Diagnostic.Render
  ( RenderStyle (..)
  , defaultRenderConfig
  , renderDiagnosticsWith
  )
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntryFolded)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..))
import Pudu.Source
  ( Source
  , SourceName (SourceName)
  , emptySpan
  , newSource
  , sourceName
  , spanSource
  , unSourceName
  )
import Pudu.Version (versionText)
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import System.Directory
  ( findExecutable
  , getPermissions
  , removeFile
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO (hClose, hFlush, openTempFile, stdout)
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

backendNativeProperties :: [(String, IO Property)]
backendNativeProperties =
  [ ("native execution matches the interpreter on success programs", testSuccessConformance)
  , ("native integer operators match mathematical and interpreter results", testIntegerConformance)
  , ("native integer failures retain exact interpreter refusals", testIntegerRefusals)
  , ("native floats match IEEE answers and the interpreter", testFloatConformance)
  , ("native float operator failures retain interpreter refusals", testFloatRefusals)
  , ("native text matches independent answers and the interpreter", testTextConformance)
  , ("native text operator failures retain interpreter refusals", testTextRefusals)
  , ("native Str methods match hand-written answers and the interpreter", testTextMethodConformance)
  , ("native Str method failures retain interpreter refusals", testTextMethodRefusals)
  , ("native Char values match hand-written answers and the interpreter", testCharConformance)
  , ("native Char failures retain interpreter refusals", testCharRefusals)
  , ("native tuples match hand-written answers and the interpreter", testTupleConformance)
  , ("native tuple failures retain interpreter refusals", testTupleRefusals)
  , ("native functions match the interpreter on ordering and recursion", testFunctionConformance)
  , ("native function failures match interpreter diagnostics", testFunctionRefusals)
  , ("native scalar loop control matches the interpreter", testControlConformance)
  , ("native loop operand failures match interpreter diagnostics", testControlRefusals)
  , ("native execution matches the interpreter on exit statuses", testStatusConformance)
  , ("native refusals match the interpreter byte for byte", testRefusalConformance)
  , ("a compiler that cannot be found is E6002", testToolchainNotFound)
  , ("a compiler that cannot be started is E6003", testToolchainInvocation)
  , ("a compiler that hangs past the timeout is E6004", testToolchainTimeout)
  , ("a compiler that rejects the C is E6005", testToolchainRejected)
  , ("an output that cannot be published is E6006", testToolchainPublish)
  ]

programWith :: [Text] -> Text
programWith body =
  Text.unlines (["module Main", "", "fn main() -> Int {"] <> body <> ["}"])

successPrograms :: [(String, Text)]
successPrograms =
  [ ("arithmetic and comparisons", programWith
      [ "  var first = 1 + 2 * 3"
      , "  var second = first - 4"
      , "  var third = second * 5 / 2"
      , "  if first > second {"
      , "    print(display(first))"
      , "  } else {"
      , "    print(display(second))"
      , "  }"
      , "  return third"
      ])
  , ("if and else values", programWith
      [ "  var chosen = if 1 < 2 { 10 } else { 20 }"
      , "  return chosen"
      ])
  , ("while with accumulating locals", programWith
      [ "  var total = 0"
      , "  var index = 0"
      , "  while index < 10 {"
      , "    total = total + index"
      , "    index = index + 1"
      , "  }"
      , "  return total"
      ])
  , ("early return", programWith
      [ "  var index = 0"
      , "  while index < 5 {"
      , "    if index == 3 {"
      , "      return 7"
      , "    }"
      , "    index = index + 1"
      , "  }"
      , "  return 1"
      ])
  , ("print of integers, booleans, and strings", programWith
      [ "  print(\"literal\")"
      , "  print(display(42))"
      , "  print(display(true))"
      , "  return 0"
      ])
  , ("unary operators", programWith
      [ "  var value = 0 - 21"
      , "  var flipped = !false"
      , "  if flipped {"
      , "    return 0 - value"
      , "  }"
      , "  return value"
      ])
  ]

statusPrograms :: [(String, Text)]
statusPrograms =
  [ ("wide entry " <> Text.unpack kind <> " " <> show value, Text.unlines ["module Main", "fn main() -> " <> kind <> " { " <> Text.pack (show value) <> " }"])
  | let boundary = 2^(127::Int) :: Integer
  , (kind, values) <- [("Int128", [-boundary,-1,0,1,255,256,boundary-1]), ("UInt128", [0,1,255,256,boundary,2*boundary-1])]
  , value <- values ]
  <> [("wide deferred positive entry", "module Main\nfn main() -> Int128 { let value = 170141183460469231731687303715884105728\n let minimum: Int128 = -value\n return value }\n")]
  <>
  [ ("UInt maximum entry", "module Main\nfn main() -> UInt { 18446744073709551615 }\n")
  , ("UInt8 maximum entry", "module Main\nfn main() -> UInt8 { 255u8 }\n")
  , ("UInt16 zero entry", "module Main\nfn main() -> UInt16 { 0 }\n")
  , ("UInt32 maximum entry", "module Main\nfn main() -> UInt32 { 4294967295u32 }\n")
  , ("UInt64 maximum entry", "module Main\nfn main() -> UInt64 { 18446744073709551615u64 }\n")
  , ("Int8 negative minimum entry", "module Main\nfn main() -> Int8 { -128i8 }\n")
  , ("Int8 positive entry", "module Main\nfn main() -> Int8 { 127 }\n")
  , ("Int16 positive entry clamps", "module Main\nfn main() -> Int16 { 32767 }\n")
  , ("Int32 negative entry clamps", "module Main\nfn main() -> Int32 { -2147483648i32 }\n")
  , ("Int64 positive entry clamps", "module Main\nfn main() -> Int64 { 9223372036854775807i64 }\n")
  , ("deferred positive boundary clamps to 255", programWith
      [ "  let value = 9223372036854775808"
      , "  let minimum: Int = -value"
      , "  return value"
      ])
  , ("zero exits zero", programWith ["  return 0"])
  , ("a small nonzero result exits as itself", programWith ["  return 3"])
  , ("a result above 255 clamps", programWith ["  return 300"])
  , ("a negative result clamps to one", programWith ["  return 0 - 5"])
  ]

refusalPrograms :: [(String, Text)]
refusalPrograms =
  [ ("division by zero", programWith
      [ "  var value = 10 / 0"
      , "  return value"
      ])
  , ("add overflow", programWith
      [ "  var value = 9223372036854775807 + 1"
      , "  return value"
      ])
  , ("subtract overflow", programWith
      [ "  var value = 0 - 9223372036854775807"
      , "  var smaller = value - 2"
      , "  return smaller"
      ])
  , ("multiply overflow", programWith
      [ "  var value = 9223372036854775807 * 2"
      , "  return value"
      ])
  , ("divide overflow", programWith
      [ "  var value = 0 - 9223372036854775807 - 1"
      , "  return value / (0 - 1)"
      ])
  , ("negate overflow", programWith
      [ "  var value = 0 - 9223372036854775807 - 1"
      , "  return -value"
      ])
  ]

testSuccessConformance :: IO Property
testSuccessConformance = do
  outcomes <- mapM (uncurry conformance) successPrograms
  pure (conjoin outcomes)

testControlConformance :: IO Property
testControlConformance = conjoin <$> mapM (uncurry conformance) controlSuccessPrograms

testControlRefusals :: IO Property
testControlRefusals = conjoin <$> mapM (uncurry conformance) controlRefusalPrograms

testFunctionConformance :: IO Property
testFunctionConformance = conjoin <$> mapM (uncurry conformance) functionSuccessPrograms

testFunctionRefusals :: IO Property
testFunctionRefusals = conjoin <$> mapM (uncurry conformance) functionRefusalPrograms

testIntegerConformance :: IO Property
testIntegerConformance = conjoin <$> mapM run integerSuccessPrograms
 where
  run (label, source, expected) = conformanceExpecting (Just (expected, "", 0)) label source

testFloatConformance :: IO Property
testFloatConformance = conjoin <$> mapM run floatSuccessPrograms
 where
  run (label, source, expected) = conformanceExpecting (Just (expected, "", 0)) label source

testTextConformance :: IO Property
testTextConformance = conjoin <$> mapM run textSuccessPrograms
 where
  run (label, source, expected) = conformanceExpecting (Just (expected, "", 0)) label source

testTextMethodConformance :: IO Property
testTextMethodConformance = conjoin <$> mapM run textMethodSuccessPrograms
 where
  run (label, source, expected) = conformanceExpecting (Just (expected, "", 0)) label source

testCharConformance :: IO Property
testCharConformance = conjoin <$> mapM run charSuccessPrograms
 where
  run (label, source, expected) = conformanceExpecting (Just (expected, "", 0)) label source

testCharRefusals :: IO Property
testCharRefusals = conjoin <$> mapM (uncurry conformance) charRefusalPrograms

testTupleConformance :: IO Property
testTupleConformance = conjoin <$> mapM run tupleSuccessPrograms
 where
  run (label, source, expected) = conformanceExpecting (Just (expected, "", 0)) label source

testTupleRefusals :: IO Property
testTupleRefusals = conjoin <$> mapM (uncurry conformance) tupleRefusalPrograms

testTextMethodRefusals :: IO Property
testTextMethodRefusals = conjoin <$> mapM (uncurry conformance) textMethodRefusalPrograms

testTextRefusals :: IO Property
testTextRefusals = conjoin <$> mapM (uncurry conformance) textRefusalPrograms

testFloatRefusals :: IO Property
testFloatRefusals = conjoin <$> mapM (uncurry conformance) floatRefusalPrograms

testIntegerRefusals :: IO Property
testIntegerRefusals = conjoin <$> mapM (uncurry conformance) integerRefusalPrograms

testStatusConformance :: IO Property
testStatusConformance = do
  outcomes <- mapM (uncurry conformance) statusPrograms
  pure (conjoin outcomes)

testRefusalConformance :: IO Property
testRefusalConformance = do
  outcomes <- mapM (uncurry conformance) refusalPrograms
  pure (conjoin outcomes)

{-| Write the program as an ordinary file whose name matches its module, run it
    both ways, and hold the two runs to each other. -}
conformance :: String -> Text -> IO Property
conformance = conformanceExpecting Nothing

conformanceExpecting :: Maybe (Text, Text, Int) -> String -> Text -> IO Property
conformanceExpecting expected label programText = withSystemTempDirectory "pudu-native" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path programText
  available <- compilerAvailable
  if not available
    then do
      putStrLn "[skip] no C compiler found (PUDU_CC unset and cc not on PATH); native execution checks skipped"
      pure (property True)
    else do
      program <- compileProgram path
      interpreted <- interpret root program
      case interpreted of
        Left problem -> pure (counterexample (label <> ": interpreter: " <> problem) False)
        Right (interpOut, interpErr, interpStatus) -> do
          native <- buildAndRun root program
          case native of
            Left problem -> pure (counterexample (label <> ": native: " <> problem) False)
            Right (nativeOut, nativeErr, nativeStatus, warnings) -> pure $ conjoin $
              [ counterexample (label <> ": stdout differs; interpreter=" <> show interpOut <> " native=" <> show nativeOut)
                  (nativeOut === interpOut)
              , counterexample (label <> ": stderr differs; interpreter=" <> show interpErr <> " native=" <> show nativeErr)
                  (nativeErr === interpErr)
              , counterexample (label <> ": status differs; interpreter=" <> show interpStatus <> " native=" <> show nativeStatus)
                  (nativeStatus === interpStatus)
              , counterexample (label <> ": the generated C drew compiler warnings: " <> Text.unpack warnings)
                  (warnings === Text.empty)
              ] <> maybe []
                (\answer -> [counterexample (label <> ": mathematical result differs")
                  ((interpOut, interpErr, interpStatus) === answer)]) expected

{-| The interpreter side, mirroring the `pudu` executable's run path: standard
    output captured from the evaluator itself, diagnostics rendered with the
    interpreter's own renderer in plain style, and the exit-status arithmetic
    mirrored from `reportResult` (0 stays 0, everything else is 1..255, a run
    that reported anything fails). -}
interpret :: FilePath -> ProgramResult -> IO (Either String (Text, Text, Int))
interpret captureRoot program
  | hasErrors diagnostics =
      pure (Left ("compile diagnostics: " <> show (map diagnosticCodeText (map diagnosticCode diagnostics))))
  | otherwise = case rootCompileResult program >>= compileModule of
      Nothing -> pure (Left "the program produced no module")
      Just parsed -> do
        (outcome, captured) <- captureStdout captureRoot $
          evaluateProgramEntryFolded
            (programFolded program)
            (programIntegerKinds program)
            (programDependencies program)
            "main"
            parsed
        let reported = outcomeDiagnostics outcome
            runtimeText = Text.concat [renderLikeCli program value <> "\n" | value <- reported]
            resultText = case outcomeValue outcome of
              Just value
                | null reported
                , not (isIntOrUnit value) -> captured <> renderValue value <> "\n"
              _ -> captured
            status
              | not (null reported) = 1
              | otherwise = case outcomeValue outcome of
                  Nothing -> 1
                  Just UnitValue -> 0
                  Just (IntValue _ number) ->
                    if number == 0 then 0 else fromInteger (max 1 (min 255 number))
                  Just _ -> 0
        pure (Right (resultText, runtimeText, status))
 where
  diagnostics = programDiagnostics program
  isIntOrUnit value = case value of
    IntValue{} -> True
    UnitValue -> True
    _ -> False

{-| The CLI's own diagnostic rendering, for a program's sources, in plain
    style: one diagnostic at a time, exactly as `runCompiledProgram` writes
    each runtime diagnostic to standard error. -}
renderLikeCli :: ProgramResult -> Diagnostic -> Text
renderLikeCli program value = case sourceFor value of
  Nothing ->
    "error["
      <> diagnosticCodeText (diagnosticCode value)
      <> "]: "
      <> diagnosticMessage value
      <> "\n  --> "
      <> unSourceName (spanSource (diagnosticSpan value))
  Just source -> renderDiagnosticsWith (defaultRenderConfig PlainStyle) source [value]
 where
  sourceFor diagnostic =
    let expected = spanSource (diagnosticSpan diagnostic)
        matches = filter ((== expected) . sourceName) (programSources program)
     in case matches of
          found : _ -> Just found
          [] -> Nothing

captureStdout :: FilePath -> IO a -> IO (a, Text)
captureStdout directory action = do
  (path, handle) <- openTempFile directory "capture"
  saved <- hDuplicate stdout
  hDuplicateTo handle stdout
  outcome <- try (action `finally` (hFlush stdout >> hDuplicateTo saved stdout))
  hClose saved
  hClose handle
  case outcome of
    Left problem -> do
      removeFile path
      ioError (problem :: IOException)
    Right value -> do
      captured <- TextIO.readFile path
      removeFile path
      pure (value, captured)

buildAndRun :: FilePath -> ProgramResult -> IO (Either String (Text, Text, Int, Text))
buildAndRun root program = case rootCompileResult program >>= compileModule of
  Nothing -> pure (Left "the program did not compile")
  Just parsed -> case lowerProgram "main" (rootCompileResult program >>= \result -> nativeTypes (compileTypes result) (compileSchemes result)) parsed of
    LowerRefused refusals ->
      pure (Left ("lowering refused: " <> show (map diagnosticMessage refusals)))
    Lowered core -> case lowerFrames core >>= emitProgram versionText (programSources program) of
      Left failure -> pure (Left ("frame emission failed: " <> show failure))
      Right emitted -> do
        let executable = root </> "Main.bin"
            request =
              ToolchainRequest
                { toolchainSource = emitted
                , toolchainOutput = executable
                }
        compiled <- compileNative request
        case compiled of
          Left failure -> pure (Left ("toolchain failure: " <> show failure))
          Right warnings -> do
            (code, out, err) <- readProcessWithExitCode executable [] ""
            pure (Right (Text.pack out, Text.pack err, statusOf code, warnings))
 where
  statusOf ExitSuccess = 0
  statusOf (ExitFailure number) = number

compilerAvailable :: IO Bool
compilerAvailable = do
  override <- lookupEnv "PUDU_CC"
  case override of
    Just value | not (null value) -> pure True
    _ -> maybe False (const True) <$> findExecutable "cc"

{-| Run an action with environment variables changed, restoring whatever was
    there before however the action ends. -}
withEnvironment :: [(String, Maybe String)] -> IO a -> IO a
withEnvironment changes action = do
  saved <- mapM save (map fst changes)
  mapM_ apply changes
  action `finally` mapM_ restore saved
 where
  save name = (,) name <$> lookupEnv name
  apply (name, Nothing) = unsetEnv name
  apply (name, Just value) = setEnv name value
  restore (name, value) = maybe (unsetEnv name) (setEnv name) value

writeExecutable :: FilePath -> Text -> IO ()
writeExecutable path body = do
  TextIO.writeFile path body
  permissions <- getPermissions path
  setPermissions path (setOwnerExecutable True permissions)

toolchainSpan :: IO Source
toolchainSpan = newSource (SourceName "toolchain.pudu") "module Main\n"

toolchainRequest :: FilePath -> ToolchainRequest
toolchainRequest root =
  ToolchainRequest
    { toolchainSource = "int main(void) { return 0; }"
    , toolchainOutput = root </> "out"
    }

testToolchainNotFound :: IO Property
testToolchainNotFound = withSystemTempDirectory "pudu-toolchain" $ \root -> do
  source <- toolchainSpan
  let spanValue = emptySpan source
  {-| An empty search path would make `findExecutable` throw rather than
      answer, so the compiler is hidden by searching an empty directory. -}
  withEnvironment [("PUDU_CC", Nothing), ("PATH", Just root)] $ do
    failure <- compileNative (toolchainRequest root)
    pure $ conjoin
      [ counterexample (show failure) (failure === Left (ToolchainNotFound "cc"))
      , diagnosticCodeText (diagnosticCode (Native.toolchainNotFound spanValue "cc")) === "E6002"
      ]

testToolchainInvocation :: IO Property
testToolchainInvocation = withSystemTempDirectory "pudu-toolchain" $ \root -> do
  source <- toolchainSpan
  let spanValue = emptySpan source
  withEnvironment [("PUDU_CC", Just (root </> "missing-compiler"))] $ do
    failure <- compileNative (toolchainRequest root)
    pure $ case failure of
      Left (ToolchainInvocation _) ->
        diagnosticCodeText (diagnosticCode (Native.toolchainInvocationFailed spanValue "reason")) === "E6003"
      other -> counterexample ("expected ToolchainInvocation, got " <> show other) False

testToolchainTimeout :: IO Property
testToolchainTimeout = withSystemTempDirectory "pudu-toolchain" $ \root -> do
  source <- toolchainSpan
  let spanValue = emptySpan source
      script = root </> "hanging-cc"
  writeExecutable script "#!/bin/sh\nexec sleep 30\n"
  withEnvironment [("PUDU_CC", Just script), ("PUDU_CC_TIMEOUT", Just "1")] $ do
    failure <- compileNative (toolchainRequest root)
    pure $ case failure of
      Left (ToolchainTimedOut seconds) -> conjoin
        [ counterexample ("expected a one-second timeout, got " <> show seconds) (seconds === 1)
        , diagnosticCodeText (diagnosticCode (Native.toolchainTimedOut spanValue seconds)) === "E6004"
        ]
      other -> counterexample ("expected ToolchainTimedOut, got " <> show other) False

testToolchainRejected :: IO Property
testToolchainRejected = withSystemTempDirectory "pudu-toolchain" $ \root -> do
  source <- toolchainSpan
  let spanValue = emptySpan source
      script = root </> "rejecting-cc"
  writeExecutable script "#!/bin/sh\necho \"generated.c:1:1: error: boom\" >&2\nexit 1\n"
  withEnvironment [("PUDU_CC", Just script)] $ do
    failure <- compileNative (toolchainRequest root)
    pure $ case failure of
      Left (ToolchainRejected output) -> conjoin
        [ counterexample ("the compiler's words were lost: " <> show output)
            (property (Text.isInfixOf "boom" output))
        , diagnosticCodeText (diagnosticCode (Native.toolchainRejected spanValue output)) === "E6005"
        ]
      other -> counterexample ("expected ToolchainRejected, got " <> show other) False

testToolchainPublish :: IO Property
testToolchainPublish = withSystemTempDirectory "pudu-toolchain" $ \root -> do
  source <- toolchainSpan
  let spanValue = emptySpan source
      script = root </> "silent-cc"
  writeExecutable script "#!/bin/sh\nexit 0\n"
  withEnvironment [("PUDU_CC", Just script)] $ do
    failure <- compileNative (toolchainRequest root)
    pure $ case failure of
      Left (ToolchainPublishFailed _) ->
        diagnosticCodeText (diagnosticCode (Native.toolchainPublishFailed spanValue "reason")) === "E6006"
      other -> counterexample ("expected ToolchainPublishFailed, got " <> show other) False
