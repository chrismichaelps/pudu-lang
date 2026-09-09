{-| @Program.Compiler.Library.Module — locates the shipped standard library -}
module Pudu.Compiler.Library
  ( isStandardModule
  , candidateRoots
  , libraryRoots
  , searchRoots
  ) where

import Control.Exception (IOException, try)
import qualified Data.Set as Set
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
libraryRoots = existing =<< candidateRoots

{-| Every place the library might be, in the order it is looked for.

    Kept apart from the search so a failure can say what was tried. A reader
    told only that a standard module could not be read has to guess at an
    installation they did not perform; told the four paths that were looked
    in, they can see which one their library is actually at. -}
candidateRoots :: IO [FilePath]
candidateRoots = do
  configured <- lookupEnv "PUDU_LIB"
  installed <- installedRoot
  beside <- besideExecutable
  development <- developmentRoot
  packaged <- Package.getDataFileName "lib"
  pure (catMaybes [configured, installed] <> beside <> [packaged] <> catMaybes [development])

{-| The library found by walking up from the executable itself.

    Where the compiler is answers where its library is; where the person
    running it happens to be standing does not. Looking upward from the
    executable is what makes a compiler work the same from any directory,
    which is the difference between a language a person can use on their own
    project and one that only works from the directory it was built in.

    Both shapes are looked for at every level: `lib/pudu` beside a `bin`, which
    is how an installed one is laid out, and the versioned path inside a
    checkout, which is how one under development is. -}
besideExecutable :: IO [FilePath]
besideExecutable = do
  executable <- try getExecutablePath :: IO (Either IOException FilePath)
  pure $ case executable of
    Left _ -> []
    Right path -> concatMap shapes (ancestors (takeDirectory path))
 where
  shapes directory =
    (directory </> "lib" </> "pudu")
      : case versionBranch Package.version of
        major : minor : _ ->
          [ directory </> "packages" </> "pudu"
              </> ("v" <> show major <> "." <> show minor)
              </> "lib"
          ]
        _ -> []

{-| A directory and the directories above it, nearest first, stopping at the
    root rather than walking forever. -}
ancestors :: FilePath -> [FilePath]
ancestors directory =
  let above = takeDirectory directory
   in directory : if above == directory then [] else ancestors above

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

{-| The directories among these that are there, each once and in the order
    they were offered.

    Two of the ways a library is looked for reach the same directory on a
    machine where the compiler runs from its own checkout, and a repeated root
    is a directory read twice for every module that is not in it — and a
    diagnostic that names it twice, which reads as a fault in the compiler
    rather than a missing file. -}
existing :: [FilePath] -> IO [FilePath]
existing paths = distinct <$> (catMaybes <$> mapM keepDirectory paths)
 where
  keepDirectory path = do
    present <- doesDirectoryExist path
    pure (if present then Just path else Nothing)
  distinct = go Set.empty
   where
    go _ [] = []
    go seen (path : rest)
      | Set.member path seen = go seen rest
      | otherwise = path : go (Set.insert path seen) rest
