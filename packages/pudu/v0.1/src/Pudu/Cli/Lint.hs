{-| @Program.Cli.Lint.Module — the filesystem and output boundary for Pudu lint. -}
module Pudu.Cli.Lint
  ( LintCommandResult (..)
  , lintCommand
  ) where

import Control.Exception (IOException, bracketOnError, try)
import Control.Monad (foldM)
import Data.List (sort, sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , rootCompileResult
  )
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (..)
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSeverity
  , diagnosticSpan
  )
import Pudu.Diagnostic.Render
  ( RenderStyle
  , defaultRenderConfig
  , renderDiagnosticsWith
  )
import Pudu.Lint
  ( FixApplicability (..)
  , LintFinding (..)
  , LintFix (..)
  , LintResult (..)
  , applySafeFixes
  , lintModule
  )
import Pudu.Lint.Config
  ( projectAllowances
  , sourceAllowances
  , suppressed
  , warningCode
  )
import Pudu.Lsp.Json (Json (..), encode)
import Pudu.Source
  ( Position (..)
  , Source
  , SourceName (..)
  , offsetPosition
  , sourceName
  , sourceText
  , spanEnd
  , spanSource
  , spanStart
  , unOffset
  )
import System.Directory
  ( canonicalizePath
  , doesDirectoryExist
  , doesFileExist
  , getPermissions
  , listDirectory
  , pathIsSymbolicLink
  , removeFile
  , renameFile
  , setPermissions
  )
import System.FilePath ((</>), takeDirectory, takeExtension, takeFileName)
import System.IO (hClose, hSetEncoding, openTempFile, utf8)
import System.IO.Error (isDoesNotExistError)

data LintCommandResult = LintCommandResult
  { lintCommandStdout :: !Text
  , lintCommandStderr :: !Text
  , lintCommandSuccess :: !Bool
  , lintCommandChanged :: ![FilePath]
  }
  deriving stock (Eq, Show)

data OutputFormat = HumanOutput | JsonOutput
  deriving stock (Eq, Show)

data Options = Options
  { optionFormat :: !OutputFormat
  , optionFix :: !Bool
  , optionAllowed :: !(Set Text)
  , optionPaths :: ![FilePath]
  }

data Reported = Reported !Source !LintFinding

data Analysis = Analysis
  { analysisReports :: ![Reported]
  , analysisIssues :: ![Text]
  , analysisHasErrors :: !Bool
  }

{-| Parse, analyze, optionally persist safe edits, and re-analyze. -}
lintCommand :: RenderStyle -> [String] -> IO LintCommandResult
lintCommand style arguments = case parseOptions arguments of
  Left problem -> pure (failed problem)
  Right options -> do
    discovered <- discoverPaths (optionPaths options)
    case discovered of
      Left problem -> pure (failed problem)
      Right [] -> pure (failed "pudu lint: no .pudu files found")
      Right paths -> do
        first <- analyzePaths options paths
        if optionFix options && null (analysisIssues first) && not (analysisHasErrors first)
          then do
            changed <- persistFixes (analysisReports first)
            case changed of
              Left problem -> pure (failed problem)
              Right files -> do
                final <- analyzePaths options paths
                pure (renderResult style options files final)
          else pure (renderResult style options [] first)
 where
  failed problem = LintCommandResult Text.empty (problem <> "\n") False []

parseOptions :: [String] -> Either Text Options
parseOptions = go (Options HumanOutput False Set.empty [])
 where
  go options remaining = case remaining of
    []
      | null (optionPaths options) -> Left "usage: pudu lint [--json] [--fix] [--allow CODE] <path>..."
      | otherwise -> Right options{optionPaths = reverse (optionPaths options)}
    "--json" : rest -> go options{optionFormat = JsonOutput} rest
    "--fix" : rest -> go options{optionFix = True} rest
    "--allow" : code : rest -> do
      valid <- warningCode (Text.pack code)
      go options{optionAllowed = Set.insert valid (optionAllowed options)} rest
    "--allow" : [] -> Left "pudu lint: --allow requires a warning code"
    option : _ | "--" `Text.isPrefixOf` Text.pack option ->
      Left ("pudu lint: unknown option " <> Text.pack option)
    path : rest -> go options{optionPaths = path : optionPaths options} rest

