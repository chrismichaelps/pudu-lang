{-| @Backend.Toolchain.Assets — files an application carries beside its code.

    An application's assets are the files under the `assets` directory beside
    its entry module. They are packaged as they are, under the same relative
    names, so a program names an asset the same way on every platform: iOS
    finds them in the bundle's `assets` directory and Android through its
    asset manager. Names are checked before anything is packaged; a name a
    platform could read differently is refused rather than renamed. -}
module Pudu.Backend.Toolchain.Assets
  ( assetDirectory
  , assetFiles
  , stageAssets
  ) where

import Control.Monad (forM, forM_)
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  , pathIsSymbolicLink
  )
import System.FilePath (makeRelative, splitDirectories, takeDirectory, (</>))

{-| The asset directory of the program whose entry module is at `entry`, when
    there is one. -}
assetDirectory :: FilePath -> IO (Maybe FilePath)
assetDirectory entry = do
  let directory = takeDirectory entry </> "assets"
  present <- doesDirectoryExist directory
  pure (if present then Just directory else Nothing)

{-| Every asset under `directory` as a relative path, in name order, or why
    one cannot be packaged: a name no platform reads the same way, or a
    symbolic link, refused so nothing outside the directory is packaged.
    Anything that is neither a file nor a directory is not an asset. -}
assetFiles :: FilePath -> IO (Either Text [FilePath])
assetFiles directory = do
  found <- walk directory
  pure $ do
    files <- found
    let relative = map (makeRelative directory) files
    mapM checked (sort relative)
 where
  walk path = do
    entries <- listDirectory path
    nested <- forM (sort entries) $ \entry -> do
      let child = path </> entry
      link <- pathIsSymbolicLink child
      folder <- doesDirectoryExist child
      if link
        then pure (Left (Text.pack ("a symbolic link, " <> makeRelative directory child)))
        else if folder then walk child else (\regular -> Right [child | regular]) <$> doesFileExist child
    pure (concat <$> sequence nested)

-- A relative asset name every platform reads the same way: segments of ASCII
-- letters, digits, dots, dashes and underscores, none hidden or empty.
checked :: FilePath -> Either Text FilePath
checked name
  | all portable (splitDirectories name) = Right name
  | otherwise = Left (Text.pack ("a name other platforms may read differently, " <> name))
 where
  portable segment = not (null segment) && take 1 segment /= "." && all allowed segment
  allowed c = isAsciiLower c || isAsciiUpper c || isDigit c || c `elem` ("._-" :: String)

{-| Copies the assets `files` (relative to `directory`) under `destination`,
    keeping their relative names. -}
stageAssets :: FilePath -> [FilePath] -> FilePath -> IO ()
stageAssets directory files destination =
  forM_ files $ \file -> do
    let target = destination </> file
    createDirectoryIfMissing True (takeDirectory target)
    copyFile (directory </> file) target
