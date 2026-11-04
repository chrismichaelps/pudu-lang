{-| @Test.Backend.OutputSpec — failed handles in isolated evaluator and native
    processes, retaining their pending bytes between output calls. -}
module Pudu.Backend.OutputSpec (outputProperties, runOutputOracle) where

import Control.Exception (onException)
import Control.Monad (void, when)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.IO.Encoding (setLocaleEncoding)
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram, programNativeModules)
import Pudu.Compiler.Program
  ( ProgramResult, compileProgram, programDependencies, programDiagnostics
  , programFolded, programIntegerKinds, programSources, rootCompileResult )
import Pudu.Diagnostic (Diagnostic, diagnosticSpan, hasErrors)
import Pudu.Diagnostic.Render (RenderStyle (PlainStyle), defaultRenderConfig, renderDiagnosticsWith)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntryFolded)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..))
import Pudu.Source (sourceName, spanSource)
import System.Directory (createFileLink, doesFileExist, findExecutable)
import System.Environment (getEnvironment, getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..), exitFailure, exitSuccess, exitWith)
import System.FilePath ((</>), takeDirectory)
import System.Info (os)
import System.IO (IOMode (WriteMode), hSetEncoding, stdout, stderr, utf8, withBinaryFile)
import System.IO.Temp (withSystemTempDirectory)
import System.Process
  ( CreateProcess (env, std_out, std_err), StdStream (UseHandle), createProcess, proc
  , readProcessWithExitCode, terminateProcess, waitForProcess )
import System.Timeout (timeout)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

outputProperties :: [(String, IO Property)]
outputProperties =
  [ ("native output failures match isolated evaluator handles", testFailures False)
  , ("native output callables match failed isolated handles", testFailures True)
  , ("native output reporting preserves failed-handle outcomes", testEntries)
  ]

{-| The runner dispatches here before setting its own buffering policy. -}
runOutputOracle :: FilePath -> IO ()
runOutputOracle path = do
  setLocaleEncoding utf8
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  program <- compileProgram path
  if hasErrors (programDiagnostics program) then exitFailure else pure ()
  case rootCompileResult program >>= compileModule of
    Nothing -> exitFailure
    Just parsed -> do
      outcome <- evaluateProgramEntryFolded (programFolded program)
        (programIntegerKinds program) (programDependencies program) "main" parsed
      case outcomeDiagnostics outcome of
        diagnostics@(_ : _) -> mapM_ (TextIO.hPutStr stderr . renderRuntime program) diagnostics >> exitFailure
        [] -> case outcomeValue outcome of
          Nothing -> exitFailure
          Just UnitValue -> exitSuccess
          Just (IntValue _ number)
            | number == 0 -> exitSuccess
            | otherwise -> exitWith (ExitFailure (fromInteger (max 1 (min 255 number))))
          Just value -> TextIO.putStrLn (renderValue value) >> exitSuccess

renderRuntime :: ProgramResult -> Diagnostic -> Text
renderRuntime program value = case filter ((== spanSource (diagnosticSpan value)) . sourceName) (programSources program) of
  source : _ -> renderDiagnosticsWith (defaultRenderConfig PlainStyle) source [value] <> "\n"
  [] -> Text.pack (show value) <> "\n"

