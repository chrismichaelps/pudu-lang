{-| @Compiler.Manifest — what a project's own file says about where its code is

    A program is its own files plus the compiler it is built with. That answers
    where the standard library comes from and it answers nothing about the
    second and third programs written in the language, which cannot share a
    line of code except by copying it.

    A dependency named by path is the smallest thing that changes that. The
    code it names is on the machine already — checked out beside the project,
    vendored into it, or shared across a repository of several programs — so
    there is no fetching, no resolution, no lock file, and no registry. What
    there is, is a way for one project to say that another directory's modules
    are part of its program.

    Nothing here reaches the network. A path that leaves the project is
    allowed, because a checkout beside it is the ordinary case; a path that
    does not exist is reported where it is written rather than as a missing
    module later. -}
module Pudu.Compiler.Manifest
  ( Manifest (..)
  , Dependency (..)
  , DependencySource (..)
  , parseManifest
  , manifestSnapshotPackageRoots
  , manifestSnapshotRoot
  , ManifestMetrics (..)
  , ManifestSnapshot
  , readManifest
  , readManifestSnapshot
  , manifestSnapshotDiagnostics
  , manifestSnapshotMetrics
  , manifestSnapshotSearchRoots
  , manifestVersionDiagnostics
  , findManifestRoot
  , manifestSearchRoots
  , projectSearchRoots
  ) where

import Control.Exception (IOException, try)
import Data.Char (isSpace)
import Data.Maybe (mapMaybe, maybeToList)
import qualified Data.Set as Set
import Pudu.Version (acceptsLanguage, versionText)
import Pudu.Package.Identity (installDirectory, parsePackageId, renderPackageId)
import Pudu.Package.Lock (Lock (..), LockEntry (..), lockFileName, parseLock)
import Pudu.Diagnostic (Diagnostic, Severity (Error), diagnostic, mkDiagnosticCode)
import Pudu.Source (SourceName (..), emptySpan, newSource)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Directory (doesDirectoryExist, doesFileExist)
import System.FilePath (isAbsolute, normalise, takeDirectory, (</>))

{-| Where a dependency's code comes from.

    A path is used where it is. A repository is checked out at a revision and
    installed into `deps/`. A registry release is named by a requirement and
    installed into `deps/` too. A value that is none of these is kept with the
    reason, so `pudu install` can point at the line. -}
data DependencySource
  = PathSource !FilePath
  | GitSource !Text !(Maybe Text)
  | RegistrySource !Text
  | UnreadableSource !Text
  deriving stock (Eq, Show)

{-| One dependency, under the name the manifest gives it, with the line it is
    written on. -}
data Dependency = Dependency
  { dependencyName :: !Text
  , dependencySource :: !DependencySource
  , dependencyLine :: !Int
  }
  deriving stock (Eq, Show)

data Manifest = Manifest
  { manifestName :: !(Maybe Text)
  , manifestLanguage :: !(Maybe Text)
  , manifestSource :: !(Maybe FilePath)
  , manifestDependencies :: ![Dependency]
  , manifestVersion :: !(Maybe Text)
  , manifestRoot :: !(Maybe Text)
  , manifestDescription :: !(Maybe Text)
  , manifestLicense :: !(Maybe Text)
  , manifestKeywords :: ![Text]
  }
  deriving stock (Eq, Show)

dependencyPath :: Dependency -> Maybe FilePath
dependencyPath dependency = case dependencySource dependency of
  PathSource path -> Just path
  _ -> Nothing

{-| Bounded filesystem work performed while taking one manifest snapshot. -}
data ManifestMetrics = ManifestMetrics
  { manifestAncestorChecks :: !Int
  , manifestReadCount :: !Int
  , manifestDependencyProbes :: !Int
  }
  deriving stock (Eq, Show)

{-| One invocation's coherent view of project configuration.

    Diagnostics and dependency roots derive from the same retained manifest
    bytes. The value is intentionally not stored beyond its compiler call. -}
data ManifestSnapshot = ManifestSnapshot
  !(Maybe FilePath)
  !Manifest
  !Text
  ![FilePath]
  ![Diagnostic]
  !ManifestMetrics
  ![FilePath]

emptyManifest :: Manifest
emptyManifest = Manifest Nothing Nothing Nothing [] Nothing Nothing Nothing Nothing []

{-| Read `pudu.toml` from a project root, answering an empty manifest when
    there is none.

    A missing manifest is not an error: a single file compiled on its own is a
    program, and asking every such program to carry a manifest first would make
    the language harder to try than it needs to be. -}
