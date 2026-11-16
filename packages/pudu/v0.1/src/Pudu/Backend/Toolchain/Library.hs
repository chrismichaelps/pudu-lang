{-| @Pudu.Backend.Toolchain.Library — a static library and its header for a
    mobile target.

    The platform SDK's own compiler compiles the unit to an object for the
    target's triple and system root, and its archiver writes the library. The
    archive is published by rename, then the header beside it, so a header a
    reader finds always describes the library next to it.
-}
module Pudu.Backend.Toolchain.Library
  ( LibraryProducts (..)
  , LibraryRequest (..)
  , appleTools
  , compileLibrary
  , invoke
  ) where

import Control.Exception (finally, mask)
import Control.Monad (void)
import qualified Data.ByteString as ByteString
import Data.List (sortOn)
import Data.Maybe (catMaybes)
import Data.Ord (Down (..))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Time.Clock (getCurrentTime, utctDay)
import Pudu.Backend.Emit.Entry (embeddedHeader, embeddedHeaderName)
import Pudu.Backend.Runtime.Host.Compress (compressLibraryMarker)
import Pudu.Backend.Runtime.Host.Tls (tlsLibraryMarker)
import Pudu.Backend.Runtime.Host.Foreign (foreignLoaderMarker)
import Pudu.Backend.Ledger (Finding, Purpose (..), appleLedger, assess, isRefusal)
import Pudu.Backend.Target (AppleSdk (..), NativeTarget (..), TargetPlatform (..))
import Pudu.Backend.Toolchain (compilerFlags)
import Pudu.Backend.Toolchain.Probe (appleInstalled, findXcrun)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), problemText, runTool, runToolOutput, timeoutSeconds, tryIO)
import System.Directory (doesDirectoryExist, doesFileExist, getHomeDirectory, listDirectory, removeDirectoryRecursive, renameFile)
import System.Environment (lookupEnv)
import System.FilePath (equalFilePath, takeDirectory, takeFileName, (</>))
import System.Info (os)
import System.IO.Temp (createTempDirectory)
import Text.Read (readMaybe)

data LibraryRequest = LibraryRequest
  { librarySource :: !Text
  , libraryOutput :: !FilePath
  , libraryTarget :: !NativeTarget
  {-| The prototypes of the exported functions the header declares. -}
  , libraryExports :: ![Text]
  }
  deriving stock (Eq, Show)

