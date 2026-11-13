{-# LANGUAGE TemplateHaskell #-}

{-| @Backend.Toolchain.HostSources — packaged platform translation units
    selected by the generated program. -}
module Pudu.Backend.Toolchain.HostSources (desktopSourceMarker, withHostSourceArguments) where

import qualified Data.ByteString.Char8 as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import Language.Haskell.TH (runIO)
import Language.Haskell.TH.Syntax (addDependentFile, lift, makeRelativeToProject)
import System.FilePath ((</>), takeExtension)
import System.Info (os)
import System.IO.Temp (withSystemTempDirectory)

desktopSourceMarker :: Text
desktopSourceMarker = "/* pudu host source: desktop */"

withHostSourceArguments :: Text -> ([String] -> IO a) -> IO a
withHostSourceArguments source compile
  | os == "darwin" && desktopSourceMarker `Text.isInfixOf` source =
      withSystemTempDirectory "pudu-host" $ \directory -> do
        mapM_ (write directory) desktopSources
        compile
          (["-fobjc-arc"]
            <> [directory </> file | (file, _) <- desktopSources, takeExtension file == ".m"]
            <> ["-framework", "AppKit", "-framework", "CoreGraphics"])
  | otherwise = compile []
 where
  write directory (file, contents) =
    ByteString.writeFile (directory </> file) (ByteString.pack contents)

desktopSources :: [(FilePath, String)]
desktopSources = $(do
  let files =
        [ "pudu_desktop.h", "pudu_desktop_host.h", "pudu_desktop.m"
        , "pudu_desktop_access.m", "pudu_desktop_menu.m", "pudu_desktop_window.m"
        ]
  paths <- traverse (makeRelativeToProject . ("cbits" </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))
