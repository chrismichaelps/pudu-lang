{-| @Pudu.Backend.Toolchain.Android — Android builds through the NDK and the
    SDK's build tools, as ADR-0029 designed: a static library and header for a
    host project, or an application package holding the program linked with
    the embedded host as `libpudu_app.so`.

    Every step runs in a temporary directory beside the output and the result
    is published by rename, so the output path never holds a partial build.
    A missing NDK, platform or build tool is refused by name before any tool
    runs.
-}
module Pudu.Backend.Toolchain.Android
  ( AndroidTools (..)
  , androidAbi
  , androidTools
  , compileAndroidLibrary
  , compileApk
  , packageLinkFlags
  , packageManifest
  ) where

import Control.Exception (finally, mask)
import Control.Monad (filterM, void)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as Char8
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.List (sortOn)
import Data.Maybe (catMaybes, listToMaybe)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Backend.Emit.Entry (embeddedHeader, embeddedHeaderName)
import Pudu.Backend.Runtime.Host.Compress (compressLibraryMarker)
import Pudu.Backend.Toolchain (compilerFlags)
import Pudu.Backend.Toolchain.Assets (stageAssets)
import Pudu.Backend.Toolchain.HostSources (androidHostSources, androidJavaSources, androidManifest)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), problemText, runTool, timeoutSeconds, tryIO)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, findExecutable, getHomeDirectory, listDirectory, removeDirectoryRecursive, renameFile)
import System.Environment (lookupEnv)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.Info (os)
import System.IO.Temp (createTempDirectory)

{-| The oldest Android release a program runs on; it matches the triples. -}
minimumApi :: Int
minimumApi = 24

{-| The ABI directory and the NDK clang triple of an Android target. -}
androidAbi :: Text -> Maybe (String, String)
androidAbi name = case name of
  "android-arm64" -> Just ("arm64-v8a", "aarch64-linux-android" <> show minimumApi)
  "android-x86_64" -> Just ("x86_64", "x86_64-linux-android" <> show minimumApi)
  _ -> Nothing

{-| @Backend.Toolchain.AndroidTools — what an Android build reaches: the NDK's
    clang for the target's triple and its archiver, and for applications the
    platform jar and the build tools. -}
data AndroidTools = AndroidTools
  { toolClang :: !FilePath
  , toolArchiver :: !FilePath
  , toolAbi :: !String
  , toolSdk :: !(Maybe FilePath)
  }

{-| The newest version directory under a directory, by numeric components. -}
newest :: FilePath -> IO (Maybe FilePath)
newest directory = do
  present <- doesDirectoryExist directory
  if not present then pure Nothing else do
    entries <- listDirectory directory
    let number part = read ('0' : filter isDigit (Text.unpack part)) :: Integer
        ordered = sortOn (Down . map number . Text.splitOn "." . Text.pack) entries
    pure ((directory </>) <$> listToMaybe ordered)

