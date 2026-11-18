{-| @Pudu.Cli.Doctor — `pudu doctor --native`: the installed native toolchain
    reported against the platform ledger.

    A build reports only what blocks it; the doctor shows the whole state, so
    a toolchain upgrade or a new platform release is judged before a release.
    The report is a pure function of what the probe found and today's date.
-}
module Pudu.Cli.Doctor
  ( DoctorFacts (..)
  , doctorReport
  , runDoctor
  ) where

import Data.List (nub)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Time.Calendar (Day, diffDays, showGregorian)
import Data.Time.Clock (getCurrentTime, utctDay)
import Pudu.Backend.Ledger
  ( Capability (..)
  , Installed (..)
  , Ledger (..)
  , Purpose (..)
  , StoreRule (..)
  , appleLedger
  , assess
  , capabilityStates
  , isRefusal
  , renderRelease
  )
import Pudu.Backend.Target (AppleSdk (..))
import Pudu.Backend.Toolchain.Probe (DeviceType (..), Inventory (..), Runtime (..), appleInstalled, findXcrun, simulatorInventory)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), timeoutSeconds)
import qualified Pudu.Diagnostic.Native as Native
import System.Exit (ExitCode (..), exitWith)
import System.IO (stderr)

{-| @Cli.Doctor.Facts — what the probe found: the device SDK, the simulator
    SDK, and the simulator inventory, each possibly unreadable. -}
data DoctorFacts = DoctorFacts
  { factsDevice :: !(Either Text Installed)
  , factsSimulator :: !(Either Text Installed)
  , factsInventory :: !(Either Text Inventory)
  }
  deriving stock (Eq, Show)

runDoctor :: [String] -> IO ()
runDoctor arguments = case arguments of
  ["--native"] -> do
    seconds <- timeoutSeconds
    today <- utctDay <$> getCurrentTime
    found <- findXcrun
    facts <- case found of
      Nothing -> pure (DoctorFacts missing missing missing)
      Just xcrun -> do
        device <- appleInstalled "ios-arm64" xcrun (AppleSdk "iphoneos" "") seconds
        simulator <- appleInstalled "ios-simulator-arm64" xcrun (AppleSdk "iphonesimulator" "") seconds
        inventory <- simulatorInventory xcrun seconds
        pure (DoctorFacts (failureText device) (failureText simulator) (failureText inventory))
    let (lines', refused) = doctorReport appleLedger today facts
    mapM_ TextIO.putStrLn lines'
    exitWith (if refused then ExitFailure 1 else ExitSuccess)
  _ -> do
    TextIO.hPutStrLn stderr "usage: pudu doctor --native"
    exitWith (ExitFailure 2)
 where
  missing = Left "xcrun was not found; install Xcode or set PUDU_XCRUN"
  failureText = either (Left . describe) Right
  describe failure = case failure of
    ToolchainSdkMissing _ detail -> detail
    other -> Text.pack (show other)

{-| The report lines and whether a development build would be refused. -}
doctorReport :: Ledger -> Day -> DoctorFacts -> ([Text], Bool)
doctorReport ledger today facts =
  ( concat
      [ ["pudu doctor: native toolchain for " <> ledgerPlatform ledger]
      , xcodeLine
      , sdkLine "iphoneos" (factsDevice facts)
      , sdkLine "iphonesimulator" (factsSimulator facts)
      , ["deployment target: " <> ledgerPlatform ledger <> " " <> renderRelease (ledgerDeployment ledger)]
      , map ruleLine (ledgerRules ledger)
      , capabilityLines
      , inventoryLines (factsInventory facts)
      , map Native.ledgerFindingLine findings
      ]
  , either (const True) (const False) (factsSimulator facts) || any isRefusal developmentFindings
  )
 where
  developmentFindings = either (const []) (assess ledger today Development) (factsSimulator facts)
  distributionFindings = either (const []) (assess ledger today Distribution) (factsDevice facts)
  findings = nub (developmentFindings <> distributionFindings)
  xcodeLine = case factsSimulator facts of
    Left problem -> ["Xcode: unavailable (" <> problem <> ")"]
    Right installed ->
      [ "Xcode " <> renderRelease (installedXcode installed) <> ": minimum " <> renderRelease (ledgerMinimumXcode ledger)
          <> ", tested " <> renderRelease (ledgerTestedXcode ledger)
      ]
  sdkLine name found = case found of
    Left problem -> [name <> " SDK: unavailable (" <> problem <> ")"]
    Right installed -> [name <> " SDK " <> renderRelease (installedSdk installed)]
  ruleLine rule =
    ruleStore rule <> " rule from " <> Text.pack (showGregorian (ruleFrom rule)) <> " (Xcode " <> renderRelease (ruleXcode rule)
      <> ", SDK " <> renderRelease (ruleSdk rule) <> "): " <> ruleStanding rule
  ruleStanding rule = case factsDevice facts of
    Left _ -> "unknown, no device SDK"
    Right installed
      | installedXcode installed >= ruleXcode rule && installedSdk installed >= ruleSdk rule -> "met"
      | days <= 0 -> "missed"
      | otherwise -> "due in " <> Text.pack (show days) <> " days"
     where
      days = diffDays (ruleFrom rule) today
  capabilityLines = case factsDevice facts of
    Left _ -> []
    Right installed ->
      [ "capability " <> capabilityName capability <> ": "
          <> (if enabled then "available" else "needs SDK " <> renderRelease (capabilitySdk capability))
          <> " (" <> capabilityPurpose capability <> ")"
      | (capability, enabled) <- capabilityStates ledger (installedSdk installed)
      ]
  inventoryLines found = case found of
    Left problem -> ["simulators: unavailable (" <> problem <> ")"]
    Right inventory -> case reverse (inventoryRuntimes inventory) of
      [] -> ["simulators: no available runtime"]
      newest : _ ->
        [ "simulator runtime " <> runtimeName newest <> ": "
            <> Text.intercalate ", "
              [ family <> " " <> Text.pack (show count) <> " device types"
              | (family, count) <- Map.toList (Map.fromListWith (+) [(deviceFamily device, 1 :: Int) | device <- inventoryDevices inventory])
              ]
        ]
