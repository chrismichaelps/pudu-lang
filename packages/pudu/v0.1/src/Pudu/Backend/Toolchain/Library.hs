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
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Time.Clock (getCurrentTime, utctDay)
import Pudu.Backend.Emit.Entry (embeddedHeader, embeddedHeaderName)
import Pudu.Backend.Runtime.Host.Compress (compressLibraryMarker)
import Pudu.Backend.Ledger (Finding, Purpose (..), appleLedger, assess, isRefusal)
import Pudu.Backend.Target (AppleSdk (..), NativeTarget (..), TargetPlatform (..))
import Pudu.Backend.Toolchain (compilerFlags)
import Pudu.Backend.Toolchain.Probe (appleInstalled, findXcrun)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), problemText, runTool, runToolOutput, timeoutSeconds, tryIO)
import System.Directory (doesDirectoryExist, findExecutable, removeDirectoryRecursive, renameFile)
import System.Environment (lookupEnv)
import System.FilePath (equalFilePath, takeDirectory, takeFileName, (</>))
import System.IO.Temp (createTempDirectory)

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
      AndroidPlatform -> androidOutcome name
 where
  target = libraryTarget request
  name = nativeTargetName target

compileApple :: LibraryRequest -> AppleSdk -> IO (Either ToolchainFailure LibraryProducts)
compileApple request sdk = do
  seconds <- timeoutSeconds
  tools <- appleTools name sdk seconds
  case tools of
    Left failure -> pure (Left failure)
    Right (root, clang, archiver, findings) -> mask $ \restore -> do
      created <- tryIO (createTempDirectory (takeDirectory output) (takeFileName output <> ".pudu-tmp"))
      case created of
        Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
        Right directory ->
          restore (build seconds root clang archiver findings directory)
            `finally` void (tryIO (removeDirectoryRecursive directory))
 where
  name = nativeTargetName (libraryTarget request)
  output = libraryOutput request
  header = takeDirectory output </> embeddedHeaderName
  links = ["-lz" | compressLibraryMarker `Text.isInfixOf` librarySource request]
  build seconds root clang archiver findings directory = do
    let sourcePath = directory </> "program.c"
        objectPath = directory </> "program.o"
        archivePath = directory </> "program.a"
        headerPath = directory </> embeddedHeaderName
    written <- tryIO (ByteString.writeFile sourcePath (Encoding.encodeUtf8 (librarySource request)))
    case written of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right () -> do
        compiled <- invoke clang
          (compilerFlags <> ["-target", Text.unpack (appleTriple sdk), "-isysroot", root, "-c", sourcePath, "-o", objectPath])
          seconds
        archived <- either (pure . Left) (\warnings -> fmap (warnings,) <$> invoke archiver ["-static", "-o", archivePath, objectPath] seconds) compiled
        case archived of
          Left failure -> pure (Left failure)
          Right (compilerOutput, archiverOutput) -> do
            published <- tryIO (do
              ByteString.writeFile headerPath (Encoding.encodeUtf8 (embeddedHeader links (libraryExports request)))
              renameFile archivePath output
              renameFile headerPath header)
            pure $ case published of
              Left problem -> Left (ToolchainPublishFailed (problemText problem))
              Right () -> Right LibraryProducts
                { libraryHeader = header
                , libraryLinks = links
                , libraryWarnings = Text.strip (Text.unlines (filter (not . Text.null) [compilerOutput, archiverOutput]))
                , libraryFindings = findings
                }

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

{-| The NDK named by `ANDROID_NDK_HOME`, then `ANDROID_NDK_ROOT`. -}
androidOutcome :: Text -> IO (Either ToolchainFailure LibraryProducts)
androidOutcome name = do
  named <- traverse lookupEnv androidVariables
  present <- traverse doesDirectoryExist [path | Just path <- named, not (null path)]
  pure $ Left $
    if or present
      then ToolchainTargetUnbuilt name
      else ToolchainSdkMissing name (Text.intercalate " or " (map Text.pack androidVariables) <> " naming an NDK directory")

androidVariables :: [String]
androidVariables = ["ANDROID_NDK_HOME", "ANDROID_NDK_ROOT"]