{-| The NDK named by `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT`, else the newest
    under the SDK's `ndk` directory; the SDK named by `ANDROID_HOME` or
    `ANDROID_SDK_ROOT`, else the platform's usual place. -}
locate :: IO (Maybe FilePath, Maybe FilePath)
locate = do
  home <- getHomeDirectory
  named <- catMaybes <$> traverse lookupEnv ["ANDROID_HOME", "ANDROID_SDK_ROOT"]
  let usual = [home </> "Library" </> "Android" </> "sdk", home </> "Android" </> "Sdk"]
  sdks <- filterM doesDirectoryExist (filter (not . null) named <> usual)
  ndkNamed <- catMaybes <$> traverse lookupEnv ["ANDROID_NDK_HOME", "ANDROID_NDK_ROOT"]
  ndks <- filterM doesDirectoryExist (filter (not . null) ndkNamed)
  bundled <- traverse (newest . (</> "ndk")) (take 1 sdks)
  pure (listToMaybe (ndks <> catMaybes bundled), listToMaybe sdks)

{-| The tools a target needs, or the first one missing named. -}
androidTools :: Text -> Bool -> IO (Either ToolchainFailure AndroidTools)
androidTools name application = case androidAbi name of
  Nothing -> pure (Left (ToolchainTargetUnbuilt name))
  Just (abi, triple) -> do
    (ndk, sdk) <- locate
    case ndk of
      Nothing -> pure (Left (ToolchainSdkMissing name "ANDROID_NDK_HOME or ANDROID_NDK_ROOT naming an NDK directory, or an NDK under the Android SDK"))
      Just root -> do
        let bin = root </> "toolchains" </> "llvm" </> "prebuilt" </> hostTag </> "bin"
            clang = bin </> (triple <> "-clang")
            archiver = bin </> "llvm-ar"
        found <- traverse doesFileExist [clang, archiver]
        pure $ case (found, sdk) of
          ([True, True], _) | not application || sdk /= Nothing -> Right (AndroidTools clang archiver abi sdk)
          ([True, True], _) -> Left (ToolchainSdkMissing name "ANDROID_HOME naming an Android SDK with a platform and build tools")
          _ -> Left (ToolchainSdkMissing name (Text.pack clang))
 where
  hostTag = (if os == "darwin" then "darwin" else "linux") <> "-x86_64"

{-| The static library and its header, published by rename. -}
compileAndroidLibrary :: AndroidTools -> Text -> [Text] -> FilePath -> IO (Either ToolchainFailure ([Text], Text))
compileAndroidLibrary tools source exports output = staged output $ \directory -> do
  seconds <- timeoutSeconds
  let sourcePath = directory </> "program.c"
      objectPath = directory </> "program.o"
      archivePath = directory </> "program.a"
      headerPath = directory </> embeddedHeaderName
      links = ["-lz" | compressLibraryMarker `Text.isInfixOf` source]
  ByteString.writeFile sourcePath (Encoding.encodeUtf8 source)
  compiled <- invoke (toolClang tools) (compilerFlags <> ["-fPIC", "-c", sourcePath, "-o", objectPath]) seconds
  archived <- either (pure . Left) (\warnings -> fmap (const warnings) <$> invoke (toolArchiver tools) ["rcs", archivePath, objectPath] seconds) compiled
  case archived of
    Left failure -> pure (Left failure)
    Right warnings -> do
      ByteString.writeFile headerPath (Encoding.encodeUtf8 (embeddedHeader links exports))
      renameFile archivePath output
      renameFile headerPath (takeDirectory output </> embeddedHeaderName)
      pure (Right (links, warnings))

{-| An application package: the program linked with the host as the ABI's
    `libpudu_app.so`, the bridge classes dexed, the manifest linked against
    the platform, the library stored uncompressed and page-aligned, and the
    whole signed with a key made for this build. `assets` is the asset
    directory and its checked files, packaged for the asset manager. -}
compileApk :: AndroidTools -> Text -> [Text] -> Text -> FilePath -> Maybe (FilePath, [FilePath]) -> IO (Either ToolchainFailure Text)
compileApk tools source exports label output assets = case toolSdk tools of
  Nothing -> pure (Left (ToolchainSdkMissing "android" "an Android SDK"))
  Just sdk -> do
    testing <- maybe False (not . null) <$> lookupEnv testBuildVariable
    platform <- newest (sdk </> "platforms")
    buildTools <- newest (sdk </> "build-tools")
    javac <- findExecutable "javac"
    jar <- findExecutable "jar"
    keytool <- findExecutable "keytool"
    case (platform, buildTools, javac, jar, keytool) of
      (Just platformDir, Just toolsDir, Just compiler, Just packer, Just keys) ->
        staged output (assemble testing (platformDir </> "android.jar") toolsDir compiler packer keys)
      (Nothing, _, _, _, _) -> missing "an Android platform under the SDK's platforms directory"
      (_, Nothing, _, _, _) -> missing "the Android SDK build tools"
      _ -> missing "a Java development kit (javac, jar and keytool)"
 where
  missing detail = pure (Left (ToolchainSdkMissing "android" detail))
  assemble testing androidJar toolsDir javac jar keytool directory = do
    seconds <- timeoutSeconds
    let library = directory </> "libprogram.a"
        nativeDir = directory </> "lib" </> toolAbi tools
        shared = nativeDir </> "libpudu_app.so"
        javaDir = directory </> "java"
        classes = directory </> "classes"
        classesJar = directory </> "classes.jar"
        manifest = directory </> "AndroidManifest.xml"
        base = directory </> "base.apk"
        aligned = directory </> "aligned.apk"
        signed = directory </> "signed.apk"
        keystore = directory </> "build.jks"
        staging = directory </> "assets"
        carried = maybe [] snd assets
        step = chain seconds
    archived <- compileAndroidLibrary tools source exports library
    case archived of
      Left failure -> pure (Left failure)
      Right (links, libraryWarnings) -> do
        createDirectoryIfMissing True nativeDir
        createDirectoryIfMissing True (javaDir </> "org" </> "pudu")
        createDirectoryIfMissing True classes
        mapM_ (\(file, text) -> Char8.writeFile (directory </> file) (Char8.pack text)) androidHostSources
        mapM_ (\(file, text) -> Char8.writeFile (javaDir </> "org" </> "pudu" </> file) (Char8.pack text)) androidJavaSources
        ByteString.writeFile manifest (Encoding.encodeUtf8 (packageManifest testing label))
        mapM_ (\(from, files) -> stageAssets from files staging) assets
        let javaFiles = [javaDir </> "org" </> "pudu" </> file | (file, _) <- androidJavaSources]
        ran <- step
          [ (toolClang tools, ["-std=c11", "-O2", "-fPIC", "-shared", "-I", directory, directory </> "pudu_android_host.c", library]
              <> map Text.unpack links <> ["-llog", "-landroid", "-o", shared])
          , (javac, ["-source", "11", "-target", "11", "-nowarn", "-cp", androidJar, "-d", classes] <> javaFiles)
          -- Every class javac wrote, nested and synthetic ones included, goes to d8 as one jar.
          , (jar, ["cf", classesJar, "-C", classes, "."])
          , (toolsDir </> "d8", ["--min-api", show minimumApi, "--lib", androidJar, "--output", directory, classesJar])
          , (toolsDir </> "aapt2", ["link", "-o", base, "-I", androidJar, "--manifest", manifest, "--min-sdk-version", show minimumApi]
              <> packageLinkFlags testing <> concat [["-A", staging] | not (null carried)])
          , (jar, ["uf", base, "-C", directory, "classes.dex"])
          , (jar, ["u0f", base, "-C", directory, "lib"])
          , (toolsDir </> "zipalign", ["-P", "16", "-f", "4", base, aligned])
          , (keytool, ["-genkeypair", "-keystore", keystore, "-storepass", "pudu-build", "-keypass", "pudu-build", "-alias", "pudu",
                       "-dname", "CN=Pudu", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000"])
          , (toolsDir </> "apksigner", ["sign", "--ks", keystore, "--ks-pass", "pass:pudu-build", "--out", signed, aligned]) ]
        case ran of
          Left failure -> pure (Left failure)
          Right warnings -> do
            renameFile signed output
            pure (Right (Text.strip (Text.unlines (filter (not . Text.null) [libraryWarnings, warnings]))))

{-| Set to a non-empty value while building, it makes the package a test build. -}
testBuildVariable :: String
testBuildVariable = "PUDU_ANDROID_TEST_BUILD"

{-| The launcher activity is exported, so any application can send it extras.
    Only a test build is debuggable; a release package is not. -}
packageLinkFlags :: Bool -> [String]
packageLinkFlags testing = ["--debug-mode" | testing]

{-| The manifest for a program's label. A test build also carries the marker
    the activity requires before it reads self-test extras. -}
packageManifest :: Bool -> Text -> Text
packageManifest testing label
  | testing = Text.replace "  </application>" (selfTestMarker <> "\n  </application>") named
  | otherwise = named
 where
  named = Text.replace "PUDU_PACKAGE" (packageName label) (Text.replace "PUDU_LABEL" (escaped label) (Text.pack androidManifest))

selfTestMarker :: Text
selfTestMarker = "    <meta-data android:name=\"org.pudu.selftest\" android:value=\"true\" />"

{-| The package's last segment derived from the program's name: ASCII letters
    and digits kept, everything else dropped, a leading digit prefixed. -}
packageName :: Text -> Text
packageName name = case Text.filter (\c -> isAsciiLower c || isAsciiUpper c || isDigit c) name of
  "" -> "app"
  kept | isDigit (Text.head kept) -> "p" <> kept
       | otherwise -> Text.toLower kept

escaped :: Text -> Text
escaped = Text.concatMap $ \c -> case c of
  '&' -> "&amp;"
  '<' -> "&lt;"
  '>' -> "&gt;"
  '"' -> "&quot;"
  '\'' -> "&apos;"
  _ -> Text.singleton c

invoke :: FilePath -> [String] -> Int -> IO (Either ToolchainFailure Text)
invoke executable arguments seconds = do
  ran <- tryIO (runTool executable arguments seconds)
  pure (either (Left . ToolchainInvocation . problemText) id ran)

{-| Each tool in order, stopping at the first failure; the output of every
    step that printed something is kept as warnings. -}
chain :: Int -> [(FilePath, [String])] -> IO (Either ToolchainFailure Text)
chain seconds = go []
 where
  go printed [] = pure (Right (Text.strip (Text.unlines (reverse printed))))
  go printed ((executable, arguments) : rest) = do
    ran <- invoke executable arguments seconds
    case ran of
      Left failure -> pure (Left failure)
      Right said -> go (if Text.null (Text.strip said) then printed else said : printed) rest

{-| A temporary directory beside the output, removed whatever happens. -}
staged :: FilePath -> (FilePath -> IO (Either ToolchainFailure a)) -> IO (Either ToolchainFailure a)
staged output work = mask $ \restore -> do
  created <- tryIO (createTempDirectory (takeDirectory output) (takeFileName output <> ".pudu-tmp"))
  case created of
    Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
    Right directory -> do
      result <- tryIO (restore (work directory)) `finally` void (tryIO (removeDirectoryRecursive directory))
      pure (either (Left . ToolchainPublishFailed . problemText) id result)
