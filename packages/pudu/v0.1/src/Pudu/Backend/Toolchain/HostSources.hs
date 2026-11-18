{-# LANGUAGE TemplateHaskell #-}

{-| @Backend.Toolchain.HostSources — packaged platform translation units
    selected by the generated program. -}
module Pudu.Backend.Toolchain.HostSources
  ( androidHostSources, androidJavaSources, androidManifest, audioSourceMarker, desktopSourceMarker, iosHostSources
  , loaderSourceLines, sqliteSourceMarker, withHostSourceArguments ) where

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

sqliteSourceMarker :: Text
sqliteSourceMarker = "/* pudu host source: sqlite */"

withHostSourceArguments :: Text -> ([String] -> IO a) -> IO a
withHostSourceArguments source compile
  | null sources = compile []
  | otherwise = withSystemTempDirectory "pudu-host" $ \directory -> do
      mapM_ (write directory) sources
      compile
        (["-I", directory] <> ["-fobjc-arc" | apple, desktop]
          <> [directory </> file | (file, _) <- sources, takeExtension file /= ".h"]
          <> concat [["-framework", framework] | framework <- frameworks])
 where
  desktop = desktopSourceMarker `Text.isInfixOf` source
  audio = audioSourceMarker `Text.isInfixOf` source
  apple = os == "darwin"
  sqlite = sqliteSourceMarker `Text.isInfixOf` source
  -- The desktop and audio hosts exist only on Apple platforms; the SQLite
  -- binding is portable C.
  sources = (if apple && desktop then desktopSources else []) <> (if apple && audio then audioSources else [])
    <> (if sqlite then sqliteSources else [])
  frameworks = concat [["AppKit", "CoreGraphics"] | apple, desktop] <> ["AudioToolbox" | apple, audio]
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

{-| The SQLite binding the interpreter links, compiled into a native program
    whose foreign block names it. -}
sqliteSources :: [(FilePath, String)]
sqliteSources = $(do
  let files = ["pudu_sqlite.c", "pudu_loader.h"]
  paths <- traverse (makeRelativeToProject . ("cbits" </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))

loaderSourceLines :: [Text]
loaderSourceLines = map Text.pack $(do
  path <- makeRelativeToProject ("cbits" </> "pudu_loader.h")
  addDependentFile path
  contents <- runIO (ByteString.readFile path)
  lift (lines (ByteString.unpack contents)))

{-| The iOS host and its private header, staged only for app builds. -}
iosHostSources :: [(FilePath, String)]
iosHostSources = $(do
  let files = ["pudu_ios_host.m", "pudu_ios_layout.h", "pudu_ios_theme.h", "pudu_ios_events.h", "pudu_ios_list.h", "pudu_ios_controls.h", "pudu_ios_material.h", "pudu_ios_stream.h", "pudu_ios_gesture.h", "pudu_ios_feedback.h", "pudu_ios_access.h", "pudu_ios_scene.h", "pudu_ios_motion.h", "pudu_ios_navigation.h", "pudu_ios_capability_test.h"]
  paths <- traverse (makeRelativeToProject . ("cbits" </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))

{-| The Android host: one translation unit and its private headers, staged
    only for application builds. -}
androidHostSources :: [(FilePath, String)]
androidHostSources = $(do
  let files = [ "pudu_android_host.c", "pudu_android_jni.h", "pudu_android_events.h", "pudu_android_theme.h"
              , "pudu_android_controls.h", "pudu_android_values.h", "pudu_android_list.h", "pudu_android_kinds.h"
              , "pudu_android_nodes.h", "pudu_android_capabilities.h", "pudu_android_java.h" ]
  paths <- traverse (makeRelativeToProject . ("cbits" </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))

{-| The Java side of the Android host, by file name under `org/pudu`. -}
androidJavaSources :: [(FilePath, String)]
androidJavaSources = $(do
  let files = [ "PuduActivity.java", "PuduBridge.java", "PuduListener.java", "PuduList.java", "PuduMenus.java"
              , "PuduAccess.java", "PuduGestures.java", "PuduMoment.java", "PuduPages.java", "PuduWell.java", "PuduTests.java" ]
  paths <- traverse (makeRelativeToProject . (("android" </> "org" </> "pudu") </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))

{-| The application manifest; the build fills in the package and label. -}
androidManifest :: String
androidManifest = $(do
  path <- makeRelativeToProject ("android" </> "AndroidManifest.xml")
  addDependentFile path
  contents <- runIO (ByteString.readFile path)
  lift (ByteString.unpack contents))

audioSources :: [(FilePath, String)]
audioSources = $(do
  let files = ["pudu_audio.h", "pudu_audio.c", "pudu_audio_stream.h", "pudu_audio_stream.c"]
  paths <- traverse (makeRelativeToProject . ("cbits" </>)) files
  mapM_ addDependentFile paths
  contents <- runIO (traverse ByteString.readFile paths)
  lift (zip files (map ByteString.unpack contents)))
