{-| @Test.Pudu.PackageSpec — dependencies: versions, locks, installation, resolution -}
module Pudu.PackageSpec
  ( packageProperties
  ) where

import Control.Exception (ErrorCall (..), evaluate, throwIO, try)
import Control.Monad (forM_)
import Data.IORef (atomicModifyIORef', newIORef, readIORef)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Library (searchRoots)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Package.Digest (treeDigest)
import Pudu.Package.Identity
  ( InstallSpec (..)
  , PackageId (..)
  , defaultRoot
  , parseInstallSpec
  , parsePackageId
  , validRoot
  )
import Pudu.Package.Concurrent (forConcurrently)
import Pudu.Package.Git (cacheRoot)
import Pudu.Package.Install (Options (..), Outcome (..), defaultOptions, synchronise)
import Pudu.Package.Progress (Event (..), Progress (..))
import Pudu.Package.Lock (Lock (..), LockEntry (..), emptyLock, parseLock, renderLock)
import Pudu.Package.ManifestEdit (removeDependency, setDependency)
import Pudu.Package.Solve
  ( Node (..)
  , Preference (..)
  , Registry (..)
  , ReleaseInfo (..)
  , Want (..)
  , noRegistry
  , solve
  )
import Pudu.Package.Version
  ( parseRequirement
  , parseVersion
  , renderVersion
  , satisfies
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getModificationTime
  , listDirectory
  , removeDirectoryRecursive
  , setModificationTime
  )
import System.Environment (lookupEnv, setEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

packageProperties :: [(String, IO Property)]
packageProperties =
  [ ("package versions order and render as released", pure testVersions)
  , ("package requirements accept what they say", pure testRequirements)
  , ("package names and install arguments are read or refused", pure testIdentity)
  , ("a package lock reads back what it wrote", pure testLockRoundTrip)
  , ("a package lock names the line it cannot read", pure testLockErrors)
  , ("a manifest edit changes one dependency line", pure testManifestEdits)
  , ("a tree digest follows content and nothing else", testTreeDigest)
  , ("the solver prefers the lock, then the newest, and backtracks", testSolverChoices)
  , ("the solver names every requirement it cannot meet", testSolverConflict)
  , ("a git package installs, locks, and restores itself", testGitInstall)
  , ("installed packages join resolution and never supply Std", testResolution)
  , ("two packages may not own one module root", testRootConflict)
  , ("a package shipping Std is refused", testStdRefused)
  , ("--locked refuses a lock that would change", testLockedRefusal)
  , ("a locked, cached repository installs without running git", testNoGitWhenCached)
  , ("installing reports what it fetches, copies, and leaves alone", testProgressEvents)
  , ("a touched but unchanged package is not copied again", testTouchedStaysInstalled)
  , ("a damaged cached checkout is refused", testDamagedCacheRefused)
  , ("concurrent package work keeps order and raises failures", testConcurrent)
  ]

testVersions :: Property
testVersions = conjoin
  [ fmap renderVersion (parseVersion "1.4.2") === Right "1.4.2"
  , fmap renderVersion (parseVersion "2.0.0-beta.1") === Right "2.0.0-beta.1"
  , counterexample "a pre-release sorts before its release" (ordered "1.0.0-rc.1" "1.0.0")
  , counterexample "numeric pre-release fields compare as numbers" (ordered "1.0.0-beta.2" "1.0.0-beta.10")
  , counterexample "a number sorts before a word" (ordered "1.0.0-1" "1.0.0-alpha")
  , counterexample "minor beats patch" (ordered "1.9.9" "1.10.0")
  , refused "1.4"
  , refused "01.2.3"
  , refused "1.2.3+build"
  , refused "one.two.three"
  ]
 where
  ordered a b = case (parseVersion a, parseVersion b) of
    (Right x, Right y) -> x < y
    _ -> False
  refused text = counterexample (Text.unpack text <> " should be refused") (either (const True) (const False) (parseVersion text))

testRequirements :: Property
testRequirements = conjoin
  [ accepts "^1.4" "1.4.0" True
  , accepts "^1.4" "1.9.3" True
  , accepts "^1.4" "2.0.0" False
  , accepts "1.4.2" "1.4.1" False
  , accepts "^0.3.1" "0.3.9" True
  , accepts "^0.3.1" "0.4.0" False
  , accepts "^0.0.3" "0.0.4" False
  , accepts "~1.4.2" "1.4.9" True
  , accepts "~1.4.2" "1.5.0" False
  , accepts "~1" "1.9.0" True
  , accepts "=1.4.2" "1.4.2" True
  , accepts "=1.4.2" "1.4.3" False
  , accepts ">=1.2, <1.8" "1.7.9" True
  , accepts ">=1.2, <1.8" "1.8.0" False
  , accepts "*" "0.0.1" True
  , counterexample "a pre-release is not chosen unless asked for" (accepts "^1.4" "1.5.0-beta.1" False)
  , counterexample "a named pre-release accepts later pre-releases of it" (accepts "^1.5.0-beta.1" "1.5.0-beta.2" True)
  , counterexample "an empty requirement is refused" (either (const True) (const False) (parseRequirement ""))
  ]
 where
  accepts requirement version expected =
    counterexample (Text.unpack (requirement <> " / " <> version)) $
      case (parseRequirement requirement, parseVersion version) of
        (Right r, Right v) -> satisfies r v === expected
        _ -> property False

testIdentity :: Property
testIdentity = conjoin
  [ parsePackageId "@alice/json-schema" === Right (Registered "alice" "json-schema")
  , parsePackageId "geometry" === Right (LocalName "geometry")
  , refused (parsePackageId "@std/json")
  , refused (parsePackageId "@Alice/json")
  , refused (parsePackageId "@alice/json--schema")
  , refused (parsePackageId "@alice")
  , defaultRoot (Registered "alice" "json-schema") === "JsonSchema"
  , validRoot "Std" === Left "Std belongs to the compiler; a package may not own it"
  , refused (validRoot "json")
  , parseInstallSpec "@alice/json" === Right (SpecRegistry (Registered "alice" "json") Nothing)
  , parseInstallSpec "@alice/json@1.2.3" === Right (SpecRegistry (Registered "alice" "json") (Just "1.2.3"))
  , parseInstallSpec "@alice/json@^1.2" === Right (SpecRegistry (Registered "alice" "json") (Just "^1.2"))
  , parseInstallSpec "../geometry" === Right (SpecPath "../geometry")
  , parseInstallSpec "https://example.org/parser.git#v1" === Right (SpecGit "https://example.org/parser.git" (Just "v1"))
  , parseInstallSpec "git+file:///tmp/lib" === Right (SpecGit "file:///tmp/lib" Nothing)
  , refused (parseInstallSpec "json")
  , refused (parseInstallSpec "@alice/json@")
  ]
 where
  refused :: Either Text a -> Property
  refused = property . either (const True) (const False)

sampleLock :: Lock
sampleLock =
  Lock
    [ LockEntry (Registered "alice" "json") "1.4.2" "registry+https://packages.example" "sha256:ab" "Json" ["@bob/text"]
    , LockEntry (LocalName "parser") "0.4.0" "git+https://example.org/p?rev=v0.4.0#3b1e" "sha256:cd" "Parser" []
    ]

testLockRoundTrip :: Property
testLockRoundTrip = conjoin
  [ parseLock (renderLock sampleLock) === Right sampleLock
  , parseLock (renderLock emptyLock) === Right emptyLock
  , counterexample "entries render in name order whatever order they arrived in"
      (renderLock (Lock (reverse (lockEntries sampleLock))) === renderLock sampleLock)
  ]

testLockErrors :: Property
testLockErrors = conjoin
  [ counterexample "a newer lock format is refused" (isLeftContaining "version 2" (parseLock "version = 2\n"))
  , counterexample "a missing field is named"
      (isLeftContaining "checksum" (parseLock "version = 1\n[[package]]\nname = \"x\"\nversion = \"1.0.0\"\nsource = \"s\"\nroot = \"X\"\n"))
  , counterexample "an unquoted value names its line"
      (isLeftContaining "pudu.lock:4" (parseLock "version = 1\n\n[[package]]\nname = x\n"))
  ]

isLeftContaining :: Text -> Either Text a -> Bool
isLeftContaining needle = either (needle `Text.isInfixOf`) (const False)

testManifestEdits :: Property
testManifestEdits = conjoin
  [ setDependency "@alice/json" "\"^1.4\"" manifest
      === "[package]\nname = \"app\"\n\n# what we use\n[dependencies]\ngeometry = \"../geometry\"\n\"@alice/json\" = \"^1.4\"\n\n[lint]\nstrict = true\n"
  , setDependency "geometry" "{ path = \"../geo\" }" manifest
      === "[package]\nname = \"app\"\n\n# what we use\n[dependencies]\ngeometry = { path = \"../geo\" }\n\n[lint]\nstrict = true\n"
  , removeDependency "geometry" manifest
      === Just "[package]\nname = \"app\"\n\n# what we use\n[dependencies]\n\n[lint]\nstrict = true\n"
  , removeDependency "missing" manifest === Nothing
  , setDependency "x" "\"../x\"" "[package]\nname = \"app\"\n"
      === "[package]\nname = \"app\"\n\n[dependencies]\nx = \"../x\"\n"
  ]
 where
  manifest = "[package]\nname = \"app\"\n\n# what we use\n[dependencies]\ngeometry = \"../geometry\"\n\n[lint]\nstrict = true\n"

testTreeDigest :: IO Property
testTreeDigest = withSystemTempDirectory "pudu-digest" $ \root -> do
  let one = root </> "one"
      two = root </> "two"
  forM_ [one, two] $ \directory -> do
    createDirectoryIfMissing True (directory </> "src" </> "Lib")
    TextIO.writeFile (directory </> "src" </> "Lib" </> "A.pudu") "module Lib.A\n"
    createDirectoryIfMissing True (directory </> ".git")
  TextIO.writeFile (two </> ".git" </> "HEAD") "ignored"
  first <- treeDigest one
  second <- treeDigest two
  TextIO.writeFile (two </> "src" </> "Lib" </> "A.pudu") "module Lib.A\n// changed\n"
  third <- treeDigest two
  pure $ conjoin
    [ counterexample "dot directories are not content" (first === second)
    , counterexample "a changed file changes the digest" (property (first /= third))
    ]

releasesFrom :: [(Text, [(Text, [(Text, Text)])])] -> Registry
releasesFrom table =
  noRegistry
    { registryUrl = "https://packages.example"
    , registryReleases = \package ->
        pure $ case lookup (render package) table of
          Nothing -> Left (render package <> " is not a project")
          Just releases ->
            Right
              [ ReleaseInfo v ("sha256:" <> version) dependencies "Root" False
              | (version, dependencies) <- releases
              , Right v <- [parseVersion version]
              ]
    }
 where
  render (Registered h n) = "@" <> h <> "/" <> n
  render (LocalName n) = n

chosen :: Either Text [Node] -> Map.Map Text Text
chosen (Right nodes) = Map.fromList [(name (nodeId n), nodeVersion n) | n <- nodes]
 where
  name (Registered h n) = "@" <> h <> "/" <> n
  name (LocalName n) = n
chosen (Left _) = Map.empty

testSolverChoices :: IO Property
testSolverChoices = do
  let registry =
        releasesFrom
          [ ("@a/app-lib", [("1.0.0", [("@b/text", "^1.0")]), ("1.1.0", [("@b/text", "^2.0")])])
          , ("@b/text", [("1.0.0", []), ("1.2.0", [])])
          ]
      fresh = Preference Map.empty (const False)
      locked = Preference (Map.fromList [(Registered "b" "text", "1.0.0")]) (const False)
  backtracked <- solve registry fresh [("pudu.toml", Registered "a" "app-lib", WantRelease "^1.0")]
  preferred <- solve registry locked [("pudu.toml", Registered "b" "text", WantRelease "^1.0")]
  refreshedLock <- solve registry locked {refreshed = const True} [("pudu.toml", Registered "b" "text", WantRelease "^1.0")]
  pure $ conjoin
    [ counterexample "1.1.0 needs a text 2 that does not exist, so 1.0.0 is chosen"
        (chosen backtracked === Map.fromList [("@a/app-lib", "1.0.0"), ("@b/text", "1.2.0")])
    , counterexample "a locked version that still fits is kept" (chosen preferred === Map.fromList [("@b/text", "1.0.0")])
    , counterexample "an update lets the lock go" (chosen refreshedLock === Map.fromList [("@b/text", "1.2.0")])
    ]

testSolverConflict :: IO Property
testSolverConflict = do
  let registry =
        releasesFrom
          [ ("@a/one", [("1.0.0", [("@b/text", "^1.0")])])
          , ("@b/text", [("1.0.0", []), ("2.0.0", [])])
          ]
  outcome <-
    solve registry (Preference Map.empty (const False))
      [ ("pudu.toml", Registered "b" "text", WantRelease "^2.0")
      , ("pudu.toml", Registered "a" "one", WantRelease "^1.0")
      ]
  missing <- solve registry (Preference Map.empty (const False)) [("pudu.toml", Registered "a" "nope", WantRelease "*")]
  pure $ conjoin
    [ counterexample (show outcome) (isLeftContaining "^1.0 asked by @a/one 1.0.0" outcome)
    , counterexample (show outcome) (isLeftContaining "^2.0 asked by pudu.toml" outcome)
    , counterexample (show missing) (isLeftContaining "@a/nope is not a project" missing)
    ]

{-| A library in a git repository, tagged, beside a project that uses it. -}
withGitLibrary :: (FilePath -> FilePath -> IO Property) -> IO Property
withGitLibrary body = withSystemTempDirectory "pudu-packages" $ \root -> do
  setEnv "PUDU_HOME" (root </> "home")
  let library = root </> "shapes-kit"
      project = root </> "app"
  createDirectoryIfMissing True (library </> "src" </> "ShapesKit")
  TextIO.writeFile (library </> "pudu.toml") "[package]\nname = \"@ada/shapes-kit\"\nversion = \"0.1.0\"\nsource = \"src\"\n"
  TextIO.writeFile (library </> "src" </> "ShapesKit" </> "Area.pudu") "module ShapesKit.Area\n\nexport fn square(side: Int) -> Int = side * side\n"
  ran <- traverse (git library)
    [ ["init", "-q"], ["add", "."], ["-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "one"], ["tag", "v0.1.0"] ]
  createDirectoryIfMissing True (project </> "src")
  TextIO.writeFile (project </> "src" </> "Main.pudu") "module Main\n"
  if all (== ExitSuccess) ran
    then body library project
    else pure (counterexample "git could not build the fixture repository" (property False))
 where
  git directory arguments = do
    (code, _, _) <- readProcessWithExitCode "git" (["-C", directory] <> arguments) ""
    pure code

installWith :: Options -> FilePath -> Text -> Lock -> IO (Either Text Outcome)
installWith options project manifest lock = do
  TextIO.writeFile (project </> "pudu.toml") manifest
  synchronise noRegistry options project manifest lock

gitManifest :: FilePath -> Text
gitManifest library =
  "[package]\nname = \"app\"\nsource = \"src\"\n\n[dependencies]\nshapes-kit = { git = \"file://" <> Text.pack library <> "\", rev = \"v0.1.0\" }\n"

testGitInstall :: IO Property
testGitInstall = withGitLibrary $ \library project -> do
  first <- installWith defaultOptions project (gitManifest library) emptyLock
  case first of
    Left problem -> pure (counterexample (Text.unpack problem) False)
    Right outcome -> do
      let installed = project </> "deps" </> "shapes-kit" </> "src" </> "ShapesKit" </> "Area.pudu"
      present <- doesFileExist installed
      lockText <- TextIO.readFile (project </> "pudu.lock")
      TextIO.appendFile installed "// edited\n"
      again <- synchronise noRegistry defaultOptions project (gitManifest library) (outcomeLock outcome)
      restored <- TextIO.readFile installed
      offline <- synchronise noRegistry defaultOptions {optionOffline = True} project (gitManifest library) (outcomeLock outcome)
      pure $ conjoin
        [ counterexample "the package's module is installed" present
        , counterexample "the lock records the commit behind the tag" ("?rev=v0.1.0#" `Text.isInfixOf` lockText)
        , counterexample "the lock records the tree digest" ("checksum = \"sha256:" `Text.isInfixOf` lockText)
        , counterexample "the lock records the root" ("root = \"ShapesKit\"" `Text.isInfixOf` lockText)
        , counterexample "an edited installed file is restored" (not ("edited" `Text.isInfixOf` restored))
        , counterexample "the second install changes nothing in the lock" (fmap outcomeLockWritten again === Right False)
        , counterexample "the cache answers when offline" (fmap outcomeLockWritten offline === Right False)
        ]

testResolution :: IO Property
testResolution = withGitLibrary $ \library project -> do
  _ <- installWith defaultOptions project (gitManifest library) emptyLock
  let named segments = ModuleName (NonEmpty.fromList segments)
  ordinary <- searchRoots (project </> "src") (named ["ShapesKit", "Area"])
  standard <- searchRoots (project </> "src") (named ["Std", "Io"])
  let packageRoot = project </> "deps" </> "shapes-kit" </> "src"
  pure $ conjoin
    [ counterexample (show ordinary) (packageRoot `elem` ordinary)
    , counterexample (show standard) (packageRoot `notElem` standard)
    ]

testRootConflict :: IO Property
testRootConflict = withGitLibrary $ \library project -> do
  let other = project </> ".." </> "other"
  createDirectoryIfMissing True (other </> "src" </> "ShapesKit")
  TextIO.writeFile (other </> "pudu.toml") "[package]\nname = \"other\"\nroot = \"ShapesKit\"\n"
  outcome <- installWith defaultOptions project (gitManifest library <> "other = { path = \"../other\" }\n") emptyLock
  lockWritten <- doesFileExist (project </> "pudu.lock")
  pure $ conjoin
    [ counterexample (show (fmap outcomeLockWritten outcome)) (isLeftContaining "both own the module root ShapesKit" outcome)
    , counterexample "nothing is written when the packages cannot share a program" (not lockWritten)
    ]

testStdRefused :: IO Property
testStdRefused = withSystemTempDirectory "pudu-std" $ \root -> do
  let project = root </> "app"
      evil = root </> "evil"
  createDirectoryIfMissing True (project </> "src")
  createDirectoryIfMissing True (evil </> "src" </> "Std")
  TextIO.writeFile (evil </> "pudu.toml") "[package]\nname = \"evil\"\n"
  TextIO.writeFile (evil </> "src" </> "Std" </> "Io.pudu") "module Std.Io\n"
  outcome <- installWith defaultOptions project "[package]\nname = \"app\"\n\n[dependencies]\nevil = { path = \"../evil\" }\n" emptyLock
  installed <- doesDirectoryExist (project </> "deps")
  pure $ conjoin
    [ counterexample (show (fmap outcomeLockWritten outcome)) (isLeftContaining "ships modules under Std" outcome)
    , counterexample "nothing was installed" (not installed)
    ]

testLockedRefusal :: IO Property
testLockedRefusal = withGitLibrary $ \library project -> do
  outcome <- installWith defaultOptions {optionLocked = True} project (gitManifest library) emptyLock
  pure (counterexample (show (fmap outcomeLockWritten outcome)) (isLeftContaining "--locked was given" outcome))

{-| The second install of a locked git package finds its checkout in the cache
    and must not start git: with no `git` on the path it still succeeds. -}
testNoGitWhenCached :: IO Property
testNoGitWhenCached = withGitLibrary $ \library project -> do
  first <- installWith defaultOptions project (gitManifest library) emptyLock
  case first of
    Left problem -> pure (counterexample (Text.unpack problem) False)
    Right outcome -> do
      removeDirectoryRecursive (project </> "deps")
      path <- lookupEnv "PATH"
      setEnv "PATH" "/nonexistent"
      again <- synchronise noRegistry defaultOptions project (gitManifest library) (outcomeLock outcome)
      setEnv "PATH" (maybe "" id path)
      restored <- doesFileExist (project </> "deps" </> "shapes-kit" </> "src" </> "ShapesKit" </> "Area.pudu")
      pure $ conjoin
        [ counterexample (show (fmap outcomeInstalled again)) (fmap outcomeInstalled again === Right 1)
        , counterexample "deps/ was restored from the cache alone" restored
        ]

recording :: IO (Progress, IO [Event])
recording = do
  seen <- newIORef []
  pure (Progress (\event -> atomicModifyIORef' seen (\events -> (event : events, ()))), reverse <$> readIORef seen)

testProgressEvents :: IO Property
testProgressEvents = withGitLibrary $ \library project -> do
  (firstProgress, firstEvents) <- recording
  first <- installWith defaultOptions{optionProgress = firstProgress} project (gitManifest library) emptyLock
  (secondProgress, secondEvents) <- recording
  second <- either (pure . Left) (\o -> synchronise noRegistry defaultOptions{optionProgress = secondProgress} project (gitManifest library) (outcomeLock o)) first
  cold <- firstEvents
  warm <- secondEvents
  let fetches events = length [() | FetchStarted _ <- events]
  pure $ conjoin
    [ counterexample (show (fmap outcomeInstalled second)) (either (const False) (const True) second)
    , counterexample (show cold) (fetches cold === 1)
    , counterexample (show cold) (Resolved 1 `elem` cold)
    , counterexample (show cold) (length [() | CopyFinished _ <- cold] === 1)
    , counterexample (show warm) (fetches warm === 0)
    , counterexample (show warm) (length [() | CacheHit _ <- warm] === 1)
    , counterexample (show warm) (length [() | UpToDate _ <- warm] === 1)
    ]

{-| A new modification time with the same content changes the fingerprint but
    not the digest: the package is kept, and nothing is copied. -}
testTouchedStaysInstalled :: IO Property
testTouchedStaysInstalled = withGitLibrary $ \library project -> do
  first <- installWith defaultOptions project (gitManifest library) emptyLock
  let installed = project </> "deps" </> "shapes-kit" </> "src" </> "ShapesKit" </> "Area.pudu"
  case first of
    Left problem -> pure (counterexample (Text.unpack problem) False)
    Right outcome -> do
      before <- getModificationTime installed
      setModificationTime installed (read "2001-02-03 04:05:06 UTC")
      again <- synchronise noRegistry defaultOptions project (gitManifest library) (outcomeLock outcome)
      after <- getModificationTime installed
      pure $ conjoin
        [ counterexample (show (fmap outcomeInstalled again)) (fmap outcomeInstalled again === Right 0)
        , counterexample "the touched file was left in place" (after /= before)
        ]

testDamagedCacheRefused :: IO Property
testDamagedCacheRefused = withGitLibrary $ \library project -> do
  first <- installWith defaultOptions project (gitManifest library) emptyLock
  case first of
    Left problem -> pure (counterexample (Text.unpack problem) False)
    Right outcome -> do
      cache <- cacheRoot
      keys <- listDirectory (cache </> "checkouts")
      forM_ keys $ \key -> do
        commits <- filter (notElem '.') <$> listDirectory (cache </> "checkouts" </> key)
        forM_ commits $ \commit ->
          TextIO.appendFile (cache </> "checkouts" </> key </> commit </> "src" </> "ShapesKit" </> "Area.pudu") "// injected\n"
      removeDirectoryRecursive (project </> "deps")
      again <- synchronise noRegistry defaultOptions project (gitManifest library) (outcomeLock outcome)
      installed <- doesFileExist (project </> "deps" </> "shapes-kit" </> "src" </> "ShapesKit" </> "Area.pudu")
      pure $ conjoin
        [ counterexample (show (fmap outcomeInstalled again)) (isLeftContaining "pudu.lock records" again)
        , counterexample "the damaged files were not left in deps/" (not installed)
        ]

testConcurrent :: IO Property
testConcurrent = do
  ordered <- forConcurrently 3 [1 .. 50 :: Int] (\n -> pure (n * 2))
  failed <- try (forConcurrently 3 [1 .. 10 :: Int] (\n -> if n == 7 then throwIO (ErrorCall "seven") else evaluate n))
  pure $ conjoin
    [ ordered === map (* 2) [1 .. 50]
    , counterexample "an item's exception reaches the caller" (either (\(ErrorCall m) -> m == "seven") (const False) failed)
    ]
