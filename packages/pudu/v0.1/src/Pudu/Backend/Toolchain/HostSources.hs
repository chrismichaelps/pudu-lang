{-# LANGUAGE TemplateHaskell #-}

{-| @Backend.Toolchain.HostSources — packaged platform translation units
    selected by the generated program. -}
module Pudu.Backend.Toolchain.HostSources (audioSourceMarker, desktopSourceMarker, withHostSourceArguments) where

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

audioSourceMarker :: Text
audioSourceMarker = "/* pudu host source: audio */"

withHostSourceArguments :: Text -> ([String] -> IO a) -> IO a
withHostSourceArguments source compile
  | os /= "darwin" || null sources = compile []
  | otherwise = withSystemTempDirectory "pudu-host" $ \directory -> do
      mapM_ (write directory) sources
      compile
        (["-I", directory] <> ["-fobjc-arc" | desktop]
          <> [directory </> file | (file, _) <- sources, takeExtension file /= ".h"]
          <> concat [["-framework", framework] | framework <- frameworks])
 where
  desktop = desktopSourceMarker `Text.isInfixOf` source
  audio = audioSourceMarker `Text.isInfixOf` source
  sources = (if desktop then desktopSources else []) <> (if audio then audioSources else [])
  frameworks = concat [["AppKit", "CoreGraphics"] | desktop] <> ["AudioToolbox" | audio]
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

audioSources :: [(FilePath, String)]
audioSources = $(do
  let files = ["pudu_audio.h", "pudu_audio.c", "pudu_audio_stream.h", "pudu_audio_stream.c"]
  paths <- traverse (makeRelativeToProject . ("cbits" </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))
