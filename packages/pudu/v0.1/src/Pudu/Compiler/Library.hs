{-| @Program.Compiler.Library.Module — locates the shipped standard library -}
module Pudu.Compiler.Library
  ( ResolutionContext
  , ResolutionMetrics (..)
  , newResolutionContext
  , resolutionDiagnostics
  , resolutionSearchRoots
  , resolutionTriedRoots
  , resolutionMetrics
  , isStandardModule
  , candidateRoots
  , libraryRoots
  , searchRoots
  , triedRoots
  ) where

import Control.Exception (IOException, try)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (catMaybes)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Version (versionBranch)
import qualified Paths_pudu as Package
import Pudu.Compiler.Manifest
  ( ManifestMetrics (..)
  , manifestSnapshotDiagnostics
  , manifestSnapshotMetrics
  , manifestSnapshotPackageRoots
  , manifestSnapshotSearchRoots
  , readManifestSnapshot
  )
import Pudu.Diagnostic (Diagnostic)
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

{-| Filesystem work performed while constructing one resolution context. -}
data ResolutionMetrics = ResolutionMetrics
  { resolutionManifestAncestorChecks :: !Int
  , resolutionManifestReads :: !Int
  , resolutionExecutableAncestors :: !Int
  , resolutionProjectRootProbes :: !Int
  , resolutionLibraryRootProbes :: !Int
  }
  deriving stock (Eq, Show)

{-| Immutable roots and diagnostics shared by one program discovery walk. -}
data ResolutionContext = ResolutionContext
  { contextSourceRoot :: !FilePath
  , contextProjectRoots :: ![FilePath]
  , contextPackageRoots :: ![FilePath]
  , contextLibraryRoots :: ![FilePath]
  , contextAttemptedLibraryRoots :: ![Text]
  , contextDiagnostics :: ![Diagnostic]
  , contextMetrics :: !ResolutionMetrics
  }

{-| Discover every root once for one compiler invocation. -}
newResolutionContext :: FilePath -> IO ResolutionContext
newResolutionContext sourceRoot = do
  manifest <- readManifestSnapshot sourceRoot
  library <- discoverLibrary
  foundLibraryRoots <- existing (discoveryCandidates library)
  let manifestMetrics = manifestSnapshotMetrics manifest
  pure
    ResolutionContext
      { contextSourceRoot = sourceRoot
      , contextProjectRoots = manifestSnapshotSearchRoots manifest
      , contextPackageRoots = manifestSnapshotPackageRoots manifest
      , contextLibraryRoots = foundLibraryRoots
      , contextAttemptedLibraryRoots = discoveryAttempted library
      , contextDiagnostics = manifestSnapshotDiagnostics manifest
      , contextMetrics =
          ResolutionMetrics
            { resolutionManifestAncestorChecks = manifestAncestorChecks manifestMetrics
            , resolutionManifestReads = manifestReadCount manifestMetrics
            , resolutionExecutableAncestors = discoveryExecutableAncestors library
            , resolutionProjectRootProbes = manifestDependencyProbes manifestMetrics
            , resolutionLibraryRootProbes = length (discoveryCandidates library)
            }
      }

resolutionDiagnostics :: ResolutionContext -> [Diagnostic]
resolutionDiagnostics = contextDiagnostics

resolutionMetrics :: ResolutionContext -> ResolutionMetrics
resolutionMetrics = contextMetrics

{-| Ordered roots for a requested module, with no filesystem work.

    Installed packages come after the project's own roots, and are never
    searched for a standard module: the project may shadow one deliberately, in
    its own tree, and a dependency may not. -}
resolutionSearchRoots :: ResolutionContext -> ModuleName -> [FilePath]
resolutionSearchRoots context name
  | isStandardModule name = projectRoots <> contextLibraryRoots context
  | otherwise = projectRoots <> contextPackageRoots context
 where
  projectRoots = contextSourceRoot context : contextProjectRoots context