discoverPaths :: [FilePath] -> IO (Either Text [FilePath])
discoverPaths asked = do
  found <- foldM add (Right Set.empty) asked
  pure (sort . Set.toList <$> found)
 where
  add (Left problem) _ = pure (Left problem)
  add (Right accumulated) path = do
    linked <- isLinked path
    file <- doesFileExist path
    directory <- doesDirectoryExist path
    if linked
      then pure (Left ("pudu lint: symbolic paths are not followed: " <> Text.pack path))
      else if file
        then if takeExtension path == ".pudu"
          then do
            canonical <- canonicalizePath path
            pure (Right (Set.insert canonical accumulated))
          else pure (Left ("pudu lint: not a .pudu file: " <> Text.pack path))
        else if directory
          then do
            nested <- discoverDirectory path
            pure (Set.union accumulated <$> nested)
          else pure (Left ("pudu lint: cannot read " <> Text.pack path))

discoverDirectory :: FilePath -> IO (Either Text (Set FilePath))
discoverDirectory root = do
  entries <- try (listDirectory root) :: IO (Either IOException [FilePath])
  case entries of
    Left problem -> pure (Left ("pudu lint: cannot read " <> Text.pack root <> ": " <> Text.pack (show problem)))
    Right names -> foldM visit (Right Set.empty) (sort names)
 where
  visit (Left problem) _ = pure (Left problem)
  visit (Right accumulated) name
    | name `elem` ignoredDirectories = pure (Right accumulated)
    | otherwise = do
        let path = root </> name
        linked <- isLinked path
        file <- doesFileExist path
        directory <- doesDirectoryExist path
        if linked
          then pure (Right accumulated)
          else if file && takeExtension path == ".pudu"
            then do
              canonical <- canonicalizePath path
              pure (Right (Set.insert canonical accumulated))
            else if directory
              then do
                nested <- discoverDirectory path
                pure (Set.union accumulated <$> nested)
              else pure (Right accumulated)

ignoredDirectories :: [FilePath]
ignoredDirectories = [".git", ".pudu", "dist-newstyle", "node_modules", "target"]

analyzePaths :: Options -> [FilePath] -> IO Analysis
analyzePaths options paths = do
  analyzed <- foldM analyzeOne (Analysis [] [] False) paths
  pure analyzed{analysisReports = normalizeReports (analysisReports analyzed)}
 where
  analyzeOne accumulated path = do
    policy <- projectAllowances path
    case policy of
      Left problem -> pure accumulated{analysisIssues = analysisIssues accumulated <> [problem]}
      Right projectAllowed -> do
        program <- compileProgram path
        let errors = filter ((== Error) . diagnosticSeverity) (programDiagnostics program)
            compilerReports = mapMaybe (reportDiagnostic program "compiler" Nothing) errors
            hasCompilerErrors = not (null errors)
        case rootParts program of
          Nothing -> pure accumulated
            { analysisReports = analysisReports accumulated <> compilerReports
            , analysisHasErrors = analysisHasErrors accumulated || hasCompilerErrors
            }
          Just (source, compiled) -> case sourceAllowances source of
              Left problem -> pure accumulated
                { analysisReports = analysisReports accumulated <> compilerReports
                , analysisIssues = analysisIssues accumulated <> [problem]
                , analysisHasErrors = analysisHasErrors accumulated || hasCompilerErrors
                }
              Right sourceAllowed -> do
                let allowed = optionAllowed options <> projectAllowed
                    compilerWarnings =
                      [ Reported source (compilerFinding value)
                      | value <- compileDiagnostics compiled
                      , diagnosticSeverity value == Warning
                      , not (suppressed sourceAllowed allowed source value)
                      ]
                    native = case (compileModule compiled, compileTypes compiled) of
                      (Just parsed, Just types) -> lintFindings (lintModule source types parsed)
                      _ -> []
                    nativeReports =
                      [ Reported source finding
                      | finding <- native
                      , not (suppressed sourceAllowed allowed source (lintDiagnostic finding))
                      ]
                pure accumulated
                  { analysisReports = analysisReports accumulated <> compilerReports
                      <> compilerWarnings <> nativeReports
                  , analysisHasErrors = analysisHasErrors accumulated || hasCompilerErrors
                  }