{-| @Backend.Toolchain.LibraryProducts — the header written beside the
    archive, the system libraries the host must link, what the tools printed,
    and the platform ledger's findings that let the build proceed. -}
data LibraryProducts = LibraryProducts
  { libraryHeader :: !FilePath
  , libraryLinks :: ![Text]
  , libraryWarnings :: !Text
  , libraryFindings :: ![Finding]
  }
  deriving stock (Eq, Show)

compileLibrary :: LibraryRequest -> IO (Either ToolchainFailure LibraryProducts)
compileLibrary request
  | equalFilePath (takeFileName (libraryOutput request)) embeddedHeaderName =
      pure (Left (ToolchainPublishFailed "the library output cannot use the generated header name pudu_program.h"))
  | otherwise = case nativeTargetPlatform target of
      ApplePlatform sdk -> compileApple request sdk
      AndroidPlatform -> compileAndroid request
 where
  target = libraryTarget request

compileApple :: LibraryRequest -> AppleSdk -> IO (Either ToolchainFailure LibraryProducts)
compileApple request sdk = do
  seconds <- timeoutSeconds
  provider <- tlsProvider "PUDU_IOS_OPENSSL_PREFIX" name (librarySource request)
  tools <- case provider of
    Left failure -> pure (Left failure)
    Right tls -> fmap (tls,) <$> appleTools name sdk seconds
  case tools of
    Left failure -> pure (Left failure)
    Right (tls, (root, clang, archiver, findings)) ->
      withLibraryStaging output (build tls seconds root clang archiver findings)
 where
  name = nativeTargetName (libraryTarget request)
  output = libraryOutput request
  build tls seconds root clang archiver findings directory = do
    let sourcePath = directory </> "program.c"
        objectPath = directory </> "program.o"
        archivePath = directory </> "program.a"
        tlsFlags = maybe [] (\(include, _) -> ["-DPUDU_TLS_APPLE_TRUST", "-I", include]) tls
        archives = maybe [] snd tls
        targetFlags = ["-target", Text.unpack (appleTriple sdk), "-isysroot", root]
        frameworks = if null archives then [] else ["-framework", "Security", "-framework", "CoreFoundation"]
        links = ["-lz" | compressLibraryMarker `Text.isInfixOf` librarySource request] <> frameworks
        -- The device and simulator share an architecture. Linking verifies
        -- the provider's platform and minimum OS before publishing its archive.
        checkProvider
          | null archives = pure (Right "")
          | otherwise = do
              linked <- invoke clang (targetFlags <> ["-dynamiclib", "-Wl,-fatal_warnings", "-o", directory </> "verify.dylib", objectPath]
                <> archives <> map Text.unpack links) seconds
              pure $ case linked of
                Left (ToolchainRejected detail) -> Left (ToolchainSdkMissing name
                  ("usable OpenSSL in PUDU_IOS_OPENSSL_PREFIX for this target:\n" <> detail))
                other -> other
        archiveFlags = ["-no_warning_for_no_symbols" | not (null archives)]
    written <- tryIO (ByteString.writeFile sourcePath (Encoding.encodeUtf8 (librarySource request)))
    case written of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right () -> do
        compiled <- invoke clang
          (compilerFlags <> tlsFlags <> targetFlags <> ["-c", sourcePath, "-o", objectPath])
          seconds
        checked <- either (pure . Left) (\warnings -> fmap (warnings <>) <$> checkProvider) compiled
        archived <- either (pure . Left) (\warnings -> fmap (warnings,) <$> invoke archiver (["-static"] <> archiveFlags <> ["-o", archivePath, objectPath] <> archives) seconds) checked
        case archived of
          Left failure -> pure (Left failure)
          Right (compilerOutput, archiverOutput) ->
            publishLibrary request archivePath directory links (libraryExports request)
              [compilerOutput, archiverOutput] findings

withLibraryStaging :: FilePath -> (FilePath -> IO (Either ToolchainFailure LibraryProducts)) -> IO (Either ToolchainFailure LibraryProducts)
withLibraryStaging output build = mask $ \restore -> do
  created <- tryIO (createTempDirectory (takeDirectory output) (takeFileName output <> ".pudu-tmp"))
  case created of
    Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
    Right directory -> restore (build directory)
      `finally` void (tryIO (removeDirectoryRecursive directory))

publishLibrary :: LibraryRequest -> FilePath -> FilePath -> [Text] -> [Text] -> [Text] -> [Finding] -> IO (Either ToolchainFailure LibraryProducts)
publishLibrary request archivePath directory links declarations warnings findings = do
  let output = libraryOutput request
      header = takeDirectory output </> embeddedHeaderName
      stagedHeader = directory </> embeddedHeaderName
  published <- tryIO (do
    ByteString.writeFile stagedHeader (Encoding.encodeUtf8 (embeddedHeader links declarations))
    renameFile archivePath output
    renameFile stagedHeader header)
  pure $ case published of
    Left problem -> Left (ToolchainPublishFailed (problemText problem))
    Right () -> Right (LibraryProducts header links (Text.strip (Text.unlines (filter (not . Text.null) warnings))) findings)

{-| The target's OpenSSL headers and archives. A native unit without TLS
    needs no provider. Use the target's installation, never the host's. -}
tlsProvider :: String -> Text -> Text -> IO (Either ToolchainFailure (Maybe (FilePath, [FilePath])))
tlsProvider variable target source
  | not (tlsLibraryMarker `Text.isInfixOf` source) = pure (Right Nothing)
  | otherwise = do
      prefix <- lookupEnv variable
      case prefix of
        Just root | not (null root) -> do
          let include = root </> "include"
              archives = map ((root </> "lib") </>) ["libssl.a", "libcrypto.a"]
          present <- traverse doesFileExist ((include </> "openssl" </> "ssl.h") : archives)
          pure (if and present then Right (Just (include, archives)) else missing)
        _ -> pure missing
 where
  missing = Left (ToolchainSdkMissing target
    ("OpenSSL for this target. Set " <> Text.pack variable <> " to its installation with include/openssl/ssl.h, lib/libssl.a, and lib/libcrypto.a"))

invoke :: FilePath -> [String] -> Int -> IO (Either ToolchainFailure Text)
invoke executable arguments seconds = do
  ran <- tryIO (runTool executable arguments seconds)
  pure (either (Left . ToolchainInvocation . problemText) id ran)

{-| The system root, compiler and archiver of the target's SDK, each one line
    `xcrun` answers within the deadline, and the ledger's findings about the
    installed Xcode and SDK. A refusing finding stops the build before any
    compile; device SDK builds are distributions, simulator builds are not. -}
appleTools :: Text -> AppleSdk -> Int -> IO (Either ToolchainFailure (FilePath, FilePath, FilePath, [Finding]))
appleTools name sdk seconds = do
  found <- findXcrun
  case found of
    Nothing -> pure (Left (ToolchainSdkMissing name "xcrun"))
    Just xcrun -> do
      let ask arguments = xcrunLine name xcrun (["--sdk", Text.unpack (appleSdkName sdk)] <> arguments) seconds
      root <- ask ["--show-sdk-path"]
      installed <- either (pure . Left) (const (appleInstalled name xcrun sdk seconds)) root
      today <- utctDay <$> getCurrentTime
      let purpose = if appleSdkName sdk == "iphoneos" then Distribution else Development
          assessed = installed >>= \versions -> case assess appleLedger today purpose versions of
            findings | (refused : _) <- filter isRefusal findings -> Left (ToolchainOutsideLedger name refused)
                     | otherwise -> Right findings
      clang <- either (pure . Left) (const (ask ["--find", "clang"])) assessed
      archiver <- either (pure . Left) (const (ask ["--find", "libtool"])) clang
      pure ((,,,) <$> root <*> clang <*> archiver <*> assessed)

xcrunLine :: Text -> FilePath -> [String] -> Int -> IO (Either ToolchainFailure FilePath)
xcrunLine name xcrun arguments seconds = do
  answered <- tryIO (runToolOutput xcrun arguments seconds)
  pure $ case answered of
    Right (Right (out, _, False))
      | [line] <- Text.lines out, not (Text.null (Text.strip line)) -> Right (Text.unpack line)
    Right (Right (_, _, True)) -> Left (missing "tool output was truncated")
    Right (Right _) -> Left (missing "expected one path on standard output")
    Right (Left (ToolchainTimedOut _)) -> Left (missing "it did not answer in time")
    Right (Left (ToolchainRejected detail)) -> Left (missing detail)
    Right (Left problem) -> Left (missing (Text.pack (show problem)))
    Left problem -> Left (missing (problemText problem))
 where
  command = Text.unwords (map Text.pack (xcrun : arguments))
  missing detail = ToolchainSdkMissing name (command <> if Text.null detail then "" else ": " <> detail)

{-| The NDK's compiler and archiver, with the ABI and API level used by the app host. -}
androidLibraryTools :: Text -> IO (Either ToolchainFailure (FilePath, FilePath))
androidLibraryTools target = case target of
  "android-arm64" -> discover "aarch64-linux-android24"
  "android-x86_64" -> discover "x86_64-linux-android24"
  _ -> pure (Left (ToolchainTargetUnbuilt target))
 where
  discover triple = do
    named <- traverse lookupEnv ["ANDROID_NDK_HOME", "ANDROID_NDK_ROOT"]
    home <- getHomeDirectory
    sdk <- traverse lookupEnv ["ANDROID_HOME", "ANDROID_SDK_ROOT"]
    let roots = filter (not . null) (catMaybes sdk)
          <> [home </> "Library" </> "Android" </> "sdk", home </> "Android" </> "Sdk"]
        host = (if os == "darwin" then "darwin" else "linux") <> "-x86_64"
    installed <- fmap concat (traverse installedNdks roots)
    search (filter (not . null) (catMaybes named) <> installed) host triple
  installedNdks sdk = do
    let directory = sdk </> "ndk"
    present <- doesDirectoryExist directory
    if not present then pure [] else do
      entries <- listDirectory directory
      let version = map (readMaybe @Integer . Text.unpack) . Text.splitOn "." . Text.pack
      pure (map (directory </>) (sortOn (Down . version) entries))
  search [] _ _ = pure (Left (ToolchainSdkMissing target "the target NDK compiler and archiver under ANDROID_NDK_HOME, ANDROID_NDK_ROOT, or the Android SDK"))
  search (root : rest) host triple = do
    let bin = root </> "toolchains" </> "llvm" </> "prebuilt" </> host </> "bin"
        clang = bin </> (triple <> "-clang")
        archiver = bin </> "llvm-ar"
    ready <- traverse doesFileExist [clang, archiver]
    if and ready then pure (Right (clang, archiver)) else search rest host triple

compileAndroid :: LibraryRequest -> IO (Either ToolchainFailure LibraryProducts)
compileAndroid request = do
  provider <- tlsProvider "PUDU_ANDROID_OPENSSL_PREFIX" name source
  tools <- case provider of
    Left failure -> pure (Left failure)
    Right tls -> fmap (tls,) <$> androidLibraryTools name
  case tools of
    Left failure -> pure (Left failure)
    Right (tls, (clang, archiver)) ->
      withLibraryStaging output (build tls clang archiver)
 where
  name = nativeTargetName (libraryTarget request)
  source = librarySource request
  output = libraryOutput request
  links = ["-lz" | compressLibraryMarker `Text.isInfixOf` source]
    <> ["-ldl" | foreignLoaderMarker `Text.isInfixOf` source] <> ["-lm"]
  build tls clang archiver directory = do
    seconds <- timeoutSeconds
    let sourcePath = directory </> "program.c"
        objectPath = directory </> "program.o"
        archivePath = directory </> "program.a"
        archives = maybe [] snd tls
        flags = maybe [] (\(include, _) -> ["-DPUDU_TLS_ANDROID_TRUST", "-I", include]) tls
        declarations
          | null archives = []
          | otherwise = ["/* Call with the process JavaVM before running an Android TLS unit. */"
                        , "int pudu_program_android_enable_tls(void *vm);"]
        combine
          | null archives = pure (Right ("", objectPath))
          | otherwise = do
              -- The target link checks the provider's ABI and dependencies.
              -- The relocatable link folds its objects into the archive.
              let validation = directory </> "verify.so"
                  combined = directory </> "combined.o"
              checked <- invoke clang (["-shared", "-Wl,--no-undefined", "-Wl,--fatal-warnings", "-o", validation, objectPath]
                <> archives <> map Text.unpack links) seconds
              case checked of
                Left (ToolchainRejected detail) -> pure (Left (ToolchainSdkMissing name
                  ("usable OpenSSL in PUDU_ANDROID_OPENSSL_PREFIX for this target:\n" <> detail)))
                Left failure -> pure (Left failure)
                Right warnings -> fmap (\extra -> (warnings <> extra, combined))
                  <$> invoke clang (["-nostdlib", "-r", "-o", combined, objectPath, "-Wl,--whole-archive"]
                    <> archives <> ["-Wl,--no-whole-archive"]) seconds
    written <- tryIO (ByteString.writeFile sourcePath (Encoding.encodeUtf8 source))
    case written of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right () -> do
        compiled <- invoke clang (compilerFlags <> flags <> ["-fPIC", "-c", sourcePath, "-o", objectPath]) seconds
        prepared <- either (pure . Left) (\warnings -> fmap (\(extra, object) -> (warnings <> extra, object)) <$> combine) compiled
        archived <- either (pure . Left) (\(warnings, object) -> fmap (warnings <>) <$> invoke archiver ["rcs", archivePath, object] seconds) prepared
        case archived of
          Left failure -> pure (Left failure)
          Right warnings ->
            publishLibrary request archivePath directory links (declarations <> libraryExports request) [warnings] []
