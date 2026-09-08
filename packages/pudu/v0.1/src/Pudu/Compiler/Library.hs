{-| @Program.Compiler.Library.Module — locates the shipped standard library -}
module Pudu.Compiler.Library
  ( isStandardModule
  , libraryRoots
  , searchRoots
  ) where

import Control.Exception (IOException, try)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Version (versionBranch)
import qualified Paths_pudu as Package
import Pudu.Compiler.Manifest (projectSearchRoots)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import System.Directory (doesDirectoryExist, getCurrentDirectory)
import System.Environment (getExecutablePath, lookupEnv)
import System.FilePath (takeDirectory, (</>))

{-| Whether a module belongs to the shipped standard library.

    Membership is by namespace, not by a list of module names: `Std.Http.Server`
    must be a standard module the day it is written, without this file learning
    about it. -}
isStandardModule :: ModuleName -> Bool
isStandardModule (ModuleName segments) = NonEmpty.head segments == standardRoot

standardRoot :: Text
standardRoot = "Std"

{-| Where a standard module may be found, in the order it is looked for.

    A program's own source root is searched first by `searchRoots`, so a program
    may shadow a standard module deliberately and visibly — the shadowing file
    is in the program's own tree, where a reader will find it. Everything here
    is a fallback behind that.

    There is no network step, no cache, and no version resolution: a Pudu
    program's dependencies are its own files plus the compiler it is built with,
    and that is the whole answer. -}
libraryRoots :: IO [FilePath]
libraryRoots = do
  configured <- lookupEnv "PUDU_LIB"
  installed <- installedRoot
  development <- developmentRoot
  packaged <- Package.getDataFileName "lib"
  existing (catMaybes [configured, installed, Just packaged, development])

{-| The roots to search for one module: the program's own source root first,
    then whatever its manifest declares as a dependency, then the library's —
    and the library only when the module is a standard one.

    A non-standard module is never looked for in the library. A typo in an
    ordinary import must be reported as a missing module in the program, not
    resolved against a library the author did not mean. It *is* looked for in
    the project's declared dependencies, because those are the project's own
    code by its own statement. -}
searchRoots :: FilePath -> ModuleName -> IO [FilePath]
searchRoots sourceRoot name = do
  declared <- dependencyRoots sourceRoot
  if isStandardModule name
    then ((sourceRoot : declared) <>) <$> libraryRoots
    else pure (sourceRoot : declared)

{-| The directories this project's manifest says its code also lives in.

    Searched after the project's own root and before the library, so a project
    may shadow a dependency's module the same way it may shadow a standard one:
    visibly, with a file in its own tree. -}
dependencyRoots :: FilePath -> IO [FilePath]
dependencyRoots = projectSearchRoots

{-| The library that ships beside the compiler. -}
installedRoot :: IO (Maybe FilePath)
installedRoot = do
  executable <- try getExecutablePath :: IO (Either IOException FilePath)
  pure $ case executable of
    Left _ -> Nothing
    Right path -> Just (takeDirectory (takeDirectory path) </> "lib" </> "pudu")

{-| The library in a checkout, so the compiler under development uses the
    standard library under development. Without it every change to `Std` would
    need an install step before it could be tested. -}
developmentRoot :: IO (Maybe FilePath)
developmentRoot = do
  working <- try getCurrentDirectory :: IO (Either IOException FilePath)
  pure $ case working of
    Left _ -> Nothing
    Right path -> case versionBranch Package.version of
      major : minor : _ -> Just (path </> "packages" </> "pudu"
        </> ("v" <> show major <> "." <> show minor) </> "lib")
      _ -> Just (path </> "lib")

existing :: [FilePath] -> IO [FilePath]
existing = fmap catMaybes . mapM keepDirectory
 where
  keepDirectory path = do
    present <- doesDirectoryExist path
    pure (if present then Just path else Nothing)