rootParts :: ProgramResult -> Maybe (Source, CompileResult)
rootParts program = do
  name <- programRoot program
  source <- Map.lookup name (programNamedSources program)
  compiled <- rootCompileResult program
  pure (source, compiled)

reportDiagnostic :: ProgramResult -> Text -> Maybe LintFix -> Diagnostic -> Maybe Reported
reportDiagnostic program rule fix value = do
  source <- sourceFor program (spanSource (diagnosticSpan value))
  pure (Reported source LintFinding
    { lintDiagnostic = value
    , lintRuleName = rule
    , lintFix = fix
    })

sourceFor :: ProgramResult -> SourceName -> Maybe Source
sourceFor program name = findSource (programSources program)
 where
  findSource sources = case sources of
    [] -> Nothing
    source : rest -> if sourceName source == name then Just source else findSource rest

compilerFinding :: Diagnostic -> LintFinding
compilerFinding value = LintFinding
  { lintDiagnostic = value
  , lintRuleName = compilerRule (diagnosticCodeText (diagnosticCode value))
  , lintFix = Nothing
  }

compilerRule :: Text -> Text
compilerRule code = case code of
  "W2001" -> "shadowed-binding"
  "W2002" -> "shadowed-label"
  "W3001" -> "unused-unsafe-capability"
  "W3002" -> "discarded-persistent-result"
  "W3003" -> "manual-failure-propagation"
  "W5001" -> "unreachable-case"
  "W7027" -> "resource-cleanup-failure"
  _ -> "compiler-" <> Text.toLower code

normalizeReports :: [Reported] -> [Reported]
normalizeReports = choose Set.empty . sortOn reportKey
 where
  choose _ [] = []
  choose seen (report : rest)
    | Set.member (reportKey report) seen = choose seen rest
    | otherwise = report : choose (Set.insert (reportKey report) seen) rest
  reportKey (Reported source finding) =
    let value = lintDiagnostic finding
        spanValue = diagnosticSpan value
     in ( sourcePath source
        , unOffset (spanStart spanValue)
        , unOffset (spanEnd spanValue)
        , diagnosticCodeText (diagnosticCode value)
        , diagnosticMessage value
        )

persistFixes :: [Reported] -> IO (Either Text [FilePath])
persistFixes reports = foldM persist (Right []) (Map.toAscList byPath)
 where
  byPath = foldl add Map.empty reports
  add accumulated (Reported source finding) = case lintFix finding of
    Nothing -> accumulated
    Just _ -> Map.insertWith
      (\(_, newer) (held, older) -> (held, older <> newer))
      (Text.unpack (sourcePath source)) (source, [finding]) accumulated
  persist (Left problem) _ = pure (Left problem)
  persist (Right changed) (path, (source, findings)) = do
    let updated = applySafeFixes source findings
    if updated == sourceText source
      then pure (Right changed)
      else do
        written <- replaceFile path updated
        pure $ case written of
          Left problem -> Left problem
          Right () -> Right (changed <> [path])