readManifest :: FilePath -> IO Manifest
readManifest root = do
  let path = root </> "pudu.toml"
  present <- doesFileExist path
  if not present
    then pure emptyManifest
    else do
      loaded <- try (TextIO.readFile path) :: IO (Either IOException Text)
      pure $ case loaded of
        Left _ -> emptyManifest
        Right contents -> parseManifest contents

{-| The directory whose `pudu.toml` governs a source root.

    Walked upwards, because a source root is where the modules are and a
    manifest is where the project is: `src/Main.pudu` compiles with a source
    root of `src`, and the manifest is beside it rather than in it. The walk
    stops after a few levels so a file compiled somewhere with no project at
    all does not read one belonging to a directory far above it. -}
findManifestRoot :: FilePath -> IO (Maybe FilePath)
findManifestRoot from = fst <$> findManifestRootCounted from

findManifestRootCounted :: FilePath -> IO (Maybe FilePath, Int)
findManifestRootCounted from = go (normalise from) (6 :: Int) 0
 where
  go _ 0 checks = pure (Nothing, checks)
  go directory remaining checks = do
    here <- doesFileExist (directory </> "pudu.toml")
    if here
      then pure (Just directory, checks + 1)
      else do
        let parent = takeDirectory directory
        if parent == directory
          then pure (Nothing, checks + 1)
          else go parent (remaining - 1) (checks + 1)

{-| Capture the governing manifest once for one compiler invocation. -}
readManifestSnapshot :: FilePath -> IO ManifestSnapshot
readManifestSnapshot sourceRoot = do
  (found, ancestorChecks) <- findManifestRootCounted sourceRoot
  case found of
    Nothing ->
      pure (ManifestSnapshot Nothing emptyManifest Text.empty [] []
        (ManifestMetrics ancestorChecks 0 0) [])
    Just root -> do
      let path = root </> "pudu.toml"
      loaded <- try (TextIO.readFile path) :: IO (Either IOException Text)
      case loaded of
        Left problem -> do
          diagnostics <- manifestReadFailure path problem
          pure (ManifestSnapshot (Just root) emptyManifest Text.empty [] diagnostics
            (ManifestMetrics ancestorChecks 1 0) [])
        Right contents -> do
          let manifest = parseManifest contents
              candidates = distinct
                (map (resolveAgainst root) (mapMaybe dependencyPath (manifestDependencies manifest)))
          roots <- existing candidates
          diagnostics <- versionDiagnostics path contents manifest
          (packages, packageProblems) <- installedPackageRoots root
          pure
            ( ManifestSnapshot (Just root) manifest contents roots (diagnostics <> packageProblems)
                (ManifestMetrics ancestorChecks 1 (length candidates)) packages
            )

manifestSnapshotSearchRoots :: ManifestSnapshot -> [FilePath]
manifestSnapshotSearchRoots (ManifestSnapshot _ _ _ roots _ _ _) = roots

{-| The source directories of the packages `pudu.lock` names, as installed in
    `deps/`. Kept apart from the project's own roots, because a package may
    never provide a standard module and the project may. -}
manifestSnapshotPackageRoots :: ManifestSnapshot -> [FilePath]
manifestSnapshotPackageRoots (ManifestSnapshot _ _ _ _ _ _ packages) = packages

manifestSnapshotRoot :: ManifestSnapshot -> Maybe FilePath
manifestSnapshotRoot (ManifestSnapshot root _ _ _ _ _ _) = root

manifestSnapshotDiagnostics :: ManifestSnapshot -> [Diagnostic]
manifestSnapshotDiagnostics (ManifestSnapshot _ _ _ _ diagnostics _ _) = diagnostics

manifestSnapshotMetrics :: ManifestSnapshot -> ManifestMetrics
manifestSnapshotMetrics (ManifestSnapshot _ _ _ _ _ metrics _) = metrics

{-| Where each locked package's modules are, and what is wrong when one is not
    where the lock says.

    Nothing is fetched and nothing is digested here: this runs before every
    compile, and a missing directory is a sentence telling the reader which
    command installs it, not a missing module three files later. -}
