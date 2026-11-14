{-| @Pudu.Backend.Toolchain.App — a signed simulator application: the
    program's static library linked with the embedded iOS host into a bundle.

    Everything is built in a temporary directory beside the output and the
    finished bundle is published by rename, so the output path never holds a
    partial application.
-}
module Pudu.Backend.Toolchain.App
  ( AppRequest (..)
  , bundleIdentifier
  , compileApp
  , infoPlist
  ) where

import Control.Exception (finally, mask)
import Control.Monad (void, when)
import qualified Data.ByteString as ByteString
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Backend.Target (AppleSdk (..), NativeTarget (..), TargetPlatform (..))
import Pudu.Backend.Toolchain.HostSources (iosHostSource)
import Pudu.Backend.Toolchain.Library (LibraryProducts (..), LibraryRequest (..), appleTools, compileLibrary, invoke)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), problemText, timeoutSeconds, tryIO)
import System.Directory (createDirectory, doesDirectoryExist, findExecutable, removeDirectoryRecursive, renameDirectory)
import System.FilePath (takeDirectory, takeExtension, takeFileName, (</>))
import System.IO.Temp (createTempDirectory)

data AppRequest = AppRequest
  { appSource :: !Text
  , appOutput :: !FilePath
  , appTarget :: !NativeTarget
  , appExports :: ![Text]
  , appName :: !Text
  , appIdentifier :: !Text
  }
  deriving stock (Eq, Show)

{-| The SDK whose applications run without a signing identity. -}
simulatorSdk :: Text
simulatorSdk = "iphonesimulator"

{-| The oldest system the application runs on; it matches the targets' triples. -}
minimumSystem :: Text
minimumSystem = "15.0"

{-| The prefix of an identifier derived from a program's name. -}
identifierPrefix :: Text
identifierPrefix = "org.pudu."

{-| The frameworks the iOS host links. -}
hostFrameworks :: [String]
hostFrameworks = ["UIKit", "Foundation"]

{-| The application at the output path, answering the tools' warnings. A
    device application needs a signing identity and is not built yet. -}
compileApp :: AppRequest -> IO (Either ToolchainFailure Text)
compileApp request = case nativeTargetPlatform (appTarget request) of
  ApplePlatform sdk | appleSdkName sdk == simulatorSdk -> buildBundle request sdk
  _ -> pure (Left (ToolchainTargetUnbuilt (nativeTargetName (appTarget request) <> " applications, which need a signing identity,")))

buildBundle :: AppRequest -> AppleSdk -> IO (Either ToolchainFailure Text)
buildBundle request sdk = do
  seconds <- timeoutSeconds
  tools <- appleTools target sdk seconds
  signer <- findExecutable "codesign"
  case (tools, signer) of
    (Left failure, _) -> pure (Left failure)
    (Right _, Nothing) -> pure (Left (ToolchainSdkMissing target "codesign"))
    (Right (root, clang, _), Just codesign) -> mask $ \restore -> do
      created <- tryIO (createTempDirectory (takeDirectory output) (takeFileName output <> ".pudu-tmp"))
      case created of
        Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
        Right directory ->
          restore (assemble seconds root clang codesign directory)
            `finally` void (tryIO (removeDirectoryRecursive directory))
 where
  target = nativeTargetName (appTarget request)
  output = appOutput request
  name = Text.unpack (appName request)
  assemble seconds root clang codesign directory = do
    let library = directory </> "libprogram.a"
        host = directory </> "pudu_ios_host.m"
        bundle = directory </> (name <> ".app")
    built <- compileLibrary LibraryRequest
      { librarySource = appSource request
      , libraryOutput = library
      , libraryTarget = appTarget request
      , libraryExports = appExports request
      }
    case built of
      Left failure -> pure (Left failure)
      Right products -> do
        prepared <- tryIO (do
          createDirectory bundle
          ByteString.writeFile host (Encoding.encodeUtf8 (Text.pack iosHostSource))
          ByteString.writeFile (bundle </> "Info.plist") (Encoding.encodeUtf8 (infoPlist (appName request) (appIdentifier request))))
        case prepared of
          Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
          Right () -> do
            linked <- invoke clang
              (["-target", Text.unpack (appleTriple sdk), "-isysroot", root, "-fobjc-arc", "-O2", "-I", directory, host, library]
                <> map Text.unpack (libraryLinks products)
                <> concat [["-framework", framework] | framework <- hostFrameworks]
                <> ["-o", bundle </> name])
              seconds
            signed <- either (pure . Left) (\warnings -> fmap (const warnings) <$> invoke codesign ["--force", "--sign", "-", bundle] seconds) linked
            case signed of
              Left failure -> pure (Left failure)
              Right warnings -> do
                published <- tryIO (publish bundle)
                pure $ case published of
                  Left problem -> Left (ToolchainPublishFailed (problemText problem))
                  Right () -> Right (Text.strip (Text.unlines (filter (not . Text.null) [libraryWarnings products, warnings])))
  -- Only an earlier application is replaced; anything else at the output
  -- path makes the rename fail rather than be removed.
  publish bundle = do
    earlier <- doesDirectoryExist output
    when (earlier && takeExtension output == ".app") (removeDirectoryRecursive output)
    renameDirectory bundle output

{-| The bundle identifier derived from a program's name: the prefix, then the
    name with every character outside ASCII letters, digits, `-` and `.`
    replaced by `-`. -}
bundleIdentifier :: Text -> Text
bundleIdentifier name = identifierPrefix <> Text.map kept name
 where
  kept c
    | isAsciiLower c || isAsciiUpper c || isDigit c || c == '-' || c == '.' = c
    | otherwise = '-'

{-| The property list of a simulator application named `name` with
    `identifier`, its text escaped for XML. -}
infoPlist :: Text -> Text -> Text
infoPlist name identifier = Text.unlines
  [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  , "<plist version=\"1.0\"><dict>"
  , entry "CFBundleIdentifier" identifier
  , entry "CFBundleExecutable" name
  , entry "CFBundleName" name
  , entry "CFBundlePackageType" "APPL"
  , entry "CFBundleVersion" "1"
  , entry "CFBundleShortVersionString" "1.0"
  , entry "MinimumOSVersion" minimumSystem
  , "<key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>"
  , "<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>"
  , "<key>UILaunchScreen</key><dict/>"
  , "</dict></plist>"
  ]
 where
  entry key value = "<key>" <> key <> "</key><string>" <> escaped value <> "</string>"
  escaped = Text.concatMap $ \c -> case c of
    '&' -> "&amp;"
    '<' -> "&lt;"
    '>' -> "&gt;"
    '"' -> "&quot;"
    '\'' -> "&apos;"
    _ -> Text.singleton c
