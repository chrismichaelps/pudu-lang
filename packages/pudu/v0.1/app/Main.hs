{-| @Program.Cli.Module — the pudu command line entry point -}
module Main (main) where

import Control.Monad (unless, when)
import Control.Exception (IOException, bracket, try)
import System.IO.Temp (withSystemTempDirectory)
import Data.List (sort, sortOn)
import Data.Maybe (fromMaybe)
import GHC.Conc (getNumCapabilities, getNumProcessors, setNumCapabilities)
import Pudu.Version (versionText, languageConstraint)
import Data.Text (Text)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Directory
  ( canonicalizePath
  , getFileSize
  , getModificationTime
  , doesPathExist
  , pathIsSymbolicLink
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getCurrentDirectory
  , listDirectory
  )
import System.FilePath
  ( (</>)
  , dropTrailingPathSeparator
  , takeBaseName
  , takeDirectory
  , takeExtension
  , takeFileName
  )
import System.IO.Error (isDoesNotExistError, isFullError, isPermissionError)
import Pudu.Bundle (Bundle (..), attachedBundle, bundleOf, materialise, writeBundled)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , programDependencies
  , programIntegerKinds
  , programDocs
  , rootCompileResult
  )
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry, evaluateProgramTallied)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..))
import Pudu.Doc (DocIndex, indexEntries, renderEntryLines)
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Lsp.Server (runServer)
import Pudu.Doc.Json (encodeIndex, escapeJson)
import Pudu.Semantic (Resolution (..), Symbol (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Doc.Search (Match (..), searchText)
import Pudu.Doc.Site (renderSite)
import Pudu.Diagnostic (Diagnostic, diagnosticSpan, hasErrors)
import Pudu.Diagnostic.Render
  ( RenderStyle (..)
  , defaultRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Repl (ReplOptions (..), runRepl)
import Pudu.Source (Source, SourceName (SourceName), newSource, sourceName, spanSource)
import GHC.IO.Encoding (setLocaleEncoding)
import System.Environment (getArgs, getExecutablePath, lookupEnv, setEnv, unsetEnv)
import System.Process
  ( ProcessHandle
  , getProcessExitCode
  , spawnProcess
  , terminateProcess
  , waitForProcess
  )
import Control.Concurrent (threadDelay)
import Data.Time.Clock (UTCTime)
import System.Exit (ExitCode (ExitFailure), exitFailure, exitSuccess, exitWith)
import System.IO
  ( BufferMode (LineBuffering)
  , hIsTerminalDevice
  , hPutStrLn
  , hSetBuffering
  , hSetEncoding
  , stderr
  , stdout
  , utf8
  )

main :: IO ()
main = do
  readAndWriteUtf8
  useEveryCore
  carried <- attachedBundle
  case carried of
    Just bundle -> runBundled bundle
    Nothing -> runCommand

{-| Read and write text as UTF-8, whatever the machine says its language is.

    A source file is UTF-8 by definition, so what a program means cannot depend
    on the environment of the machine compiling it. Without this it does: text
    is decoded with the locale's encoding, and a machine with no locale set
    decodes as ASCII — so a file carrying an em dash cannot be read at all, and
    the failure arrives as "cannot read module", naming a file that is present
    and readable.

    That is not a hypothetical environment. A container built from a minimal
    image has no locale, and neither does a program started with its
    environment cleared, which is how a service is often run.

    The handles are set as well as the default, because the two standard ones
    are open before this runs and keep the encoding they were opened with —
    leaving a diagnostic that contains an em dash unable to be printed on the
    same machine that could not read it. -}
readAndWriteUtf8 :: IO ()
readAndWriteUtf8 = do
  setLocaleEncoding utf8
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8

{-| Give the runtime the cores the machine has.

    A threaded build still runs Haskell on one capability unless it is told
    otherwise, and nothing about a server says so: `Std.Http.Server` starts
    sixteen workers, and all sixteen shared one core. Measured over
    `bench/request.mjs`, saying this raised a fixed reply from 473 to 1417
    requests a second and a rendered page from 325 to 970.

    Set here rather than linked in, both because a reader can see it and
    because it can be conditional: a capability count other than one was asked
    for on the command line, and an explicit choice is not overridden. A
    compile is no slower in wall time for it — what the extra cores do there is
    collect garbage. -}
useEveryCore :: IO ()
useEveryCore = do
  chosen <- getNumCapabilities
  when (chosen <= 1) (setNumCapabilities =<< getNumProcessors)

{-| Run a program, and run it again whenever a source under it changes.

    The loop somebody writing a service actually wants: change a file, see the
    change. Without it every edit costs a stop, a scroll back for the command,
    and a start, which is small enough to tolerate and frequent enough to
    dominate an afternoon.

    The program runs as a separate process rather than on another thread of
    this one. A service holds a socket, and the operating system is the only
    thing that reliably lets go of one — a cancelled thread leaves the port
    bound for long enough that the next start fails, and the failure looks like
    a mistake in the program rather than in the reloading. Restarting a process
    costs milliseconds and cannot leak a listener.

    Every `.pudu` file under the program's own directory is watched rather than
    only the ones it imports. Watching the import graph would miss the file
    that is about to be imported: a new module is invisible until something
    imports it, and the edit that adds the import is the one a reader most
    expects to see picked up.

    A program that stops on its own is not restarted, and the watch continues.
    That is what makes the loop usable while a program is still crashing at
    start-up: the failure is on screen, the fix is a save away, and nothing had
    to be typed in between. -}
watchProgram :: RenderStyle -> FilePath -> [String] -> IO ()
watchProgram _style path carried = do
  present <- doesFileExist path
  unless present $ do
    hPutStrLn stderr ("pudu run: cannot read " <> path)
    exitFailure
  self <- getExecutablePath
  root <- watchedRoot path
  -- What this loop says is worth nothing late. Its output is a handful of
  -- short lines between a save and a restart, and held in a buffer they
  -- arrive after the thing they were meant to announce.
  hSetBuffering stdout LineBuffering
  TextIO.putStrLn (Text.pack ("watching " <> root))
  stamps <- sourceStamps root
  follow self root stamps
 where
  follow self root stamps = do
    settled <- bracket
      (startWatched self path carried)
      stopWatched
      (\_ -> awaitChange root stamps)
    follow self root settled

  awaitChange root stamps = do
    threadDelay pollMicroseconds
    fresh <- sourceStamps root
    if fresh == stamps
      then awaitChange root stamps
      else do
        settled <- settle root fresh
        if settled == stamps
          then awaitChange root stamps
          else do
            TextIO.putStrLn (Text.pack (changedLine (changedNames stamps settled)))
            pure settled

stopWatched :: ProcessHandle -> IO ()
stopWatched running = do
  stopped <- getProcessExitCode running
  case stopped of
    Just _ -> pure ()
    Nothing -> do
      terminateProcess running
      _ <- waitForProcess running
      pure ()

settle :: FilePath -> [(FilePath, (UTCTime, Integer))] -> IO [(FilePath, (UTCTime, Integer))]
settle root previous = do
  threadDelay 100000
  current <- sourceStamps root
  if current == previous then pure current else settle root current

{-| How long to wait between looks.

    Short enough that a save feels answered and long enough that the loop is
    not a program that spins. A quarter of a second is under what a person
    notices between saving and looking. -}
pollMicroseconds :: Int
pollMicroseconds = 250000

{-| Start the program, as this same executable running it without watching. -}
startWatched :: FilePath -> FilePath -> [String] -> IO ProcessHandle
startWatched self path carried = spawnProcess self (["run", path] <> carried)

{-| What was changed, said by name.

    Named rather than counted, because the useful thing after a restart is
    seeing that the file it noticed is the file that was saved — an editor that
    writes a backup beside the source will otherwise restart a service for
    reasons nobody can see. -}
changedLine :: [FilePath] -> String
changedLine [] = "a source changed, starting again"
changedLine [one] = takeFileName one <> " changed, starting again"
changedLine several =
  show (length several) <> " files changed, starting again"

changedNames :: [(FilePath, (UTCTime, Integer))] -> [(FilePath, (UTCTime, Integer))] -> [FilePath]
changedNames before after =
  Map.keys (Map.differenceWith unchanged (Map.fromList after) (Map.fromList before))
    <> Map.keys (Map.difference (Map.fromList before) (Map.fromList after))
 where
  unchanged current previous = if current == previous then Nothing else Just current

{-| The directory whose sources are watched.

    The project root when the program sits in one, so that a service in `src`
    still notices a change to a module in `test` or to a sibling directory the
    manifest names. The program's own directory otherwise. -}
watchedRoot :: FilePath -> IO FilePath
watchedRoot path = do
  full <- canonicalizePath path
  let here = takeDirectory full
  found <- nearestManifest here
  pure (fromMaybe here found)

{-| The nearest directory at or above this one holding a manifest. -}
nearestManifest :: FilePath -> IO (Maybe FilePath)
nearestManifest directory = do
  present <- doesFileExist (directory </> "pudu.toml")
  if present
    then pure (Just directory)
    else do
      let above = takeDirectory directory
      if above == directory then pure Nothing else nearestManifest above

{-| Every source under a directory, with when it was last written.

    Sorted, so that two readings can be compared directly. Directories whose
    contents are written by tools rather than by people are skipped: watching
    `.pudu` files a build produced would restart the program in response to its
    own output. -}
sourceStamps :: FilePath -> IO [(FilePath, (UTCTime, Integer))]
sourceStamps root = sort <$> walk Set.empty root
 where
  walk ancestors directory = do
    resolved <- try (canonicalizePath directory) :: IO (Either IOException FilePath)
    case resolved of
      Left _ -> pure []
      Right canonical
        | Set.member canonical ancestors -> pure []
        | otherwise -> do
            entries <- try (listDirectory directory) :: IO (Either IOException [FilePath])
            case entries of
              Left _ -> pure []
              Right names -> concat <$> mapM (one (Set.insert canonical ancestors) directory) names
  one ancestors directory name
    | ignored name = pure []
    | otherwise = do
        let full = directory </> name
        isDirectory <- doesDirectoryExist full
        if isDirectory
          then walk ancestors full
          else
            if takeExtension full == ".pudu" || name == "pudu.toml"
              then do
                stamp <- try ((,) <$> getModificationTime full <*> getFileSize full)
                  :: IO (Either IOException (UTCTime, Integer))
                pure (either (const []) (\at -> [(full, at)]) stamp)
              else pure []
  ignored name = name `elem` [".git", ".pudu", "dist-newstyle", "node_modules", "target"]

{-| Run the program attached to this executable.

    Nothing about the command line is consulted: a bundled executable is the
    program, so its arguments belong to the program rather than to the
    compiler, and a bundle that read `run` or `--help` out of them would take
    them away from it. -}
runBundled :: Bundle -> IO ()
runBundled bundle = withSystemTempDirectory "pudu-bundle" $ \root -> do
  style <- detectStyle
  entry <- materialise root bundle
  withEnvironment "PUDU_LIB" root (runProgram style entry)

{-| Run an action with one environment variable set, restoring it afterwards. -}
withEnvironment :: String -> String -> IO a -> IO a
withEnvironment name value action =
  bracket (lookupEnv name) restore (\_ -> setEnv name value >> action)
 where
  restore previous = case previous of
    Just held -> setEnv name held
    Nothing -> unsetEnv name

runCommand :: IO ()
runCommand = do
  arguments <- getArgs
  style <- detectStyle
  case arguments of
    [] -> startRepl style Nothing
    ("repl" : rest) -> startRepl style (listToPath rest)
    ("check" : paths) -> checkPaths style paths
    ("run" : "--watch" : path : carried) -> watchProgram style path carried
    ("run" : path : "--watch" : carried) -> watchProgram style path carried
    ("run" : path : _) -> runProgram style path
    ("explain" : path : _) -> explainProgram style path
    ("run" : []) -> do
      hPutStrLn stderr "pudu run: no file given"
      exitFailure
    ("build" : path : "-o" : target : _) -> buildProgram style path target
    ("build" : path : _) -> buildProgram style path (defaultTargetName path)
    ("build" : []) -> do
      hPutStrLn stderr "pudu build: no file given"
      exitFailure
    ("test" : paths) -> testPaths style paths
    ["init", path] -> initProject (Just path)
    ["init"] -> initProject Nothing
    ("init" : _) -> hPutStrLn stderr "usage: pudu init [directory]" >> exitFailure
    ("lsp" : _) -> runServer
    ("fmt" : "--check" : paths) -> formatPaths CheckOnly paths
    ("fmt" : "--stdout" : paths) -> formatPaths ToStdout paths
    ("fmt" : paths) -> formatPaths InPlace paths
    ("api" : "--json" : paths) -> apiPaths paths
    ("doc" : "--json" : paths) -> documentPaths JsonOutput paths
    ("doc" : "--html" : paths) -> documentPaths HtmlOutput paths
    ("doc" : paths) -> documentPaths TextOutput paths
    ("search" : query : paths) -> searchPaths (Text.pack query) paths
    ("search" : []) -> do
      hPutStrLn stderr "pudu search: no query given"
      exitFailure
    ("--version" : _) -> TextIO.putStrLn versionLine
    ("version" : _) -> TextIO.putStrLn versionLine
    ("--help" : _) -> usage
    ("help" : _) -> usage
    (unknown : _) -> do
      hPutStrLn stderr ("pudu: unknown command '" <> unknown <> "'")
      usage
      exitFailure

listToPath :: [String] -> Maybe FilePath
listToPath values = case values of
  path : _ -> Just path
  [] -> Nothing

startRepl :: RenderStyle -> Maybe FilePath -> IO ()
startRepl style initial =
  runRepl ReplOptions{replStyle = style, replInitialLoad = initial}

{-| Check every named file, report all diagnostics, and fail only after the last
    one so a broken first file cannot hide the rest. -}
checkPaths :: RenderStyle -> [FilePath] -> IO ()
checkPaths style paths
  | null paths = do
      hPutStrLn stderr "pudu check: no files given"
      exitFailure
  | otherwise = do
      results <- mapM (checkOne style) paths
      if or results then exitFailure else exitSuccess

checkOne :: RenderStyle -> FilePath -> IO Bool
checkOne style path = do
  program <- compileProgram path
  let diagnostics = programDiagnostics program
  unless (null diagnostics) $
    TextIO.putStrLn (renderProgramDiagnostics style program diagnostics)
  TextIO.putStrLn (Text.pack path <> ": " <> renderSummary diagnostics)
  pure (hasErrors diagnostics)

{-| Compile a program and run its entry point.

    The entry point is `main` in the root module. Its dependencies are linked
    first, in dependency order, so a call into an imported module — including
    the standard library — finds the function it named.

    A program with errors is not run. Evaluating a module whose meaning was
    never established produces a second, less useful account of the same
    defect. -}
{-| Run a program and say what running it cost.

    A Pudu program has no machine code to read, so the honest account of what it
    does is what the evaluator did: the names it looked up, the closures it
    called, the expressions of each kind it walked. Those are the costs this
    implementation actually has, and the ones a reader optimising it can act on.

    A count is a fact about the program, not a time, so it does not move when
    the machine is busy and two runs of the same program agree. -}
explainProgram :: RenderStyle -> FilePath -> IO ()
explainProgram style path = do
  program <- compileProgram path
  let diagnostics = programDiagnostics program
  unless (null diagnostics) $
    TextIO.putStrLn (renderProgramDiagnostics style program diagnostics)
  if hasErrors diagnostics
    then exitFailure
    else case rootCompileResult program >>= compileModule of
      Nothing -> do
        hPutStrLn stderr "pudu explain: the program produced no module"
        exitFailure
      Just parsed -> do
        (outcome, counted) <-
          evaluateProgramTallied
            (programIntegerKinds program)
            (programDependencies program)
            entryPointName
            parsed
        mapM_ (TextIO.putStrLn . renderRuntime style program) (outcomeDiagnostics outcome)
        TextIO.putStrLn (renderTally counted)
        when (hasErrors (outcomeDiagnostics outcome)) exitFailure

{-| The tally, widest first, because the largest number is where the work is. -}
renderTally :: Map.Map Text.Text Int -> Text.Text
renderTally counted =
  Text.unlines $
    ["", "what running this cost", ""]
      <> map row ordered
      <> ["", "  " <> pad "total steps" <> right (show total)]
 where
  ordered = sortOn (negate . snd) (Map.toList counted)
  total = sum (map snd ordered)
  row (name, count) = "  " <> pad name <> right (show count)
  pad name = name <> Text.replicate (max 1 (22 - Text.length name)) " "
  right shown =
    Text.replicate (max 1 (12 - length shown)) " " <> Text.pack shown

runProgram :: RenderStyle -> FilePath -> IO ()
runProgram style path = do
  program <- compileProgram path
  let diagnostics = programDiagnostics program
  unless (null diagnostics) $
    TextIO.putStrLn (renderProgramDiagnostics style program diagnostics)
  if hasErrors diagnostics
    then exitFailure
    else case rootCompileResult program >>= compileModule of
      Nothing -> do
        hPutStrLn stderr "pudu run: the program produced no module"
        exitFailure
      Just parsed -> do
        outcome <-
          evaluateProgramEntry
            (programIntegerKinds program)
            (programDependencies program)
            entryPointName
            parsed
        mapM_ (TextIO.putStrLn . renderRuntime style program) (outcomeDiagnostics outcome)
        case outcomeValue outcome of
          Just value | not (null (outcomeDiagnostics outcome)) -> value `seq` exitFailure
          Just value -> reportResult value
          Nothing -> exitFailure

{-| Write one file that runs this program anywhere the compiler runs.

    The program is checked first and refused if it does not compile, because a
    build that produced a file which fails at startup would have moved the
    error to the worst possible place to meet it. -}
buildProgram :: RenderStyle -> FilePath -> FilePath -> IO ()
buildProgram style path target = do
  program <- compileProgram path
  let diagnostics = programDiagnostics program
  unless (null diagnostics) $
    TextIO.putStrLn (renderProgramDiagnostics style program diagnostics)
  if hasErrors diagnostics
    then exitFailure
    else case programRoot program of
      Nothing -> do
        hPutStrLn stderr "pudu build: the program produced no module"
        exitFailure
      Just entry -> do
        let bundle = bundleOf entry (programNamedSources program)
        -- A build writes a file the size of the compiler, so the write is the
        -- step most likely to fail for a reason that has nothing to do with
        -- the program: a full disk, a directory that is not there, a path
        -- that may not be written to. Said plainly, because a reader who has
        -- just been told their program compiled needs to know it was the
        -- writing that stopped and where.
        written <- try (writeBundled target bundle) :: IO (Either IOException ())
        case written of
          Left problem -> do
            hPutStrLn stderr ("pudu build: could not write " <> target)
            hPutStrLn stderr ("  " <> describeWriteFailure problem)
            exitFailure
          Right () ->
            TextIO.putStrLn
              ( Text.pack target
                  <> " ("
                  <> Text.pack (show (length (bundleModules bundle)))
                  <> " modules)"
              )

{-| Why a build could not be written, in the terms of the thing that stopped
    it rather than the terms of the call that failed. -}
describeWriteFailure :: IOException -> String
describeWriteFailure problem
  | isFullError problem = "there is no space left on the device"
  | isPermissionError problem = "permission was refused"
  | isDoesNotExistError problem = "the directory it would go in does not exist"
  | otherwise = show problem

{-| What to call the built file when nobody said. -}
defaultTargetName :: FilePath -> FilePath
defaultTargetName path =
  let stem = takeBaseName path
   in if null stem then "program" else stem

{-| The entry point every runnable program declares. -}
entryPointName :: Text
entryPointName = "main"

{-| What a run does with `main`'s answer.

    A whole number becomes the exit status, because that is what a shell reads
    and a program returning one meant it as a status rather than as output.
    Unit prints nothing. Anything else is printed, so a program that answers
    with a value can be run and read without writing its own output call. -}
reportResult :: Value -> IO ()
reportResult value = case value of
  UnitValue -> exitSuccess
  IntValue _ status
    | status == 0 -> exitSuccess
    | otherwise -> exitWith (ExitFailure (fromInteger (max 1 (min 255 status))))
  _ -> TextIO.putStrLn (renderValue value) >> exitSuccess

renderRuntime :: RenderStyle -> ProgramResult -> Diagnostic -> Text
renderRuntime style program value = renderProgramDiagnostics style program [value]

{-| @Program.Cli.FormatMode — what `pudu fmt` does with what it produced. -}
data FormatMode = InPlace | CheckOnly | ToStdout
  deriving stock (Eq, Show)

{-| Format every named file.

    A directory names every `.pudu` file beneath it, so a whole tree is
    formatted by naming the tree rather than by expanding it in the shell,
    where the expansion differs between shells and silently produces nothing
    when it matches nothing.

    A file that does not lex is left exactly as it was and reported, because a
    formatter that rewrites text it could not read is a formatter that loses
    work. `--check` changes nothing and exits non-zero when any file would
    change, which is the shape a continuous-integration step needs. -}
formatPaths :: FormatMode -> [FilePath] -> IO ()
formatPaths mode paths
  | null paths = do
      hPutStrLn stderr "pudu fmt: no files given"
      exitFailure
  | otherwise = do
      expanded <- mapM expand paths
      let files = concat [names | Right names <- expanded]
          missing = [path | Left path <- expanded]
      mapM_ (\path -> hPutStrLn stderr ("pudu fmt: " <> path <> ": no such file or directory")) missing
      when (null files && null missing) $
        hPutStrLn stderr "pudu fmt: no Pudu files under the given directories"
      outcomes <- mapM formatOne (sort files)
      case mode of
        _ | not (null missing) -> exitFailure
        CheckOnly | or outcomes -> exitFailure
        _ -> pure ()
 where
  expand path = do
    isDirectory <- doesDirectoryExist path
    if isDirectory
      then Right <$> collectPuduFiles path
      else do
        isFile <- doesFileExist path
        pure (if isFile then Right [path] else Left path)
  formatOne path = do
    contents <- TextIO.readFile path
    source <- newSource (SourceName (Text.pack path)) contents
    let result = formatSource source
        changed = formatChanged result
    unless (null (formatDiagnostics result)) $
      hPutStrLn stderr (Text.unpack (Text.pack path <> ": " <> renderSummary (formatDiagnostics result)))
    case mode of
      ToStdout -> TextIO.putStr (formatText' result)
      CheckOnly ->
        when changed (hPutStrLn stderr (path <> ": not formatted"))
      InPlace -> do
        when changed (TextIO.writeFile path (formatText' result))
        when changed (putStrLn path)
    pure changed

{-| @Program.Cli.DocOutput — who the index is being written for.

    Text is for a reader at a terminal, JSON for an editor or search server,
    and HTML for a browser. They are the same index, and nothing is included in
    one that the others cannot express, so a tool never has to scrape the human
    form. -}
data DocOutput = TextOutput | JsonOutput | HtmlOutput
  deriving stock (Eq, Show)

{-| Index every named file and its imports.

    Documentation is produced even when the program has errors: a module that
    fails to check is exactly when a reader most wants to see what it declares,
    and the entries that did check are still true. Errors are reported to
    stderr so the index on stdout stays machine-readable. -}
documentPaths :: DocOutput -> [FilePath] -> IO ()
documentPaths output paths
  | null paths = do
      hPutStrLn stderr "pudu doc: no files given"
      exitFailure
  | otherwise = do
      (index, failed) <- indexPaths paths
      case output of
        JsonOutput -> TextIO.putStrLn (encodeIndex index)
        HtmlOutput -> TextIO.putStr (renderSite index)
        TextOutput -> mapM_ describe (indexEntries index)
      if failed then exitFailure else exitSuccess
 where
  describe entry = do
    mapM_ TextIO.putStrLn (renderEntryLines entry)
    TextIO.putStrLn Text.empty

{-| Answer one query against every named file and its imports. -}
searchPaths :: Text -> [FilePath] -> IO ()
searchPaths query paths
  | null paths = do
      hPutStrLn stderr "pudu search: no files given"
      exitFailure
  | otherwise = do
      (index, failed) <- indexPaths paths
      case searchText query index of
        [] -> do
          TextIO.putStrLn ("no results for " <> query)
          exitFailure
        matches -> mapM_ (mapM_ TextIO.putStrLn . renderEntryLines . matchEntry) matches
      if failed then exitFailure else exitSuccess

{-| Run every named test file, or discover them under standard directories.

    Each test file is compiled and evaluated as a standalone program. A test
    whose `main` returns an `Int` reports that many held assertions. A test
    whose evaluation produces diagnostics is a failure regardless of the value,
    because a program that panics during an assertion pass is not a passing
    program.

    The runner prints one line per file as it goes — the number held if it
    passed, or the reason it did not — and a summary line at the end. Exit
    status is 0 when every file passed, 1 otherwise. -}
testPaths :: RenderStyle -> [FilePath] -> IO ()
testPaths style paths = do
  files <- discoverTestFiles paths
  when (null files) $ do
    hPutStrLn stderr "pudu test: no test files found"
    exitFailure
  results <- mapM (runTestFile style) (sort files)
  let passed = length (filter fst results)
      total  = length results
      assertions = sum (map snd results)
  TextIO.putStrLn ""
  TextIO.putStrLn (testSummaryLine passed total assertions)
  if passed == total then exitSuccess else exitFailure

{-| Resolve the file list for `pudu test`.

    A path that names a directory is walked, and one that names a file is
    taken as it stands. Naming a directory is what a reader does when they
    mean "the tests in here", and reading it as a file to compile answers a
    reasonable request with a compilation error about a directory.

    When no path is given the runner looks in `test`, `tests`, and
    `test-fixtures` — the three a project might use — and collects every
    `.pudu` file beneath them. -}
discoverTestFiles :: [FilePath] -> IO [FilePath]
discoverTestFiles explicit
  | not (null explicit) = concat <$> mapM fileOrDirectory explicit
  | otherwise = concat <$> mapM collectPuduFiles standardTestDirs

{-| The `.pudu` files a path stands for: those beneath it when it is a
    directory, and the path itself when it is not. -}
fileOrDirectory :: FilePath -> IO [FilePath]
fileOrDirectory path = do
  isDirectory <- doesDirectoryExist path
  if isDirectory then collectPuduFiles path else pure [path]

standardTestDirs :: [FilePath]
standardTestDirs = ["test", "tests", "test-fixtures"]

collectPuduFiles :: FilePath -> IO [FilePath]
collectPuduFiles root = do
  exists <- doesDirectoryExist root
  if exists then walk root else pure []
 where
  walk dir = do
    entries <- listDirectory dir
    let fullPaths = map (dir </>) entries
    (files, dirs) <- partitionPaths fullPaths
    let puduFiles = filter isPuduFile files
    nested <- concat <$> mapM walk dirs
    pure (puduFiles <> nested)

partitionPaths :: [FilePath] -> IO ([FilePath], [FilePath])
partitionPaths = go [] []
 where
  go files dirs remaining = case remaining of
    []     -> pure (files, dirs)
    p : ps -> do
      isDir <- doesDirectoryExist p
      if isDir
        then go files (p : dirs) ps
        else go (p : files) dirs ps

isPuduFile :: FilePath -> Bool
isPuduFile path = takeExtension path == ".pudu"

{-| Compile and evaluate one test file, printing progress as it goes.

    A test passes when it compiles without errors, evaluates to an `IntValue`,
    and produces no runtime diagnostics. The integer is the assertion count. -}
runTestFile :: RenderStyle -> FilePath -> IO (Bool, Int)
runTestFile style path = do
  program <- compileProgram path
  let diagnostics = programDiagnostics program
  unless (null diagnostics) $
    TextIO.putStrLn (renderProgramDiagnostics style program diagnostics)
  if hasErrors diagnostics
    then do
      TextIO.putStrLn (testFileLine path "FAIL" "compilation errors")
      pure (False, 0)
    else case rootCompileResult program >>= compileModule of
      Nothing -> do
        TextIO.putStrLn (testFileLine path "FAIL" "no module produced")
        pure (False, 0)
      Just parsed -> do
        outcome <-
          evaluateProgramEntry
            (programIntegerKinds program)
            (programDependencies program)
            entryPointName
            parsed
        mapM_ (TextIO.putStrLn . renderRuntime style program) (outcomeDiagnostics outcome)
        classifyOutcome path outcome

{-| What a suite's answer says about it.

    A suite answers how many of its checks held. That number alone cannot
    carry a verdict, because a suite where two of five held answers two, and
    so does a suite of two that passed — so a suite that stops asserting
    halfway looks exactly like a shorter one. The sign carries it instead: a
    suite that had checks fail answers the negative of how many, which no
    passing suite can answer. `Std.Test.done` writes that, and names the
    checks that did not hold on its way out.

    Answering nothing at all is a failure rather than an empty pass. A suite
    that holds nothing asserted nothing, and reporting that as passing is how
    a file that stopped testing goes unnoticed for a year. -}
classifyOutcome :: FilePath -> EvalOutcome -> IO (Bool, Int)
classifyOutcome path outcome
  | not (null (outcomeDiagnostics outcome)) = do
      TextIO.putStrLn (testFileLine path "FAIL" "runtime diagnostics")
      pure (False, 0)
  | otherwise = case outcomeValue outcome of
      Just (IntValue _ n)
        | n < 0 -> do
            let failed = fromInteger (negate n)
            TextIO.putStrLn (testFileLine path "FAIL" (plural failed "check" <> " did not hold"))
            pure (False, 0)
        | n == 0 -> do
            TextIO.putStrLn (testFileLine path "FAIL" "held nothing")
            pure (False, 0)
        | otherwise -> do
            let count = fromInteger n
            TextIO.putStrLn (testFileLine path "PASS" (show count <> " held"))
            pure (True, count)
      Just _ -> do
        TextIO.putStrLn (testFileLine path "PASS" "non-integer result")
        pure (True, 0)
      Nothing -> do
        TextIO.putStrLn (testFileLine path "FAIL" "no value returned")
        pure (False, 0)

{-| A count and the word for it, with the ending the count calls for. -}
plural :: Int -> String -> String
plural count word = show count <> " " <> word <> (if count == 1 then "" else "s")

testFileLine :: FilePath -> String -> String -> Text
testFileLine path status detail =
  Text.pack ("  " <> status <> "  " <> takeFileName path <> "  " <> detail)

testSummaryLine :: Int -> Int -> Int -> Text
testSummaryLine passed total assertions =
  Text.pack
    ( show passed <> "/" <> show total <> " suites passed, "
      <> show assertions <> " assertions held"
    )

initProject :: Maybe FilePath -> IO ()
initProject target = do
  result <- try (createProject target) :: IO (Either IOException ())
  case result of
    Left problem -> hPutStrLn stderr ("pudu init: " <> show problem) >> exitFailure
    Right () -> pure ()

createProject :: Maybe FilePath -> IO ()
createProject target = do
  root <- resolveInitRoot target
  let manifest = root </> "pudu.toml"
      sourceDirectory = root </> "src"
      entry = sourceDirectory </> "Main.pudu"
      testDirectory = root </> "test"
      suite = testDirectory </> "MainTest.pudu"
      ignore = root </> ".gitignore"
      readme = root </> "README.md"
      projectName = takeFileName (dropTrailingPathSeparator root)
  when (null projectName || projectName == "/") $
    ioError (userError "choose a named project directory")
  mapM_ requireAbsent [manifest, entry, suite]
  sourceExists <- doesPathExist sourceDirectory
  sourceLinked <- isLinked sourceDirectory
  sourceIsDirectory <- doesDirectoryExist sourceDirectory
  when (sourceLinked || (sourceExists && not sourceIsDirectory)) $
    ioError (userError "src must be a real directory")
  testExists <- doesPathExist testDirectory
  testLinked <- isLinked testDirectory
  testIsDirectory <- doesDirectoryExist testDirectory
  when (testLinked || (testExists && not testIsDirectory)) $
    ioError (userError "test must be a real directory")
  readmeExists <- doesPathExist readme
  ignoreExists <- doesPathExist ignore
  ignoreLinked <- isLinked ignore
  ignoreIsFile <- doesFileExist ignore
  when (ignoreLinked || (ignoreExists && not ignoreIsFile)) $
    ioError (userError ".gitignore must be a regular file")
  createDirectoryIfMissing True sourceDirectory
  createDirectoryIfMissing True testDirectory
  TextIO.writeFile entry mainTemplate
  TextIO.writeFile suite testTemplate
  unless ignoreExists (TextIO.writeFile ignore gitignoreTemplate)
  unless readmeExists (TextIO.writeFile readme (readmeTemplate projectName))
  TextIO.writeFile manifest (manifestTemplate projectName)
  TextIO.putStrLn (Text.pack ("initialized " <> root))

requireAbsent :: FilePath -> IO ()
requireAbsent path = do
  exists <- doesPathExist path
  linked <- isLinked path
  when (exists || linked) (ioError (userError (path <> " already exists")))

isLinked :: FilePath -> IO Bool
isLinked path = do
  result <- try (pathIsSymbolicLink path) :: IO (Either IOException Bool)
  case result of
    Right linked -> pure linked
    Left problem
      | isDoesNotExistError problem -> pure False
      | otherwise -> ioError problem

resolveInitRoot :: Maybe FilePath -> IO FilePath
resolveInitRoot target = do
  path <- maybe getCurrentDirectory pure target
  when (null path) (ioError (userError "project directory cannot be empty"))
  createDirectoryIfMissing True path
  canonicalizePath path

manifestTemplate :: String -> Text
manifestTemplate name = Text.unlines
  [ "[package]"
  , "name = \"" <> tomlName (Text.pack name) <> "\""
  , "version = \"0.1.0\""
  , "language = \"" <> languageConstraint <> "\""
  , "source = \"src\""
  , ""
  , "# A suite under test/ has its own root, so the code it is testing has to"
  , "# be named as somewhere else the project's modules live."
  , "[dependencies]"
  , "src = \"src\""
  , ""
  ]

tomlName :: Text -> Text
tomlName = Text.concatMap escape
 where
  escape '\\' = "\\\\"
  escape '"' = "\\\""
  escape '\n' = "\\n"
  escape '\r' = "\\r"
  escape '\t' = "\\t"
  escape c | fromEnum c < 32 || fromEnum c == 127 = "_"
           | otherwise = Text.singleton c

{-| The program a new project starts from.

    It answers rather than doing nothing, because the first thing anybody does
    with a new project is run it, and a program that prints nothing and leaves
    with zero has told them nothing about whether any of this works. It also
    holds one function worth testing, so the test the project starts with has
    something real to check rather than checking that arithmetic works. -}
mainTemplate :: Text
mainTemplate = Text.unlines
  [ "module Main"
  , ""
  , "import Std.Io as Io"
  , ""
  , "/// A greeting for somebody, or for the world when nobody was named."
  , "export fn greeting(name: Str) -> Str {"
  , "  if name.isEmpty() { \"Hello, world.\" } else { \"Hello, \" + name + \".\" }"
  , "}"
  , ""
  , "export fn main() -> Int {"
  , "  match Io.writeLine(greeting(\"\")) {"
  , "    case Ok(_) => 0"
  , "    case Err(_) => 1"
  , "  }"
  , "}"
  ]

{-| The suite a new project starts from.

    A project begins with a test that can fail. `pudu test` reads how many
    checks held, so a suite says so with `Std.Test.report`, and a check that
    does not hold names what it wanted beside what it found. -}
testTemplate :: Text
testTemplate = Text.unlines
  [ "module MainTest"
  , ""
  , "import Std.Test as Test"
  , "import Main"
  , ""
  , "fn main() -> Int {"
  , "  let checks = Test.suite(\"greeting\", &["
  , "      Test.equals(\"names somebody given a name\", &Main.greeting(\"Ada\"), &\"Hello, Ada.\"),"
  , "      Test.equals(\"greets the world given nobody\", &Main.greeting(\"\"), &\"Hello, world.\")"
  , "    ])"
  , "  Test.report(&Test.run(&checks))"
  , "}"
  ]

{-| What the project says about itself. -}
readmeTemplate :: String -> Text
readmeTemplate name = Text.unlines
  [ "# " <> Text.pack name
  , ""
  , "```bash"
  , "pudu run src/Main.pudu     # run it"
  , "pudu run --watch src/Main.pudu   # run it again on every save"
  , "pudu test                  # run the suites under test/"
  , "pudu check src/Main.pudu   # compile and report, without running"
  , "pudu fmt src/Main.pudu     # rewrite in the one committed style"
  , "pudu build src/Main.pudu   # one file that runs anywhere the compiler runs"
  , "```"
  ]

gitignoreTemplate :: Text
gitignoreTemplate = Text.unlines
  [ ".pudu/"
  , "*.o"
  , ""
  , ".DS_Store"
  , "*.swp"
  ]

{-| Build one index over every named program, reporting each program's
    diagnostics to stderr so they cannot corrupt the index on stdout. -}
indexPaths :: [FilePath] -> IO (DocIndex, Bool)
indexPaths paths = do
  indexed <- mapM one paths
  pure (mconcat (map fst indexed), or (map snd indexed))
 where
  one path = do
    program <- compileProgram path
    let diagnostics = programDiagnostics program
    unless (null diagnostics) $
      hPutStrLn stderr (Text.unpack (Text.pack path <> ": " <> renderSummary diagnostics))
    pure (programDocs program, hasErrors diagnostics)

renderProgramDiagnostics :: RenderStyle -> ProgramResult -> [Diagnostic] -> Text
renderProgramDiagnostics style program =
  Text.intercalate "\n" . map renderOne
 where
  sources = programSources program
  renderOne value = case sourceFor value sources of
    Nothing -> "error: diagnostic source is unavailable"
    Just source -> renderDiagnosticsWith (defaultRenderConfig style) source [value]

sourceFor :: Diagnostic -> [Source] -> Maybe Source
sourceFor value = firstMatching
 where
  expected = spanSource (diagnosticSpan value)
  firstMatching sources = case filter ((== expected) . sourceName) sources of
    found : _ -> Just found
    [] -> Nothing

{-| Colour is used only for an interactive terminal, and never when NO_COLOR is
    set, so piped and redirected output stays plain. -}
detectStyle :: IO RenderStyle
detectStyle = do
  terminal <- hIsTerminalDevice stdout
  noColor <- lookupEnv "NO_COLOR"
  pure (if terminal && noColor == Nothing then ColorStyle else PlainStyle)

usage :: IO ()
usage =
  mapM_
    TextIO.putStrLn
    [ "pudu " <> versionText
    , ""
    , "usage:"
    , "  pudu                 start the puduci interactive session"
    , "  pudu repl [file]     start puduci, optionally loading a file"
    , "  pudu check <file>... compile files and report diagnostics"
    , "  pudu run <file>      compile a program and run its main function"
  , "  pudu run --watch <file>  the same, run again whenever a source file"
  , "                       under it changes"
    , "  pudu build <file> [-o name]  write one file that runs anywhere the"
    , "                       compiler runs, with every module it needs inside it"
    , "  pudu test [path]...  discover and execute test fixtures"
    , "  pudu init [path]     initialize a canonical project with pudu.toml"
    , "  pudu explain <file>  run a program and report what running it cost"
    , "  pudu lsp             speak the language server protocol over stdio"
    , "  pudu fmt <path>...   rewrite files, or every file under a directory"
    , "  pudu fmt --check ... report which files are not formatted, changing none"
    , "  pudu fmt --stdout .. write the formatted text to stdout"
    , "  pudu doc <file>...   describe every name a program declares"
    , "  pudu doc --json ...  the same index, for an editor or a search server"
    , "  pudu doc --html ...  emit a self-contained searchable documentation page"
    , "  pudu search <query> <file>...  find a name, or a type shape such as"
    , "                       'Array[a] -> a'"
    , "  pudu api --json <file>...  emit public API identities"
    , "  pudu version         print the version"
    , "  pudu help            print this message"
    ]

versionLine :: Text
versionLine = "pudu " <> versionText


apiPaths :: [FilePath] -> IO ()
apiPaths [] = hPutStrLn stderr "pudu api --json: no files given" >> exitFailure
apiPaths paths = do
  programs <- mapM compileProgram paths
  if any (hasErrors . programDiagnostics) programs
    then hPutStrLn stderr "pudu api: compilation failed; no API index emitted" >> exitFailure
    else do
      let entries =
            [ "{\"module\":\"" <> escapeJson (moduleNameText name)
                <> "\",\"name\":\"" <> escapeJson (symbolName symbol) <> "\"}"
            | program <- programs
            , Just name <- [programRoot program]
            , Just compiled <- [rootCompileResult program]
            , Just resolution <- [compileResolution compiled]
            , symbol <- resolutionExports resolution
            ]
      TextIO.putStrLn ("{\"version\":\"" <> versionText <> "\",\"exports\":["
        <> Text.intercalate "," entries <> "]}")
