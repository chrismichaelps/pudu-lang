{-| @Package.Install — make `deps/` and `pudu.lock` say what `pudu.toml` asks

    One function does the work of every command that changes dependencies:
    read the manifest, turn each dependency into what it asks for, choose one
    version of every package, check that the chosen packages can share a
    program, write the lock, and bring `deps/` into line with it. The commands
    differ only in how they change the manifest first and which locked choices
    they let go of.

    Dependencies are expanded, fetched, and copied concurrently, and each
    step is reported to `optionProgress`.

    Nothing is written until everything is known to fit. A failure leaves the
    manifest's caller to restore its edit, the lock as it was, and `deps/`
    untouched. -}
module Pudu.Package.Install
  ( Options (..)
  , defaultOptions
  , Project (..)
  , openProject
  , Outcome (..)
  , Change (..)
  , synchronise
  , sourceDirectoryOf
  ) where

import Control.Exception (IOException, try)
import Control.Monad (filterM, forM, forM_, unless, when)
import Data.Maybe (fromMaybe)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Manifest
  ( Dependency (..)
  , DependencySource (..)
  , Manifest (..)
  , findManifestRoot
  , parseManifest
  )
import Pudu.Package.Concurrent (concurrentLimit, forConcurrently)
import Pudu.Package.Digest (cachedTreeDigest, copyTree, renderTreeProblem, treeDigest, treeFingerprint)
import Pudu.Package.Git (GitCheckout (..), GitSession, checkoutGit, newGitSession)
import Pudu.Package.GitHubIndex (repositoryUrl)
import Pudu.Package.Identity
  ( PackageId (..)
  , defaultRoot
  , installDirectory
  , parsePackageId
  , renderPackageId
  , reservedRoots
  , validRoot
  )
import Pudu.Package.Lock (Lock (..), LockEntry (..), emptyLock, lockFileName, parseLock, renderLock)
import Pudu.Package.Progress (Event (..), Progress, emit, silentProgress)
import Pudu.Package.Solve
  ( Node (..)
  , NodeSource (..)
  , Preference (..)
  , Registry (..)
  , Want (..)
  , solve
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getCurrentDirectory
  , listDirectory
  , removeDirectoryRecursive
  , renameDirectory
  , renameFile
  )
import System.FilePath (isAbsolute, normalise, takeDirectory, (</>))

data Options = Options
  { optionOffline :: !Bool
  , optionLocked :: !Bool
  , optionRefresh :: !(PackageId -> Bool)
  , optionProgress :: !Progress
  , optionGit :: !(Maybe GitSession)
  -- ^ Git session shared with the caller; a new one is opened when absent.
  }

defaultOptions :: Options
defaultOptions = Options False False (const False) silentProgress Nothing

data Project = Project
  { projectRoot :: !FilePath
  , projectManifestText :: !Text
  , projectManifest :: !Manifest
  , projectLock :: !Lock
  }

{-| The project the current directory is in, with its lock. -}
openProject :: IO (Either Text Project)
openProject = do
  here <- getCurrentDirectory
  found <- findManifestRoot here
  case found of
    Nothing -> pure (Left "there is no pudu.toml here or above; run pudu init to start a project")
    Just root -> do
      text <- TextIO.readFile (root </> "pudu.toml")
      let lockPath = root </> lockFileName
      present <- doesFileExist lockPath
      locked <-
        if present
          then parseLock <$> TextIO.readFile lockPath
          else pure (Right emptyLock)
      pure $ case locked of
        Left problem -> Left (problem <> "; delete pudu.lock and run pudu install to write a new one")
        Right lock -> Right (Project root text (parseManifest text) lock)

data Change
  = Added !PackageId !Text
  | Removed !PackageId !Text
  | Moved !PackageId !Text !Text
  deriving stock (Eq, Show)

data Outcome = Outcome
  { outcomeChanges :: ![Change]
  , outcomeLock :: !Lock
  , outcomeLockWritten :: !Bool
  , outcomeInstalled :: !Int
  , outcomeRoots :: ![(PackageId, Text)]
  }