replaceFile :: FilePath -> Text -> IO (Either Text ())
replaceFile path contents = do
  permissions <- getPermissions path
  attempted <- try $ bracketOnError
    (openTempFile (takeDirectory path) (takeFileName path <> ".pudu-lint"))
    cleanup
    (\(temporary, handle) -> do
      hSetEncoding handle utf8
      TextIO.hPutStr handle contents
      hClose handle
      setPermissions temporary permissions
      renameFile temporary path)
  pure $ case attempted of
    Left problem -> Left ("pudu lint: cannot replace " <> Text.pack path <> ": " <> Text.pack (show (problem :: IOException)))
    Right () -> Right ()
 where
  cleanup (temporary, handle) = do
    _ <- try (hClose handle) :: IO (Either IOException ())
    _ <- try (removeFile temporary) :: IO (Either IOException ())
    pure ()

renderResult :: RenderStyle -> Options -> [FilePath] -> Analysis -> LintCommandResult
renderResult style options changed analysis =
  let reports = analysisReports analysis
      issues = analysisIssues analysis
      output = case optionFormat options of
        HumanOutput -> renderHuman style reports
        JsonOutput -> encode (JsonArray (map reportJson reports <> map issueJson issues)) <> "\n"
      errors = case optionFormat options of
        HumanOutput -> if null issues then Text.empty else Text.unlines issues
        JsonOutput -> Text.empty
   in LintCommandResult
        { lintCommandStdout = output
        , lintCommandStderr = errors
        , lintCommandSuccess = null reports && null issues && not (analysisHasErrors analysis)
        , lintCommandChanged = changed
        }

{-| Every report ends its own line, as `pudu check` prints them, so a reader
    going line by line finds each header at the start of one. -}
renderHuman :: RenderStyle -> [Reported] -> Text
renderHuman style reports = Text.concat
  [ Text.dropWhileEnd (== '\n') (renderDiagnosticsWith (defaultRenderConfig style) source [lintDiagnostic finding]) <> "\n"
  | Reported source finding <- reports
  ]

reportJson :: Reported -> Json
reportJson (Reported source finding) =
  let value = lintDiagnostic finding
      spanValue = diagnosticSpan value
      Position line column = maybe (Position 1 1) id (offsetPosition source (spanStart spanValue))
   in JsonObject
        [ ("path", JsonText (sourcePath source))
        , ("start", JsonNumber (fromIntegral (unOffset (spanStart spanValue))))
        , ("end", JsonNumber (fromIntegral (unOffset (spanEnd spanValue))))
        , ("line", JsonNumber (fromIntegral line))
        , ("column", JsonNumber (fromIntegral column))
        , ("code", JsonText (diagnosticCodeText (diagnosticCode value)))
        , ("severity", JsonText (severityText (diagnosticSeverity value)))
        , ("rule", JsonText (lintRuleName finding))
        , ("message", JsonText (diagnosticMessage value))
        , ("help", maybe JsonNull JsonText (diagnosticHelp value))
        , ("fix", maybe JsonNull fixJson (lintFix finding))
        ]

fixJson :: LintFix -> Json
fixJson fix = JsonObject
  [ ("applicability", JsonText (case lintFixApplicability fix of Safe -> "safe"))
  , ("start", JsonNumber (fromIntegral (lintFixStart fix)))
  , ("end", JsonNumber (fromIntegral (lintFixEnd fix)))
  , ("replacement", JsonText (lintFixReplacement fix))
  ]

issueJson :: Text -> Json
issueJson message = JsonObject
  [ ("code", JsonText "E7102")
  , ("severity", JsonText "error")
  , ("rule", JsonText "configuration")
  , ("message", JsonText message)
  , ("fix", JsonNull)
  ]

severityText :: Severity -> Text
severityText severity = case severity of
  Error -> "error"
  Warning -> "warning"
  Note -> "note"

sourcePath :: Source -> Text
sourcePath source = case sourceName source of SourceName path -> path

isLinked :: FilePath -> IO Bool
isLinked path = do
  result <- try (pathIsSymbolicLink path) :: IO (Either IOException Bool)
  case result of
    Right linked -> pure linked
    Left problem | isDoesNotExistError problem -> pure False
    Left problem -> ioError problem