testEntries :: IO Property
testEntries = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "entry output checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-entry-output" $ \root -> do
      original <- getExecutablePath
      let oracle = root </> "pudu"
      createFileLink original oracle
      launched <- compileC cc root "launcher" launcher
      case launched of
        Left failure -> pure (counterexample failure (False === True))
        Right runner -> conjoin <$> traverse (check cc root runner oracle)
          (["fn main() -> Str { \"x\".repeat(" <> Text.pack (show size) <> ") }" | size <- [8186, 8187, 8192, 20000 :: Int]]
           <> ["fn main() -> Result[(), Str] { printPart(\"x\".repeat(8190)) }"
              , "fn main() -> Str { \"é\".repeat(4094) }"
              , "fn main() -> Int { print(\"start\")\n 1 / 0 }"])
 where
  check cc root runner oracle body = do
    let path = root </> "Main.pudu"
    TextIO.writeFile path ("module Main\n" <> body <> "\n")
    program <- compileProgram path
    case programNativeModules program of
      Nothing -> pure (counterexample "entry source did not check" (False === True))
      Just modules -> case lowerProgram "main" modules of
        LowerRefused failures -> pure (counterexample (show failures) (False === True))
        Lowered core -> case lowerFrames core >>= emitProgram "entry-output" (programSources program) of
          Left failure -> pure (counterexample (show failure) (False === True))
          Right emitted -> do
            built <- compileC cc root "entry" emitted
            case built of
              Left failure -> pure (counterexample failure (False === True))
              Right binary -> do
                full <- doesFileExist "/dev/full"
                conjoin <$> traverse (run root runner oracle path binary body)
                  (["out-healthy", "out-read", "out-closed", "out-pipe", "out-tty"] <> ["out-full" | full]
                    <> if "1 / 0" `Text.isInfixOf` body then ["err-read", "err-closed", "err-pipe"]
                      <> ["out-mask" <> show mask | mask <- [1 .. 7 :: Int]] else [])
  run root runner oracle path binary body mode = do
    let blocked = mode `elem` ["out-mask3", "out-mask5", "out-mask6", "out-mask7"]
        limit = if blocked then 2000000 else 10000000
    environment <- getEnvironment
    let nativeProcess = (proc runner [mode, "default", binary])
          {env = Just (("NO_COLOR", "1") : filter ((/= "NO_COLOR") . fst) environment)}
    native <- observe root limit nativeProcess
    conjoin <$> traverse (\engine -> do
      inherited <- getEnvironment
      let settings = [("PUDU_EVAL", engine), ("NO_COLOR", "1")]
          process = (proc runner [mode, "default", oracle, "--native-output-oracle", path])
            {env = Just (settings <> filter (\(name, _) -> name `notElem` map fst settings) inherited)}
      interpreted <- observe root limit process
      pure $ counterexample (Text.unpack body <> ": " <> mode <> "/" <> engine
        <> ": " <> take 1100 (show native <> " vs " <> show interpreted)) $ conjoin
          [ native === interpreted
          , case native of
              Exited status _ _ -> (not blocked && status `elem` [ExitSuccess, ExitFailure 1, ExitFailure (-13)]) === True
              Waiting{} -> blocked === True ]) ["compiled", "tree"]