installedPackageRoots :: FilePath -> IO ([FilePath], [Diagnostic])
installedPackageRoots root = do
  let path = root </> lockFileName
  present <- doesFileExist path
  if not present
    then pure ([], [])
    else do
      loaded <- try (TextIO.readFile path) :: IO (Either IOException Text)
      case loaded of
        Left problem -> (,) [] <$> reportCoded "E7201" path Text.empty ("cannot read pudu.lock: " <> Text.pack (show problem))
        Right contents -> case parseLock contents of
          Left problem -> (,) [] <$> reportCoded "E7201" path contents problem
          Right (Lock entries) -> do
            found <- traverse (packageRoot root) entries
            let roots = [r | Right r <- found]
                missing = [renderPackageId (entryName e) | Left e <- found]
            problems <-
              if null missing
                then pure []
                else
                  reportCoded "E7202" path contents
                    ( "pudu.lock names " <> Text.intercalate ", " missing
                        <> " but deps/ does not hold " <> (if length missing == 1 then "it" else "them")
                        <> "; run pudu install"
                    )
            pure (roots, problems)

packageRoot :: FilePath -> LockEntry -> IO (Either LockEntry FilePath)
packageRoot root entry = do
  let directory = installDirectory root (entryName entry)
  there <- doesDirectoryExist directory
  if not there
    then pure (Left entry)
    else do
      own <- readManifest directory
      let source = maybe "src" id (manifestSource own)
      hasSource <- doesDirectoryExist (directory </> source)
      pure (Right (if hasSource then normalise (directory </> source) else directory))

{-| Every directory a source root's project says its code also lives in.

    Answers nothing when there is no project, which is the ordinary case for a
    single file compiled on its own. -}
projectSearchRoots :: FilePath -> IO [FilePath]
projectSearchRoots sourceRoot = manifestSnapshotSearchRoots <$> readManifestSnapshot sourceRoot

{-| The directories a dependency contributes, in the order they are written.

    A dependency's own `source` is not read: that would mean reading a manifest
    per dependency and deciding what to do when two of them disagree, and the
    convention — a directory of modules — needs no such decision. A dependency
    pointing at a project rather than at its sources names the sources.

    The roots are made absolute against the project root, so a relative path in
    a manifest means what the person writing it meant: relative to the file
    they wrote it in. -}
manifestSearchRoots :: FilePath -> Manifest -> IO [FilePath]
manifestSearchRoots root manifest =
  existing
    ( distinct
        (map (resolveAgainst root) (mapMaybe dependencyPath (manifestDependencies manifest)))
    )

existing :: [FilePath] -> IO [FilePath]
existing [] = pure []
existing (path : rest) = do
  there <- doesDirectoryExist path
  remaining <- existing rest
  pure (if there then path : remaining else remaining)

distinct :: [FilePath] -> [FilePath]
distinct = go Set.empty
 where
  go _ [] = []
  go seen (path : rest)
    | Set.member path seen = go seen rest
    | otherwise = path : go (Set.insert path seen) rest

resolveAgainst :: FilePath -> FilePath -> FilePath
resolveAgainst root path
  | isAbsolute path = normalise path
  | otherwise = normalise (root </> path)

{-| Read the parts of the manifest the compiler and `pudu install` act on.

    Deliberately not the whole of TOML: this runs before anything is compiled,
    including `Std.Toml`, and a manifest is a handful of keys under two
    headings. A key this does not recognise is passed over rather than
    refused, so a manifest may carry whatever else a project needs. -}
parseManifest :: Text -> Manifest
parseManifest contents = go (zip [1 ..] (Text.lines contents)) "" emptyManifest
 where
  go [] _ manifest = manifest{manifestDependencies = reverse (manifestDependencies manifest)}
  go ((number, line) : rest) section manifest =
    let trimmed = Text.strip (dropComment line)
     in if Text.null trimmed
          then go rest section manifest
          else case Text.stripPrefix "[" trimmed >>= Text.stripSuffix "]" of
            Just heading -> go rest (Text.strip heading) manifest
            Nothing -> case splitAssignment trimmed of
              Nothing -> go rest section manifest
              Just (rawKey, value)
                | section == "package" -> go rest section (packageField (unquote rawKey) value manifest)
                | section == "dependencies" ->
                    let key = unquote rawKey
                     in go rest section
                          manifest
                            { manifestDependencies =
                                Dependency key (dependencySourceOf key value) number
                                  : manifestDependencies manifest
                            }
                | otherwise -> go rest section manifest
  packageField key value manifest = case key of
    "name" -> manifest{manifestName = Just (unquote value)}
    "language" -> manifest{manifestLanguage = Just (unquote value)}
    "source" -> manifest{manifestSource = Just (Text.unpack (unquote value))}
    "version" -> manifest{manifestVersion = Just (unquote value)}
    "root" -> manifest{manifestRoot = Just (unquote value)}
    "description" -> manifest{manifestDescription = Just (unquote value)}
    "license" -> manifest{manifestLicense = Just (unquote value)}
    "keywords" -> manifest{manifestKeywords = stringList value}
    _ -> manifest

