{-| @Program.Cli.Module — the pudu command line entry point -}
module Main (main) where

import Control.Monad (unless, when)
import Data.Text (Text)
import qualified Data.Map.Strict as Map
import Data.List (sortOn)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
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
import Pudu.Eval.Value (Value (..), renderValue)
import Pudu.Doc (DocIndex, indexEntries, renderEntryLines)
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Lsp.Server (runServer)
import Pudu.Doc.Json (encodeIndex)
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
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode (ExitFailure), exitFailure, exitSuccess, exitWith)
import System.IO (hIsTerminalDevice, hPutStrLn, stderr, stdout)

main :: IO ()
main = do
  arguments <- getArgs
  style <- detectStyle
  case arguments of
    [] -> startRepl style Nothing
    ("repl" : rest) -> startRepl style (listToPath rest)
    ("check" : paths) -> checkPaths style paths
    ("run" : path : _) -> runProgram style path
    ("explain" : path : _) -> explainProgram style path
    ("run" : []) -> do
      hPutStrLn stderr "pudu run: no file given"
      exitFailure
    ("lsp" : _) -> runServer
    ("fmt" : "--check" : paths) -> formatPaths CheckOnly paths
    ("fmt" : "--stdout" : paths) -> formatPaths ToStdout paths
    ("fmt" : paths) -> formatPaths InPlace paths
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
      outcomes <- mapM formatOne paths
      case mode of
        CheckOnly | or outcomes -> exitFailure
        _ -> pure ()
 where
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
    , "  pudu explain <file>  run a program and report what running it cost"
    , "  pudu lsp             speak the language server protocol over stdio"
    , "  pudu fmt <file>...   rewrite files in the one committed style"
    , "  pudu fmt --check ... report which files are not formatted, changing none"
    , "  pudu fmt --stdout .. write the formatted text to stdout"
    , "  pudu doc <file>...   describe every name a program declares"
    , "  pudu doc --json ...  the same index, for an editor or a search server"
    , "  pudu doc --html ...  emit a self-contained searchable documentation page"
    , "  pudu search <query> <file>...  find a name, or a type shape such as"
    , "                       'Array[a] -> a'"
    , "  pudu version         print the version"
    , "  pudu help            print this message"
    ]

versionLine :: Text
versionLine = "pudu " <> versionText

versionText :: Text
versionText = "0.1.0.0"
