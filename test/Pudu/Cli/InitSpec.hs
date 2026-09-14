{-| @Test.Pudu.Cli.InitSpec — safe canonical project initialization. -}
module Pudu.Cli.InitSpec
  ( initProperties
  ) where

import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Cli.Init
  ( InitError (..)
  , createProject
  , packageNameFrom
  )
import System.Directory
  ( canonicalizePath
  , createDirectory
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  )
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

initProperties :: [(String, IO Property)]
initProperties =
  [ ("project names follow the package identity grammar", pure testPackageNames)
  , ("a fresh project contains every runnable scaffold", testFreshProject)
  , ("existing source and supporting files are preserved", testPreservedFiles)
  , ("an existing manifest refuses every other write", testExistingManifest)
  , ("an incompatible managed path leaves no partial project", testIncompatiblePath)
  , ("reserved project names are refused before creating a directory", testReservedName)
  , ("an initialization lock refuses concurrent scaffolding", testInitializationLock)
  ]

testPackageNames :: Property
testPackageNames = conjoin
  [ packageNameFrom "My Product" === Right "my-product"
  , packageNameFrom "two---parts" === Right "two-parts"
  , packageNameFrom "  V2_report  " === Right "v2-report"
  , counterexample "a doubled letter is part of the name, not a separator run"
      ( map packageNameFrom ["hello", "letter", "book-keeper", "app2", "aabbcc"]
          === map Right ["hello", "letter", "book-keeper", "app2", "aabbcc"]
      )
  , packageNameFrom "my  app" === Right "my-app"
  , packageNameFrom "---" === Left (InvalidPackageName "---")
  , packageNameFrom "CORE" === Left (ReservedPackageName "core")
  ]

testFreshProject :: IO Property
testFreshProject = withSystemTempDirectory "pudu-init" $ \temporaryRoot -> do
  let target = temporaryRoot </> "My Product"
  result <- createProject (Just target)
  root <- canonicalizePath target
  filesPresent <- traverse doesFileExist (managedFiles root)
  manifest <- TextIO.readFile (root </> "pudu.toml")
  entry <- TextIO.readFile (root </> "src" </> "Main.pudu")
  application <- TextIO.readFile (root </> "src" </> "App" </> "Greeting.pudu")
  domain <- TextIO.readFile (root </> "src" </> "Domain" </> "Greeting.pudu")
  suite <- TextIO.readFile (root </> "test" </> "App" </> "GreetingTest.pudu")
  pure $ counterexample (show result) $ conjoin
    [ result === Right root
    , filesPresent === replicate 7 True
    , property ("name = \"my-product\"" `Text.isInfixOf` manifest)
    , property ("import App.Greeting as Greeting" `Text.isInfixOf` entry)
    , property ("import Domain.Greeting as Domain" `Text.isInfixOf` application)
    , property (not ("import App." `Text.isInfixOf` domain))
    , property ("Test.report" `Text.isInfixOf` suite)
    ]

testPreservedFiles :: IO Property
testPreservedFiles = withSystemTempDirectory "pudu-init" $ \target -> do
  let entry = target </> "src" </> "Main.pudu"
      application = target </> "src" </> "App" </> "Greeting.pudu"
      domain = target </> "src" </> "Domain" </> "Greeting.pudu"
      suite = target </> "test" </> "App" </> "GreetingTest.pudu"
      readme = target </> "README.md"
      ignore = target </> ".gitignore"
      originals =
        [ (entry, "module Existing\n")
        , (application, "module App.Greeting\n")
        , (domain, "module Domain.Greeting\n")
        , (suite, "module ExistingTest\n")
        , (readme, "keep this readme\n")
        , (ignore, "keep-this\n")
        ]
  createDirectoryIfMissing True (target </> "src")
  createDirectoryIfMissing True (target </> "src" </> "App")
  createDirectoryIfMissing True (target </> "src" </> "Domain")
  createDirectoryIfMissing True (target </> "test" </> "App")
  traverse_ (uncurry TextIO.writeFile) originals
  result <- createProject (Just target)
  root <- canonicalizePath target
  after <- traverse (TextIO.readFile . fst) originals
  manifest <- doesFileExist (target </> "pudu.toml")
  pure $ conjoin
    [ result === Right root
    , after === map snd originals
    , manifest === True
    ]

testExistingManifest :: IO Property
testExistingManifest = withSystemTempDirectory "pudu-init" $ \target -> do
  root <- canonicalizePath target
  let manifest = root </> "pudu.toml"
  TextIO.writeFile manifest "owned = true\n"
  result <- createProject (Just target)
  contents <- TextIO.readFile manifest
  sourceCreated <- doesDirectoryExist (target </> "src")
  pure $ conjoin
    [ result === Left (ManifestAlreadyExists manifest)
    , contents === "owned = true\n"
    , sourceCreated === False
    ]

testIncompatiblePath :: IO Property
testIncompatiblePath = withSystemTempDirectory "pudu-init" $ \target -> do
  root <- canonicalizePath target
  let readme = root </> "README.md"
  createDirectory readme
  result <- createProject (Just target)
  manifest <- doesFileExist (target </> "pudu.toml")
  sourceCreated <- doesDirectoryExist (target </> "src")
  pure $ conjoin
    [ result === Left (RegularFileRequired readme)
    , manifest === False
    , sourceCreated === False
    ]

testReservedName :: IO Property
testReservedName = withSystemTempDirectory "pudu-init" $ \temporaryRoot -> do
  let target = temporaryRoot </> "Std"
  result <- createProject (Just target)
  created <- doesDirectoryExist target
  pure $ conjoin
    [ result === Left (ReservedPackageName "std")
    , created === False
    ]

testInitializationLock :: IO Property
testInitializationLock = withSystemTempDirectory "pudu-init" $ \target -> do
  root <- canonicalizePath target
  let lock = root </> ".pudu-init"
  createDirectory lock
  result <- createProject (Just target)
  manifest <- doesFileExist (target </> "pudu.toml")
  pure $ conjoin
    [ result === Left (InitializationInProgress lock)
    , manifest === False
    ]

managedFiles :: FilePath -> [FilePath]
managedFiles root =
  [ root </> "pudu.toml"
  , root </> "src" </> "Main.pudu"
  , root </> "src" </> "App" </> "Greeting.pudu"
  , root </> "src" </> "Domain" </> "Greeting.pudu"
  , root </> "test" </> "App" </> "GreetingTest.pudu"
  , root </> ".gitignore"
  , root </> "README.md"
  ]

traverse_ :: (a -> IO b) -> [a] -> IO ()
traverse_ action values = case values of
  [] -> pure ()
  value : rest -> action value >> traverse_ action rest