testFailures :: Bool -> IO Property
testFailures indirect
  | os == "mingw32" = putStrLn "[skip] output descriptor matrix requires POSIX; Windows evidence remains pending" >> pure (True === True)
  | otherwise = do
      configured <- lookupEnv "PUDU_CC"
      compiler <- findExecutable (maybe "cc" id configured)
      case compiler of
        Nothing -> pure (counterexample "output checks require a C11 compiler" (False === True))
        Just cc -> withSystemTempDirectory "pudu-output" $ \root -> do
          launched <- compileC cc root "launcher" launcher
          case launched of
            Left failure -> pure (counterexample failure (False === True))
            Right runner -> do
              oracle <- getExecutablePath
              full <- doesFileExist "/dev/full"
              results <- traverse (check cc root runner oracle full) [False, True]
              masks <- checkMasks cc root runner oracle
              pure (conjoin (masks : results))
 where
  check cc root runner oracle full errors = do
    let path = root </> "Main.pudu"
        channel = if errors then "err-" else "out-"
        modes = [(mode, "default") | mode <- ["healthy", "closed", "read", "tty"] <> ["full" | full]]
          <> [("pipe", inherited) | inherited <- ["default", "ignored", "blocked"]]
    TextIO.writeFile path (throughValues indirect
      (if errors then ["printError", "printErrorPart"] else ["print", "printPart"]) (failureProgram errors))
    program <- compileProgram path
    case programNativeModules program of
      Nothing -> pure (counterexample "output source produced no checked modules" (False === True))
      Just modules -> case lowerProgram "main" modules of
        LowerRefused failures -> pure (counterexample (show failures) (False === True))
        Lowered core -> case lowerFrames core >>= emitProgram "output-test" (programSources program) of
          Left failure -> pure (counterexample (show failure) (False === True))
          Right emitted -> do
            built <- compileC cc root "native" emitted
            case built of
              Left failure -> pure (counterexample failure (False === True))
              Right binary -> do
                results <- traverse (run runner oracle path binary channel (Just (ExitFailure 7))) modes
                pure (conjoin results)
  checkMasks cc root runner oracle = do
    let path = root </> "Main.pudu"
    TextIO.writeFile path (throughValues indirect ["printPart", "printErrorPart"] maskProgram)
    program <- compileProgram path
    case programNativeModules program of
      Nothing -> pure (counterexample "mask source produced no checked modules" (False === True))
      Just modules -> case lowerProgram "main" modules of
        LowerRefused failures -> pure (counterexample (show failures) (False === True))
        Lowered core -> case lowerFrames core >>= emitProgram "output-masks" (programSources program) of
          Left failure -> pure (counterexample (show failure) (False === True))
          Right emitted -> do
            built <- compileC cc root "native-masks" emitted
            case built of
              Left failure -> pure (counterexample failure (False === True))
              Right binary -> conjoin <$> traverse
                (run runner oracle path binary "out-" Nothing)
                [("mask" <> show mask, "default") | mask <- [1 .. 7 :: Int]]
  run runner oracle path binary channel expectedStatus (mode, inherited) = do
    let blockedMode = mode `elem` ["mask3", "mask5", "mask6", "mask7"]
        limit = if blockedMode then 2000000 else 10000000
    environment <- getEnvironment
    let nativeProcess = (proc runner [channel <> mode, inherited, binary])
          {env = Just (("NO_COLOR", "1") : filter ((/= "NO_COLOR") . fst) environment)}
    native <- observe (takeDirectory path) limit nativeProcess
    outcomes <- traverse (\engine -> do
      inheritedEnv <- getEnvironment
      let settings = [("PUDU_EVAL", engine), ("NO_COLOR", "1")]
          process = (proc runner [channel <> mode, inherited, oracle, "--native-output-oracle", path])
            {env = Just (settings <> filter (\(name, _) -> name `notElem` map fst settings) inheritedEnv)}
      interpreted <- observe (takeDirectory path) limit process
      when (native /= interpreted) $ putStrLn ("[output mismatch] " <> channel <> mode <> "/" <> inherited <> "/" <> engine
        <> ": " <> summary native <> " vs " <> summary interpreted)
      pure $ counterexample (channel <> mode <> "/" <> inherited <> "/" <> engine
        <> ": native=" <> show native <> "; evaluator=" <> show interpreted) $ conjoin
          [ native === interpreted
          , counterexample "unexpected exit or blocked output" (case native of
              Exited status _ _ -> case expectedStatus of
                Just expected -> status === expected
                Nothing -> case status of
                  ExitFailure number -> (number > 0 && number <= 206 && not blockedMode) === True
                  _ -> False === True
              Waiting _ _ -> (blockedMode && expectedStatus == Nothing) === True)
          ]) ["compiled", "tree"]
    pure (conjoin outcomes)
  summary = take 180 . show

failureProgram :: Bool -> Text
failureProgram errors = Text.unlines $
  [ "module Main", "fn main() -> Int {" ]
  <> [report <> "(show(" <> write <> "Part(\"ab\")))"
     ,report <> "(show(" <> write <> "(\"c\")))"
     ,report <> "(show(" <> write <> "(\"x\".repeat(8190))))"
     ,report <> "(show(" <> write <> "Part(\"\")))"
     ,report <> "(show(" <> write <> "(\"\")))"]
  <> concat
    [ [report <> "(show(" <> write <> "(\"x\".repeat(" <> Text.pack (show size) <> "))))"
      ,report <> "(show(" <> write <> "Part(\"é\\0\".repeat(" <> Text.pack (show size) <> "))))"]
    | size <- [0, 1, 8190, 8191, 8192, 8193, 16384 :: Int] ]
  <> ["return 7", "}"]
 where
  write = if errors then "printError" else "print"
  report = if errors then "print" else "printError"

maskProgram :: Text
maskProgram = Text.unlines
  [ "module Main"
  , "fn code(result: Result[(), Str]) -> Int {"
  , "  match result {"
  , "    case Ok(_) => 1"
  , "    case Err(message) => {"
  , "      var answer = 0"
  , "      for character in message.chars() { answer = (answer + character.code()) % 101 }"
  , "      answer + 2", "    }", "  }", "}"
  , "fn main() -> Int {"
  , "  let out = code(printPart(\"abcdefgh\"))"
  , "  let err = code(printErrorPart(\"abcdefgh\"))"
  , "  return out + err", "}" ]