{-| Human-readable roots for a failed lookup, with no filesystem work. -}
resolutionTriedRoots :: ResolutionContext -> ModuleName -> [Text]
resolutionTriedRoots context name
  | not (isStandardModule name) = own <> map shown (contextPackageRoots context)
  | not (null (contextLibraryRoots context)) = own <> map shown (contextLibraryRoots context)
  | otherwise = own <> contextAttemptedLibraryRoots context
 where
  own = map shown (contextSourceRoot context : contextProjectRoots context)

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
candidateRoots = discoveryCandidates <$> discoverLibrary

data LibraryDiscovery = LibraryDiscovery
  { discoveryCandidates :: ![FilePath]
  , discoveryAttempted :: ![Text]
  , discoveryExecutableAncestors :: !Int
  }

discoverLibrary :: IO LibraryDiscovery
discoverLibrary = do
  configured <- lookupEnv "PUDU_LIB"
  executable <- try getExecutablePath :: IO (Either IOException FilePath)
  working <- try getCurrentDirectory :: IO (Either IOException FilePath)
  packaged <- Package.getDataFileName "lib"
  let installed = case executable of
        Left _ -> Nothing
        Right path -> Just (takeDirectory (takeDirectory path) </> "lib" </> "pudu")
      executableDirectories = case executable of
        Left _ -> []
        Right path -> ancestors (takeDirectory path)
      beside = concatMap rootShapes executableDirectories
      development = case working of
        Left _ -> Nothing
        Right path -> Just (developmentPath path)
      candidates = distinct
        (catMaybes [configured, installed] <> beside <> [packaged] <> catMaybes [development])
      walked = case executable of
        Left _ -> []
        Right path ->
          [ Text.pack (takeDirectory path)
              <> " and every directory above it (lib/pudu, or a checkout's packages/pudu/"
              <> versionDirectory
              <> "/lib)"
          ]
      attempted = map shown (catMaybes [configured, installed]) <> walked <> [shown packaged]
  pure (LibraryDiscovery candidates attempted (length executableDirectories))

rootShapes :: FilePath -> [FilePath]
rootShapes directory =
  (directory </> "lib" </> "pudu")
    : case versionBranch Package.version of
      major : minor : _ ->
        [ directory </> "packages" </> "pudu"
            </> ("v" <> show major <> "." <> show minor)
            </> "lib"
        ]
      _ -> []

developmentPath :: FilePath -> FilePath
developmentPath path = case versionBranch Package.version of
  major : minor : _ -> path </> "packages" </> "pudu"
    </> ("v" <> show major <> "." <> show minor) </> "lib"
  _ -> path </> "lib"

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
  context <- newResolutionContext sourceRoot
  pure (resolutionSearchRoots context name)

{-| Where a module that was not found was looked for, written for a reader.

    When the library is present the places searched are the answer, because the
    module is most likely misspelled. When no library location exists at all,
    the search alone names nothing, and the empty locations are the whole
    explanation: those are named instead, with the walk up from the executable
    described once rather than spelled out for every directory above it. -}
triedRoots :: FilePath -> ModuleName -> IO [Text]
triedRoots sourceRoot name = do
  context <- newResolutionContext sourceRoot
  pure (resolutionTriedRoots context name)

{-| The directories among these that are there, each once and in the order
    they were offered.

    Two of the ways a library is looked for reach the same directory on a
    machine where the compiler runs from its own checkout, and a repeated root
    is a directory read twice for every module that is not in it — and a
    diagnostic that names it twice, which reads as a fault in the compiler
    rather than a missing file. -}
existing :: [FilePath] -> IO [FilePath]
existing paths = catMaybes <$> mapM keepDirectory (distinct paths)
 where
  keepDirectory path = do
    present <- doesDirectoryExist path
    pure (if present then Just path else Nothing)

distinct :: [FilePath] -> [FilePath]
distinct = go Set.empty
 where
  go _ [] = []
  go seen (path : rest)
    | Set.member path seen = go seen rest
    | otherwise = path : go (Set.insert path seen) rest

shown :: FilePath -> Text
shown root = if null root then "." else Text.pack root

versionDirectory :: Text
versionDirectory = case versionBranch Package.version of
  major : minor : _ -> Text.pack ("v" <> show major <> "." <> show minor)
  _ -> "v<version>"
