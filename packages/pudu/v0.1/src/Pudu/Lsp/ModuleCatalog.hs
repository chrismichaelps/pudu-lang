{-| @Program.Lsp.ModuleCatalog — the modules an import could name -}
module Pudu.Lsp.ModuleCatalog
  ( moduleCatalog
  , modulesUnder
  ) where

import Control.Exception (IOException, try)
import Data.Char (isAlphaNum, isAsciiUpper)
import Data.List (sort)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Library (newResolutionContext, resolutionSearchRoots)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>), splitExtension)

{-| Every module an import in a program under `sourceRoot` can reach: the
    program's own, its manifest dependencies', and the standard library's.

    The roots are the ones the compiler searches, asked of the same resolution
    context, so an offered module is one an import of it would find. A program
    module shadows a standard one of the same name, as it does when compiling. -}
moduleCatalog :: FilePath -> IO [Text]
moduleCatalog sourceRoot = do
  context <- newResolutionContext sourceRoot
  let projectRoots = resolutionSearchRoots context (ModuleName (NonEmpty.singleton "Main"))
      standardRoots =
        drop (length projectRoots) (resolutionSearchRoots context (ModuleName (NonEmpty.singleton "Std")))
  own <- mapM (modulesUnder (const True)) projectRoots
  standard <- mapM (modulesUnder (== "Std")) standardRoots
  pure (Set.toAscList (Set.fromList (concat own <> concat standard)))

{-| The modules whose files lie under `root`, named by their path from it:
    `root/Std/Io.pudu` is `Std.Io`.

    Only directories whose names can be module segments are entered, because a
    module path is made of those alone; a source root that is also a repository
    root therefore never walks its build output or dependencies. The walk still
    stops after a fixed number of directories, so an editor opened on a very
    large tree answers promptly with what it found. -}
modulesUnder :: (Text -> Bool) -> FilePath -> IO [Text]
modulesUnder admitsFirst root = sort . fst <$> walk directoryBudget [] [([], root)]
 where
  walk budget found pending = case pending of
    [] -> pure (found, budget)
    (segments, directory) : rest
      | budget <= (0 :: Int) -> pure (found, budget)
      | otherwise -> do
          listed <- try (listDirectory directory) :: IO (Either IOException [FilePath])
          case listed of
            Left _ -> walk (budget - 1) found rest
            Right entries -> do
              entryKinds <- mapM (classify segments directory) (sort entries)
              let files = [name | Just (Left name) <- entryKinds]
                  directories = [child | Just (Right child) <- entryKinds]
              walk (budget - 1) (files <> found) (rest <> directories)
  classify segments directory entry
    | not (segment entry) && snd (splitExtension entry) /= ".pudu" = pure Nothing
    | otherwise = do
        let path = directory </> entry
        isDirectory <- doesDirectoryExist path
        pure (classified segments path entry isDirectory)
  classified segments path entry isDirectory =
    case splitExtension entry of
      _ | isDirectory, segment entry, admitted (segments <> [Text.pack entry]) ->
            Just (Right (segments <> [Text.pack entry], path))
      (stem, ".pudu") | not isDirectory, segment stem, admitted (segments <> [Text.pack stem]) ->
            Just (Left (Text.intercalate "." (segments <> [Text.pack stem])))
      _ -> Nothing
  admitted names = case names of
    first : _ -> admitsFirst first
    [] -> False
  segment name = case name of
    first : rest -> isAsciiUpper first && all (\scalar -> isAlphaNum scalar || scalar == '_') rest
    [] -> False

{-| How many directories one catalog reads at most. The standard library is a
    few dozen; a program with more modules than this is still offered the ones
    nearest its root. -}
directoryBudget :: Int
directoryBudget = 2000