{-| Bring the lock and `deps/` into line with a manifest's text. -}
synchronise :: Registry -> Options -> FilePath -> Text -> Lock -> IO (Either Text Outcome)
synchronise registry given root manifestText oldLock = do
  session <- maybe (newGitSession (optionOffline given) (optionProgress given)) pure (optionGit given)
  let options = given{optionGit = Just session}
      manifest = parseManifest manifestText
      preference = Preference (Map.fromList [(entryName e, entryVersion e) | e <- lockEntries oldLock]) (optionRefresh options)
  expanded <- wantsOf options oldLock root root True (manifestDependencies manifest)
  case expanded of
    Left problem -> pure (Left problem)
    Right wants -> do
      solved <- solve registry preference [("pudu.toml", package, want) | (package, want) <- wants]
      case solved of
        Left problem -> pure (Left problem)
        Right nodes -> do
          emit (optionProgress options) (Resolved (length nodes))
          contents <- forConcurrently concurrentLimit nodes (contentOf registry)
          case sequence contents of
            Left problem -> pure (Left problem)
            Right located -> do
              checked <- checkShared manifest located
              case checked of
                Left problem -> pure (Left problem)
                Right () -> do
                  entries <- forConcurrently concurrentLimit [(n, d) | (n, Just d) <- located] (entryFor registry)
                  case sequence entries of
                    Left problem -> pure (Left problem)
                    Right lockEntriesNew -> finish options root oldLock (Lock (sortOn (renderPackageId . entryName) lockEntriesNew)) located

finish :: Options -> FilePath -> Lock -> Lock -> [(Node, Maybe FilePath)] -> IO (Either Text Outcome)
finish options root oldLock newLock located = do
  let changed = renderLock newLock /= renderLock oldLock
      changes = difference oldLock newLock
  if changed && optionLocked options
    then
      pure
        ( Left
            ( "--locked was given, and pudu.lock does not match pudu.toml:\n"
                <> Text.unlines (map (("  " <>) . describeChange) changes)
                <> "run pudu install without --locked to update it"
            )
        )
    else do
      let writeLock = when changed $ do
            let path = root </> lockFileName
            TextIO.writeFile (path <> ".partial") (renderLock newLock)
            renameFile (path <> ".partial") path
      installed <- materialise (optionProgress options) root newLock (Map.fromList [(nodeId n, d) | (n, Just d) <- located]) writeLock
      case installed of
        Left problem -> pure (Left problem)
        Right count ->
          pure
            ( Right
                Outcome
                  { outcomeChanges = changes
                  , outcomeLock = newLock
                  , outcomeLockWritten = changed
                  , outcomeInstalled = count
                  , outcomeRoots = [(nodeId n, nodeRoot n) | (n, _) <- located, not (Text.null (nodeRoot n))]
                  }
            )

describeChange :: Change -> Text
describeChange change = case change of
  Added package version -> "+ " <> renderPackageId package <> " " <> version
  Removed package version -> "- " <> renderPackageId package <> " " <> version
  Moved package old new -> "~ " <> renderPackageId package <> " " <> old <> " -> " <> new

difference :: Lock -> Lock -> [Change]
difference (Lock old) (Lock new) =
  [Added (entryName e) (entryVersion e) | e <- new, entryName e `notElem` map entryName old]
    <> [Removed (entryName e) (entryVersion e) | e <- old, entryName e `notElem` map entryName new]
    <> [ Moved (entryName e) (entryVersion o) (entryVersion e)
       | e <- new
       , o <- old
       , entryName o == entryName e
       , entryVersion o /= entryVersion e || entrySource o /= entrySource e
       ]

{-| Each dependency of a manifest as what it asks for.

    Repositories and directories are read here, before solving, because what
    they contain does not depend on anything else chosen. `top` marks the
    project's own manifest: a directory may be named there, and not by a
    package that came from a repository, which would name a directory on
    whoever published it. -}
wantsOf :: Options -> Lock -> FilePath -> FilePath -> Bool -> [Dependency] -> IO (Either Text [(PackageId, Want)])
wantsOf options lock projectRoot base top dependencies = do
  results <- forConcurrently concurrentLimit dependencies $ \dependency -> do
    let key = dependencyName dependency
        at = "pudu.toml:" <> Text.pack (show (dependencyLine dependency)) <> ": "
    case parsePackageId key of
      Left problem -> pure (Left (at <> problem))
      Right package -> case dependencySource dependency of
        UnreadableSource reason -> pure (Left (at <> key <> ": " <> reason))
        RegistrySource requirement -> pure (Right (package, WantRelease requirement))
        PathSource path
          | not top -> pure (Left (key <> " is a path dependency of a package from a repository or the registry; only a project may name a directory"))
          | otherwise -> do
              let directory = normalise (if isAbsolute path then path else base </> path)
              exists <- doesDirectoryExist directory
              if not exists
                then pure (Left (at <> key <> " names " <> Text.pack directory <> ", which does not exist"))
                else fixedFrom options lock projectRoot package (FromPath directory) directory True
        GitSource url revision -> do
          let lockedCommit = do
                entry <- lookupEntry package lock
                if optionRefresh options package then Nothing else lockedGitCommit url revision (entrySource entry)
          session <- maybe (newGitSession (optionOffline options) (optionProgress options)) pure (optionGit options)
          fetched <- checkoutGit session url (fromMaybe (fromMaybe "HEAD" revision) lockedCommit)
          case fetched of
            Left problem -> pure (Left (at <> key <> ": " <> problem))
            Right checkout ->
              fixedFrom options lock projectRoot package
                (FromGit (gitSourceText url revision) (checkoutCommit checkout) (checkoutDirectory checkout))
                (checkoutDirectory checkout) False
  pure (sequence results)

fixedFrom :: Options -> Lock -> FilePath -> PackageId -> NodeSource -> FilePath -> Bool -> IO (Either Text (PackageId, Want))
fixedFrom options lock projectRoot package source directory isPath = do
  hasManifest <- doesFileExist (directory </> "pudu.toml")
  if not hasManifest
    then
      if isPath
        then pure (Right (package, WantFixed source "0.0.0" "" []))
        else pure (Left (renderPackageId package <> " has no pudu.toml at the revision asked for, so it is not a Pudu package"))
    else do
      own <- parseManifest <$> TextIO.readFile (directory </> "pudu.toml")
      let version = maybe "0.0.0" id (manifestVersion own)
          root = maybe (defaultRoot (named own)) id (manifestRoot own)
          named m = case manifestName m >>= either (const Nothing) Just . parsePackageId of
            Just identity -> identity
            Nothing -> package
      case validRoot root of
        Left problem -> pure (Left (renderPackageId package <> ": " <> problem))
        Right _ -> do
          inner <- wantsOf options lock projectRoot directory isPath (manifestDependencies own)
          pure $ case inner of
            Left problem -> Left (renderPackageId package <> " → " <> problem)
            Right wants -> Right (package, WantFixed source version root [(renderPackageId p, w) | (p, w) <- wants])

gitSourceText :: Text -> Maybe Text -> Text
gitSourceText url revision = "git+" <> url <> maybe "" ("?rev=" <>) revision

lockedGitCommit :: Text -> Maybe Text -> Text -> Maybe Text
lockedGitCommit url revision source = do
  rest <- Text.stripPrefix (gitSourceText url revision <> "#") source
  if Text.null rest then Nothing else Just rest

lookupEntry :: PackageId -> Lock -> Maybe LockEntry
lookupEntry package (Lock entries) = case filter ((== package) . entryName) entries of
  entry : _ -> Just entry
  [] -> Nothing

{-| Where a chosen package's files are, or nothing for a directory used in place. -}
contentOf :: Registry -> Node -> IO (Either Text (Node, Maybe FilePath))
contentOf registry node = case nodeSource node of
  FromPath _ -> pure (Right (node, Nothing))
  FromGit _ _ directory -> pure (Right (node, Just directory))
  FromRegistry _ checksum -> fmap (\d -> (node, Just d)) <$> registryFetch registry (nodeId node) (nodeVersion node) checksum

entryFor :: Registry -> (Node, FilePath) -> IO (Either Text LockEntry)
entryFor _ (node, directory) = do
  (source, checksum) <- case nodeSource node of
    FromRegistry base commit -> do
      digest <- cachedTreeDigest directory
      pure (Right ("github+" <> repositoryUrl base (nodeId node) <> "#" <> commit), either (Left . renderTreeProblem) Right digest)
    FromGit url commit _ -> do
      digest <- cachedTreeDigest directory
      pure (Right (url <> "#" <> commit), either (Left . renderTreeProblem) Right digest)
    FromPath path -> pure (Left ("a directory is not locked: " <> Text.pack path), Left "")
  pure $ do
    s <- source
    c <- checksum
    Right (LockEntry (nodeId node) (nodeVersion node) s c (nodeRoot node) (map renderPackageId (nodeDependencies node)))

{-| Whether the chosen packages can share one program.

    Each owns a module root, and no two — nor the project itself — may own the
    same one. None may ship a module under a root the compiler owns: that
    includes a directory named by path when it is a package with its own
    manifest, and not a plain directory of the project's own modules, which may
    shadow a standard module deliberately. -}
checkShared :: Manifest -> [(Node, Maybe FilePath)] -> IO (Either Text ())
checkShared manifest located = do
  let own = case manifestName manifest >>= either (const Nothing) Just . parsePackageId of
        Just identity -> [("the project itself", maybe (defaultRoot identity) id (manifestRoot manifest))]
        Nothing -> maybe [] (\r -> [("the project itself", r)]) (manifestRoot manifest)
      claims = own <> [(renderPackageId (nodeId n), nodeRoot n) | (n, _) <- located, not (Text.null (nodeRoot n))]
      owners = Map.fromListWith (<>) [(r, [who]) | (who, r) <- claims]
      clashes = [(r, whos) | (r, whos) <- Map.toList owners, length whos > 1]
  let packaged = [(n, d) | (n, Just d) <- located] <> [(n, d) | (n, Nothing) <- located, FromPath d <- [nodeSource n], not (Text.null (nodeRoot n))]
  shipped <- forM packaged $ \(node, directory) -> do
    source <- sourceDirectoryOf directory
    offending <- filterM (doesDirectoryExist . (source </>) . Text.unpack) reservedRoots
    pure [(renderPackageId (nodeId node), r) | r <- offending]
  pure $ case (clashes, concat shipped) of
    ((root, whos) : _, _) ->
      Left
        ( Text.intercalate " and " (reverse whos) <> " both own the module root " <> root
            <> "; a program can use only one package for each root"
        )
    ([], (who, root) : _) ->
      Left (who <> " ships modules under " <> root <> ", which belongs to the compiler; it cannot be installed")
    ([], []) -> Right ()

{-| Where a package's modules are: its manifest's `source`, or `src`, or the
    package directory itself when it has neither. -}
sourceDirectoryOf :: FilePath -> IO FilePath
sourceDirectoryOf directory = do
  hasManifest <- doesFileExist (directory </> "pudu.toml")
  configured <-
    if hasManifest
      then manifestSource . parseManifest <$> TextIO.readFile (directory </> "pudu.toml")
      else pure Nothing
  let candidate = directory </> maybe "src" id configured
  exists <- doesDirectoryExist candidate
  pure (if exists then candidate else directory)

{-| Make `deps/` hold exactly the locked packages, and run `commit` (which
    writes the lock) once every package is known to install.

    Each installed package has a `.installed` marker holding the locked
    checksum, the tree digest, and the fingerprint. A package is kept when the
    checksum matches and either the fingerprint matches or the recomputed tree
    digest matches. Every other package is first copied into
    `<destination>.partial`; for a git package the digest of the copied files
    must equal the locked checksum. If any copy fails, every staged copy is
    removed and nothing else changes. Otherwise `commit` runs, each staged
    copy replaces its destination by rename, and entries in `deps/` the lock
    does not name are removed. -}
materialise :: Progress -> FilePath -> Lock -> Map.Map PackageId FilePath -> IO () -> IO (Either Text Int)
materialise progress root (Lock entries) contents commit = do
  staged <- forConcurrently concurrentLimit entries $ \entry -> do
    let destination = installDirectory root (entryName entry)
        marker = destination </> ".installed"
    fresh <- isFresh destination marker (entryChecksum entry)
    if fresh
      then do
        emit progress (UpToDate (entryName entry))
        pure (Right Nothing)
      else case Map.lookup (entryName entry) contents of
        Nothing -> pure (Left (renderPackageId (entryName entry) <> " is locked but its files are not available"))
        Just from -> do
          emit progress (CopyStarted (entryName entry) (entryVersion entry))
          let staging = destination <> ".partial"
          leftover <- doesDirectoryExist staging
          when leftover (removeDirectoryRecursive staging)
          createDirectoryIfMissing True (takeDirectory destination)
          copied <- copyTree from staging
          case copied of
            Left problem -> pure (Left (renderTreeProblem problem))
            Right digest
              | any (`Text.isPrefixOf` entrySource entry) ["git+", "github+"] && digest /= entryChecksum entry ->
                  pure
                    ( Left
                        ( "the files of " <> renderPackageId (entryName entry) <> " have digest " <> digest
                            <> ", and pudu.lock records " <> entryChecksum entry
                            <> "; nothing was installed"
                        )
                    )
              | otherwise -> do
                  writeMarker (staging </> ".installed") (entryChecksum entry) digest staging
                  pure (Right (Just (entryName entry, staging, destination)))
  case sequence staged of
    Left problem -> do
      forM_ entries $ \entry -> do
        let staging = installDirectory root (entryName entry) <> ".partial"
        leftover <- doesDirectoryExist staging
        when leftover (removeDirectoryRecursive staging)
      pure (Left problem)
    Right results -> do
      commit
      let swaps = [swap | Just swap <- results]
      forM_ swaps $ \(package, staging, destination) -> do
        replaceDirectory staging destination
        emit progress (CopyFinished package)
      pruned <- prune root [installDirectory root (entryName e) | e <- entries]
      pure (length swaps <$ pruned)

{-| Move a directory into place, replacing what was there: the old one is
    renamed aside first and removed after the new one has its name. -}
replaceDirectory :: FilePath -> FilePath -> IO ()
replaceDirectory staging destination = do
  exists <- doesDirectoryExist destination
  let aside = destination <> ".replaced"
  leftover <- doesDirectoryExist aside
  when leftover (removeDirectoryRecursive aside)
  when exists (renameDirectory destination aside)
  renameDirectory staging destination
  when exists (removeDirectoryRecursive aside)

isFresh :: FilePath -> FilePath -> Text -> IO Bool
isFresh destination marker checksum = do
  current <- readMarker marker
  case current of
    Just (recorded, digest, fingerprint) | recorded == checksum -> do
      now <- treeFingerprint destination
      if now == Right fingerprint
        then pure True
        else do
          hashed <- treeDigest destination
          if hashed == Right digest
            then True <$ writeMarker marker checksum digest destination
            else pure False
    _ -> pure False

writeMarker :: FilePath -> Text -> Text -> FilePath -> IO ()
writeMarker marker checksum digest destination = do
  fingerprint <- either (const "") id <$> treeFingerprint destination
  TextIO.writeFile marker (checksum <> "\n" <> digest <> "\n" <> fingerprint <> "\n")

readMarker :: FilePath -> IO (Maybe (Text, Text, Text))
readMarker path = do
  present <- doesFileExist path
  if not present
    then pure Nothing
    else do
      loaded <- try (TextIO.readFile path) :: IO (Either IOException Text)
      pure $ case fmap Text.lines loaded of
        Right [checksum, digest, fingerprint] -> Just (checksum, digest, fingerprint)
        Right [checksum, digest] -> Just (checksum, digest, "")
        _ -> Nothing

prune :: FilePath -> [FilePath] -> IO (Either Text ())
prune root kept = do
  let deps = root </> "deps"
  exists <- doesDirectoryExist deps
  if not exists
    then pure (Right ())
    else do
      top <- listDirectory deps
      forM_ top $ \name -> do
        let path = deps </> name
        isDirectory <- doesDirectoryExist path
        when isDirectory $
          if take 1 name == "@"
            then do
              inner <- listDirectory path
              forM_ inner $ \project -> do
                let full = path </> project
                unless (full `elem` kept) (removeDirectoryRecursive full)
              remaining <- listDirectory path
              when (null remaining) (removeDirectoryRecursive path)
            else unless (path `elem` kept) (removeDirectoryRecursive path)
      pure (Right ())
