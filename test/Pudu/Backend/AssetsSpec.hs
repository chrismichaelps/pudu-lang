{-| @Test.Backend.AssetsSpec — which files an application carries as assets,
    and the names and links refused before anything is packaged. -}
module Pudu.Backend.AssetsSpec (assetProperties) where

import qualified Data.Text as Text
import Pudu.Backend.Toolchain.Assets (assetDirectory, assetFiles, stageAssets)
import System.Directory (createDirectoryIfMissing, createFileLink, doesFileExist)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, once, (===))

assetProperties :: [(String, IO Property)]
assetProperties =
  [ ("assets are listed by relative name and staged under the same names", once <$> listedAndStaged)
  , ("assets with names other platforms may read differently are refused", once <$> refusedNames)
  , ("a symbolic link among the assets is refused", once <$> refusedLink)
  , ("a program without an assets directory carries no assets", once <$> absent)
  ]

listedAndStaged :: IO Property
listedAndStaged = withSystemTempDirectory "pudu-assets" $ \root -> do
  let assets = root </> "assets"
  createDirectoryIfMissing True (assets </> "icons")
  writeFile (assets </> "b.png") "b"
  writeFile (assets </> "icons" </> "a-1_x.png") "a"
  found <- assetDirectory (root </> "Main.pudu")
  listed <- assetFiles assets
  staged <- case listed of
    Right files -> stageAssets assets files (root </> "out") >> doesFileExist (root </> "out" </> "icons" </> "a-1_x.png")
    Left _ -> pure False
  pure $ conjoin
    [ found === Just assets
    , listed === Right ["b.png", "icons" </> "a-1_x.png"]
    , counterexample "the nested asset was not staged under its relative name" staged
    ]

refusedNames :: IO Property
refusedNames = conjoin <$> mapM refused ["café.png", ".hidden", "with space.png"]
 where
  refused name = withSystemTempDirectory "pudu-assets" $ \root -> do
    writeFile (root </> name) "x"
    listed <- assetFiles root
    pure $ case listed of
      Left reason -> counterexample (Text.unpack reason) (Text.pack name `Text.isInfixOf` reason)
      Right files -> counterexample ("accepted " <> show files) False

refusedLink :: IO Property
refusedLink = withSystemTempDirectory "pudu-assets" $ \root -> do
  let assets = root </> "assets"
  createDirectoryIfMissing True assets
  writeFile (root </> "outside.png") "x"
  createFileLink (root </> "outside.png") (assets </> "linked.png")
  listed <- assetFiles assets
  pure $ case listed of
    Left reason -> counterexample (Text.unpack reason) ("symbolic link" `Text.isInfixOf` reason)
    Right files -> counterexample ("accepted " <> show files) False

absent :: IO Property
absent = withSystemTempDirectory "pudu-assets" $ \root -> (=== Nothing) <$> assetDirectory (root </> "Main.pudu")
