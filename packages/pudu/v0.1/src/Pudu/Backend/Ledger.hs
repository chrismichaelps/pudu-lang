{-| @Pudu.Backend.Ledger — the platform toolchain facts a native build is
    checked against, and the findings an installed toolchain earns.

    The ledger is data shipped with the compiler that was tested against it:
    the Xcode floor and tested release, the deployment target, store
    submission rules with their effective dates, and capabilities a newer SDK
    enables. Assessment is pure; codes and wording belong to native
    diagnostics.
-}
module Pudu.Backend.Ledger
  ( Capability (..)
  , Finding (..)
  , Installed (..)
  , Ledger (..)
  , Purpose (..)
  , Release
  , StoreRule (..)
  , appleLedger
  , ledgerTriple
  , assess
  , capabilityStates
  , isRefusal
  , parseRelease
  , release
  , renderRelease
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Read as Read
import Data.Time.Calendar (Day, diffDays, fromGregorian)

{-| @Backend.Ledger.Release — a dotted version compared component by
    component, a missing component reading as zero. -}
newtype Release = Release [Int]
  deriving stock (Show)

instance Eq Release where
  left == right = compare left right == EQ

instance Ord Release where
  compare (Release left) (Release right) = compare (padded left) (padded right)
   where
    width = max (length left) (length right)
    padded parts = take width (parts <> repeat 0)

release :: [Int] -> Release
release = Release

parseRelease :: Text -> Maybe Release
parseRelease text = Release <$> traverse component (Text.splitOn "." (Text.strip text))
 where
  component part = case Read.decimal part of
    Right (value, rest) | Text.null rest -> Just value
    _ -> Nothing

renderRelease :: Release -> Text
renderRelease (Release parts) = Text.intercalate "." (map (Text.pack . show) parts)

{-| @Backend.Ledger.StoreRule — a store's requirement on the toolchain that
    builds a submission, from the day it takes effect. -}
data StoreRule = StoreRule
  { ruleStore :: !Text
  , ruleXcode :: !Release
  , ruleSdk :: !Release
  , ruleFrom :: !Day
  , ruleSource :: !Text
  }
  deriving stock (Eq, Show)

{-| @Backend.Ledger.Capability — a platform feature compiled in only when the
    selected SDK is at least `capabilitySdk`. -}
data Capability = Capability
  { capabilityName :: !Text
  , capabilitySdk :: !Release
  , capabilityPurpose :: !Text
  }
  deriving stock (Eq, Show)

data Ledger = Ledger
  { ledgerPlatform :: !Text
  , ledgerMinimumXcode :: !Release
  , ledgerTestedXcode :: !Release
  , ledgerDeployment :: !Release
  , ledgerRules :: ![StoreRule]
  , ledgerCapabilities :: ![Capability]
  }
  deriving stock (Eq, Show)

{-| What a build produces: only distribution builds are submitted to a store,
    so only they are refused by a store rule. -}
data Purpose = Development | Distribution
  deriving stock (Eq, Show)

data Installed = Installed
  { installedXcode :: !Release
  , installedSdk :: !Release
  }
  deriving stock (Eq, Show)

data Finding
  = XcodeBelowMinimum !Release !Release
  | XcodeUntested !Release !Release
  | StoreRuleMissed !Purpose !StoreRule
  | StoreRuleDue !Integer !StoreRule
  deriving stock (Eq, Show)

{-| The App Store floor is the Xcode floor, so every product of the toolchain
    can be submitted. -}
appleLedger :: Ledger
appleLedger = Ledger
  { ledgerPlatform = "iOS"
  , ledgerMinimumXcode = Release [26, 0]
  , ledgerTestedXcode = Release [26, 6]
  , ledgerDeployment = Release [15, 0]
  , ledgerRules =
      [ StoreRule
          { ruleStore = "App Store"
          , ruleXcode = Release [26, 0]
          , ruleSdk = Release [26, 0]
          , ruleFrom = fromGregorian 2026 4 28
          , ruleSource = "https://developer.apple.com/news/upcoming-requirements/"
          }
      ]
  , ledgerCapabilities =
      [ Capability "glass-material" (Release [26, 0]) "glass realization of materials on iOS 26 or later"
      , Capability "fold-posture" (Release [27, 1]) "hinge angle and reserved regions of the iPhone Duo"
      ]
  }

{-| The clang triple for an architecture at the ledger's deployment target. -}
ledgerTriple :: Ledger -> Text -> Bool -> Text
ledgerTriple ledger architecture simulator =
  architecture <> "-apple-ios" <> renderRelease (ledgerDeployment ledger) <> if simulator then "-simulator" else ""

{-| Findings in order: the toolchain, then each rule in ledger order. A rule
    is due when it is unmet and takes effect within ninety days. -}
assess :: Ledger -> Day -> Purpose -> Installed -> [Finding]
assess ledger today purpose installed =
  [XcodeBelowMinimum xcode lowest | xcode < lowest]
    <> [XcodeUntested xcode tested | xcode >= lowest, majorMinor xcode > majorMinor tested]
    <> concatMap ruled (ledgerRules ledger)
 where
  xcode = installedXcode installed
  lowest = ledgerMinimumXcode ledger
  tested = ledgerTestedXcode ledger
  ruled rule
    | xcode >= ruleXcode rule && installedSdk installed >= ruleSdk rule = []
    | days <= 0 = [StoreRuleMissed purpose rule]
    | days <= 90 = [StoreRuleDue days rule]
    | otherwise = []
   where
    days = diffDays (ruleFrom rule) today

isRefusal :: Finding -> Bool
isRefusal finding = case finding of
  XcodeBelowMinimum _ _ -> True
  StoreRuleMissed Distribution _ -> True
  _ -> False

capabilityStates :: Ledger -> Release -> [(Capability, Bool)]
capabilityStates ledger sdk = [(capability, sdk >= capabilitySdk capability) | capability <- ledgerCapabilities ledger]

majorMinor :: Release -> Release
majorMinor (Release parts) = Release (take 2 parts)
