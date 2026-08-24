{-| @Program.Cli.Module — the pudu command line entry point -}
module Main (main) where

import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , programDependencies
  , programDocs
  , rootCompileResult
  )
import Pudu.Eval (EvalOutcome (..), evaluateProgramEntry)
import Pudu.Eval.Value (Value (..), renderValue)
import Pudu.Doc (DocIndex, indexEntries, renderEntryLines)
import Pudu.Doc.Json (encodeIndex)
import Pudu.Doc.Search (Match (..), searchText)
import Pudu.Diagnostic (Diagnostic, diagnosticSpan, hasErrors)
import Pudu.Diagnostic.Render
  ( RenderStyle (..)
  , defaultRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Repl (ReplOptions (..), runRepl)
import Pudu.Source (Source, sourceName, spanSource)
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure, exitSuccess)
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
    ("run" : []) -> do
      hPutStrLn stderr "pudu run: no file given"
      exitFailure
    ("doc" : "--json" : paths) -> documentPaths JsonOutput paths
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
        let outcome =
              evaluateProgramEntry (programDependencies program) entryPointName parsed
        mapM_ (TextIO.putStrLn . renderRuntime style program) (outcomeDiagnostics outcome)
        case outcomeValue outcome of
          Just value | not (null (outcomeDiagnostics outcome)) -> value `seq` exitFailure
          Just value -> reportResult value
          Nothing -> exitFailure

{-| The entry point every runnable program declares. -}
entryPointName :: Text
entryPointName = "main"

{-| A run reports its result only when there is one to report, so a program
    whose `main` returns unit prints nothing and a shell pipeline stays
    usable. -}
reportResult :: Value -> IO ()
reportResult value = case value of
  UnitValue -> exitSuccess
  _ -> TextIO.putStrLn (renderValue value) >> exitSuccess

renderRuntime :: RenderStyle -> ProgramResult -> Diagnostic -> Text
renderRuntime style program value = renderProgramDiagnostics style program [value]

{-| @Program.Cli.DocOutput — who the index is being written for.

    Text is for a reader at a terminal; JSON is for an editor or a search
    server. They are the same index, and nothing is included in one that the
    other cannot express, so a tool never has to scrape the human form. -}
data DocOutput = TextOutput | JsonOutput
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
      index <- indexPaths paths
      case output of
        JsonOutput -> TextIO.putStrLn (encodeIndex index)
        TextOutput -> mapM_ describe (indexEntries index)
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
      index <- indexPaths paths
      case searchText query index of
        [] -> do
          TextIO.putStrLn ("no results for " <> query)
          exitFailure
        matches -> mapM_ (mapM_ TextIO.putStrLn . renderEntryLines . matchEntry) matches

{-| Build one index over every named program, reporting each program's
    diagnostics to stderr so they cannot corrupt the index on stdout. -}
indexPaths :: [FilePath] -> IO DocIndex
indexPaths paths = mconcat <$> mapM one paths
 where
  one path = do
    program <- compileProgram path
    let diagnostics = programDiagnostics program
    unless (null diagnostics) $
      hPutStrLn stderr (Text.unpack (Text.pack path <> ": " <> renderSummary diagnostics))
    pure (programDocs program)

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
    , "  pudu doc <file>...   describe every name a program declares"
    , "  pudu doc --json ...  the same index, for an editor or a search server"
    , "  pudu search <query> <file>...  find a name, or a type shape such as"
    , "                       'Array[a] -> a'"
    , "  pudu version         print the version"
    , "  pudu help            print this message"
    ]

versionLine :: Text
versionLine = "pudu " <> versionText

versionText :: Text
versionText = "0.1.0.0"