stringList :: Text -> [Text]
stringList value = case Text.stripPrefix "[" (Text.strip value) >>= Text.stripSuffix "]" of
  Just inner -> filter (not . Text.null) (map (unquote . Text.strip) (Text.splitOn "," inner))
  Nothing -> []

{-| The ways a dependency is written.

    A key naming a registry package, `"@alice/json" = "^1.4"`, takes a
    requirement. Any other key takes a path, written bare as it always has
    been, or a table: `{ path = "../other" }`, `{ git = "…", rev = "v1.2" }`
    (or `tag`, or `branch`), or `{ version = "^1.4" }` under a registry key. -}
dependencySourceOf :: Text -> Text -> DependencySource
dependencySourceOf key value
  | Text.isPrefixOf "{" trimmed =
      let inner = Text.dropEnd 1 (Text.drop 1 trimmed)
          fields = map (\(k, v) -> (k, unquote v)) (mapMaybe splitAssignment (map Text.strip (Text.splitOn "," inner)))
          revision = firstOf ["rev", "tag", "branch"] fields
       in case (lookup "path" fields, lookup "git" fields, lookup "version" fields) of
            (Just path, _, _) -> PathSource (Text.unpack path)
            (_, Just url, _) -> GitSource url revision
            (_, _, Just requirement) | registered -> RegistrySource requirement
            _ -> UnreadableSource "a dependency table needs path, git, or (for @handle/name) version"
  | registered = RegistrySource (unquote trimmed)
  | otherwise = PathSource (Text.unpack (unquote trimmed))
 where
  trimmed = Text.strip value
  registered = case parsePackageId key of
    Right package -> "@" `Text.isPrefixOf` renderPackageId package
    Left _ -> False
  firstOf names fields = case mapMaybe (`lookup` fields) names of
    found : _ -> Just found
    [] -> Nothing

splitAssignment :: Text -> Maybe (Text, Text)
splitAssignment line = case Text.breakOn "=" line of
  (_, rest) | Text.null rest -> Nothing
  (key, rest) -> Just (Text.strip key, Text.strip (Text.drop 1 rest))

{-| A comment is dropped, unless the `#` is inside quotes — a path may hold one. -}
dropComment :: Text -> Text
dropComment line = Text.pack (walk (Text.unpack line) False)
 where
  walk [] _ = []
  walk ('"' : rest) quoted = '"' : walk rest (not quoted)
  walk ('#' : rest) False = if all isSpace rest then [] else []
  walk (c : rest) quoted = c : walk rest quoted

unquote :: Text -> Text
unquote value = case Text.stripPrefix "\"" value >>= Text.stripSuffix "\"" of
  Just inner -> inner
  Nothing -> case Text.stripPrefix "'" value >>= Text.stripSuffix "'" of
    Just inner -> inner
    Nothing -> value

manifestVersionDiagnostics :: FilePath -> IO [Diagnostic]
manifestVersionDiagnostics sourceRoot =
  manifestSnapshotDiagnostics <$> readManifestSnapshot sourceRoot

manifestReadFailure :: FilePath -> IOException -> IO [Diagnostic]
manifestReadFailure path problem =
  reportManifest path Text.empty ("cannot read project manifest: " <> Text.pack (show problem))

versionDiagnostics :: FilePath -> Text -> Manifest -> IO [Diagnostic]
versionDiagnostics path contents manifest = case manifestLanguage manifest of
  Nothing -> pure []
  Just constraint -> case acceptsLanguage constraint of
    Left problem -> reportManifest path contents ("invalid package.language: " <> problem)
    Right True -> pure []
    Right False -> reportManifest path contents
      ("package.language requires " <> constraint <> "; this compiler is " <> versionText)

reportManifest :: FilePath -> Text -> Text -> IO [Diagnostic]
reportManifest = reportCoded "E2090"

reportCoded :: Text -> FilePath -> Text -> Text -> IO [Diagnostic]
reportCoded code path contents message = do
  source <- newSource (SourceName (Text.pack path)) contents
  pure (maybeToList $ do
    known <- mkDiagnosticCode code
    diagnostic known Error (emptySpan source) message)
