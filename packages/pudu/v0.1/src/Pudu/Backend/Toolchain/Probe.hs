{-| @Pudu.Backend.Toolchain.Probe — what the installed Apple tools are: the
    Xcode and SDK releases a build is assessed with, and the simulator
    runtimes and device families a test matrix can use.

    Answers are read from the tools' plain listings by pure parsers, so an
    unexpected line is skipped rather than failing discovery.
-}
module Pudu.Backend.Toolchain.Probe
  ( DeviceType (..)
  , Inventory (..)
  , Runtime (..)
  , appleInstalled
  , findXcrun
  , parseDeviceTypes
  , parseRuntimes
  , parseXcodeVersion
  , simulatorInventory
  ) where

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Ledger (Installed (..), Release, parseRelease)
import Pudu.Backend.Target (AppleSdk (..))
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), problemText, runToolOutput, tryIO)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)

{-| @Backend.Toolchain.Probe.Runtime — an available simulator runtime. -}
data Runtime = Runtime
  { runtimeName :: !Text
  , runtimeRelease :: !Release
  }
  deriving stock (Eq, Show)

{-| @Backend.Toolchain.Probe.DeviceType — a simulator device type and the
    family its name begins with. -}
data DeviceType = DeviceType
  { deviceName :: !Text
  , deviceFamily :: !Text
  }
  deriving stock (Eq, Show)

data Inventory = Inventory
  { inventoryRuntimes :: ![Runtime]
  , inventoryDevices :: ![DeviceType]
  }
  deriving stock (Eq, Show)

{-| `PUDU_XCRUN` when set, otherwise `xcrun` on the search path. -}
findXcrun :: IO (Maybe FilePath)
findXcrun = do
  override <- lookupEnv "PUDU_XCRUN"
  case override of
    Just value | not (null value) -> pure (Just value)
    _ -> findExecutable "xcrun"

{-| The selected Xcode and the release of `sdk`. -}
appleInstalled :: Text -> FilePath -> AppleSdk -> Int -> IO (Either ToolchainFailure Installed)
appleInstalled target xcrun sdk seconds = do
  xcode <- answer target xcrun ["xcodebuild", "-version"] seconds parseXcodeVersion
  version <- answer target xcrun ["--sdk", Text.unpack (appleSdkName sdk), "--show-sdk-version"] seconds parseRelease
  pure (Installed <$> xcode <*> version)

{-| Available runtimes and every device type the tools list. -}
simulatorInventory :: FilePath -> Int -> IO (Either ToolchainFailure Inventory)
simulatorInventory xcrun seconds = do
  runtimes <- answer "simulator" xcrun ["simctl", "list", "runtimes"] seconds (Just . parseRuntimes)
  devices <- answer "simulator" xcrun ["simctl", "list", "devicetypes"] seconds (Just . parseDeviceTypes)
  pure (Inventory <$> runtimes <*> devices)

{-| The release on the first line, `Xcode 26.6`. -}
parseXcodeVersion :: Text -> Maybe Release
parseXcodeVersion out = case Text.words <$> take 1 (Text.lines out) of
  [["Xcode", version]] -> parseRelease version
  _ -> Nothing

{-| Lines such as `iOS 26.4 (26.4 - 23E244) - com.apple...`; runtimes marked
    unavailable are skipped. -}
parseRuntimes :: Text -> [Runtime]
parseRuntimes = mapMaybe runtime . Text.lines
 where
  runtime line = case Text.words line of
    (platform : version : _)
      | platform == "iOS"
      , not ("unavailable" `Text.isInfixOf` line)
      , Just found <- parseRelease version ->
          Just (Runtime (platform <> " " <> version) found)
    _ -> Nothing

{-| Lines such as `iPhone 17 Pro (com.apple...)`. The family is the first
    word of the name, or the first two when the name begins with the maker,
    as in `Apple Watch` and `Apple TV`. -}
parseDeviceTypes :: Text -> [DeviceType]
parseDeviceTypes = mapMaybe device . Text.lines
 where
  device line
    | "(com.apple." `Text.isInfixOf` line
    , name <- Text.strip (fst (Text.breakOn " (com.apple." line))
    , Just family <- familyOf (Text.words name) =
        Just (DeviceType name family)
    | otherwise = Nothing
  familyOf words' = case words' of
    ("Apple" : line' : _) -> Just ("Apple " <> line')
    (first : _) -> Just first
    [] -> Nothing

answer :: Text -> FilePath -> [String] -> Int -> (Text -> Maybe a) -> IO (Either ToolchainFailure a)
answer target xcrun arguments seconds parse = do
  ran <- tryIO (runToolOutput xcrun arguments seconds)
  pure $ case ran of
    Right (Right (out, _, False)) | Just value <- parse out -> Right value
    Right (Right _) -> Left (missing "the answer could not be read")
    Right (Left (ToolchainTimedOut _)) -> Left (missing "it did not answer in time")
    Right (Left (ToolchainRejected detail)) -> Left (missing detail)
    Right (Left problem) -> Left (missing (Text.pack (show problem)))
    Left problem -> Left (missing (problemText problem))
 where
  command = Text.unwords (map Text.pack (xcrun : arguments))
  missing detail = ToolchainSdkMissing target (command <> ": " <> detail)