throughValues :: Bool -> [Text] -> Text -> Text
throughValues False _ source = source
throughValues True names source =
  let aliases = zip names ["output" <> Text.pack (show position) | position <- [0 :: Int ..]]
      replaced = foldl' (\body (name, alias) -> Text.replace (name <> "(") (alias <> "(") body) source aliases
      declarations = Text.concat ["\n  let " <> alias <> " = " <> name | (name, alias) <- aliases]
      header = "fn main() -> Int {"
   in Text.replace header (header <> declarations) replaced

data Observation
  = Exited !ExitCode !Text !Text
  | Waiting !Text !Text
  deriving stock (Eq, Show)

observe :: FilePath -> Int -> CreateProcess -> IO Observation
observe root limit process = do
  let outputPath = root </> "observed.stdout"
      errorPath = root </> "observed.stderr"
  status <- withBinaryFile outputPath WriteMode $ \output ->
    withBinaryFile errorPath WriteMode $ \errors -> do
      (_, _, _, child) <- createProcess process{std_out = UseHandle output, std_err = UseHandle errors}
      let stop = terminateProcess child >> void (waitForProcess child)
      result <- timeout limit (waitForProcess child) `onException` stop
      case result of
        Nothing -> stop >> pure Nothing
        Just code -> pure (Just code)
  output <- TextIO.readFile outputPath
  errors <- TextIO.readFile errorPath
  pure $ case status of
    Just code -> Exited code output errors
    Nothing -> Waiting output errors

compileC :: FilePath -> FilePath -> String -> Text -> IO (Either String FilePath)
compileC cc root name source = do
  let path = root </> name <> ".c"
      binary = root </> name
  TextIO.writeFile path source
  (status, output, errors) <- readProcessWithExitCode cc
    ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", path, "-o", binary] ""
  pure $ if status == ExitSuccess && null output && null errors
    then Right binary else Left (show status <> output <> errors)

launcher :: Text
launcher = Text.unlines
  [ "#define _XOPEN_SOURCE 700"
  , "#include <fcntl.h>", "#include <signal.h>", "#include <stdlib.h>"
  , "#include <string.h>", "#include <unistd.h>"
  , "int main(int argc, char **argv) {"
  , "  if (argc < 4) return 99;"
  , "  int target = strncmp(argv[1], \"err-\", 4) == 0 ? 2 : 1;"
  , "  const char *mode = argv[1] + 4;"
  , "  if (strcmp(mode, \"pipe\") == 0) {"
  , "    int descriptors[2]; if (pipe(descriptors) != 0) return 98;"
  , "    if (close(descriptors[0]) != 0 || dup2(descriptors[1], target) < 0) return 98;"
  , "    if (close(descriptors[1]) != 0) return 98;"
  , "  } else if (strncmp(mode, \"mask\", 4) == 0) {"
  , "    int mask = mode[4] - '0';"
  , "    for (int fd = 0; fd < 3; ++fd) if ((mask & (1 << fd)) != 0 && close(fd) != 0) return 98;"
  , "  } else if (strcmp(mode, \"closed\") == 0) {"
  , "    if (close(target) != 0) return 98;"
  , "  } else if (strcmp(mode, \"read\") == 0 || strcmp(mode, \"full\") == 0) {"
  , "    int fd = open(mode[0] == 'r' ? \"/dev/null\" : \"/dev/full\", mode[0] == 'r' ? O_RDONLY : O_WRONLY);"
  , "    if (fd < 0 || dup2(fd, target) < 0) return 98;"
  , "    if (fd != target && close(fd) != 0) return 98;"
  , "  } else if (strcmp(mode, \"tty\") == 0) {"
  , "    int master = posix_openpt(O_RDWR | O_NOCTTY);"
  , "    if (master < 0 || grantpt(master) != 0 || unlockpt(master) != 0) return 97;"
  , "    int slave = open(ptsname(master), O_WRONLY | O_NOCTTY);"
  , "    if (slave < 0 || close(master) != 0 || dup2(slave, target) < 0) return 97;"
  , "    if (slave != target && close(slave) != 0) return 97;"
  , "  }"
  , "  if (signal(SIGPIPE, argv[2][0] == 'i' ? SIG_IGN : SIG_DFL) == SIG_ERR) return 96;"
  , "  if (argv[2][0] == 'b') {"
  , "    sigset_t mask; if (sigemptyset(&mask) || sigaddset(&mask, SIGPIPE) || sigprocmask(SIG_BLOCK, &mask, 0)) return 95;"
  , "  }"
  , "  execv(argv[3], argv + 3); return 94;"
  , "}" ]
