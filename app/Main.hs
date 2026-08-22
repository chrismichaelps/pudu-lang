{-| @Program.Cli.Module — the pudu command line entry point -}
module Main (main) where

import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (hasErrors)
import Pudu.Diagnostic.Render
  ( RenderStyle (..)
  , defaultRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Repl (ReplOptions (..), runRepl)
import Pudu.Source (SourceName (SourceName), newSource)
import System.Directory (doesFileExist)
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
  present <- doesFileExist path
  if not present
    then do
      hPutStrLn stderr ("pudu: cannot read " <> path)
      pure True
    else do
      text <- TextIO.readFile path
      source <- newSource (SourceName (Text.pack path)) text
      let result = runCompile source
          diagnostics = compileDiagnostics result
      unless (null diagnostics) $
        TextIO.putStrLn (renderDiagnosticsWith (defaultRenderConfig style) source diagnostics)
      TextIO.putStrLn (Text.pack path <> ": " <> renderSummary diagnostics)
      pure (hasErrors diagnostics)

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
    , "  pudu version         print the version"
    , "  pudu help            print this message"
    ]

versionLine :: Text
versionLine = "pudu " <> versionText

versionText :: Text
versionText = "0.1.0.0"
