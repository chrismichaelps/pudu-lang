{-| @Test.Backend.LedgerSpec — platform ledger assessment, the toolchain
    probe's parsers, ledger wording, and the doctor report. -}
module Pudu.Backend.LedgerSpec (ledgerProperties) where

import Control.Exception (bracket)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Time.Calendar (Day, addDays, fromGregorian)
import Pudu.Backend.Ledger
  ( Finding (..)
  , Installed (..)
  , Ledger (..)
  , Purpose (..)
  , StoreRule (..)
  , appleLedger
  , assess
  , capabilityStates
  , isRefusal
  , ledgerTriple
  , parseRelease
  , release
  )
import Pudu.Backend.Target (AppleSdk (..), NativeTarget (..), TargetPlatform (..), nativeTargetNamed)
import Pudu.Backend.Toolchain.Library (LibraryRequest (..), compileLibrary)
import Pudu.Backend.Toolchain.Probe (DeviceType (..), Inventory (..), Runtime (..), parseDeviceTypes, parseRuntimes, parseXcodeVersion)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..))
import Pudu.Cli.Doctor (DoctorFacts (..), doctorReport)
import qualified Pudu.Diagnostic.Native as Native
import System.Directory (getPermissions, listDirectory, setOwnerExecutable, setPermissions)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, once, property, (===))

ledgerProperties :: [(String, IO Property)]
ledgerProperties =
  [ ("ledger releases parse and compare by component", pure (once releases))
  , ("ledger findings refuse or warn by purpose", pure (once findings))
  , ("ledger store rules fall due ninety days ahead", pure (once dueWindow))
  , ("ledger capabilities and triples follow the SDK and deployment target", pure (once capabilities))
  , ("toolchain probe parses the tools' listings", pure (once parsers))
  , ("ledger wording carries the stable codes", pure (once wording))
  , ("doctor reports the toolchain and refuses without Xcode", pure (once doctor))
  , ("ledger refuses an old Xcode before any compile", once <$> refusedBuild)
  ]

today :: Day
today = fromGregorian 2026 11 14

installed :: [Int] -> [Int] -> Installed
installed xcode sdk = Installed (release xcode) (release sdk)

{-| The App Store rule as Apple published it; the ledger must hold exactly
    this. -}
appStore :: StoreRule
appStore = StoreRule
  { ruleStore = "App Store"
  , ruleXcode = release [26, 0]
  , ruleSdk = release [26, 0]
  , ruleFrom = fromGregorian 2026 4 28
  , ruleSource = "https://developer.apple.com/news/upcoming-requirements/"
  }

releases :: Property
releases =
  conjoin
    [ parseRelease "26.6" === Just (release [26, 6])
    , parseRelease " 26.0.1 " === Just (release [26, 0, 1])
    , parseRelease "26" === Just (release [26, 0])
    , parseRelease "26.x" === Nothing
    , parseRelease "" === Nothing
    , counterexample "26.0 < 26.0.1" (release [26, 0] < release [26, 0, 1])
    , counterexample "9.9 < 26" (release [9, 9] < release [26])
    ]

findings :: Property
findings =
  conjoin
    [ ledgerRules appleLedger === [appStore]
    , counterexample "the tested toolchain earns nothing" (assess appleLedger today Development (installed [26, 6] [26, 5]) === [])
    , assess appleLedger today Distribution (installed [26, 6] [26, 5]) === []
    , counterexample "a patch release is still tested" (assess appleLedger today Development (installed [26, 6, 1] [26, 5]) === [])
    , assess appleLedger today Development (installed [27, 0] [27, 0]) === [XcodeUntested (release [27, 0]) (release [26, 6])]
    , assess appleLedger today Development old === [XcodeBelowMinimum (release [25, 4]) (release [26, 0]), StoreRuleMissed Development appStore]
    , map isRefusal (assess appleLedger today Development old) === [True, False]
    , map isRefusal (assess appleLedger today Distribution old) === [True, True]
    , counterexample "a warning never refuses" (not (isRefusal (XcodeUntested (release [27, 0]) (release [26, 6]))))
    ]
 where
  old = installed [25, 4] [18, 5]

dueWindow :: Property
dueWindow =
  conjoin
    [ ruledAt 90 === [StoreRuleDue 90 (ruleFrom 90)]
    , ruledAt 91 === []
    , ruledAt 0 === [StoreRuleMissed Distribution (ruleFrom 0)]
    , counterexample "a due rule warns" (not (any isRefusal (ruledAt 1)))
    ]
 where
  ruleFrom days = appStore {ruleXcode = release [27, 0], ruleSdk = release [27, 0], ruleFrom = addDays days today}
  ruledAt days = assess appleLedger {ledgerRules = [ruleFrom days]} today Distribution (installed [26, 6] [26, 5])

capabilities :: Property
capabilities =
  conjoin
    [ map snd (capabilityStates appleLedger (release [26, 5])) === [True, False]
    , map snd (capabilityStates appleLedger (release [27, 1])) === [True, True]
    , map snd (capabilityStates appleLedger (release [18, 5])) === [False, False]
    , ledgerTriple appleLedger "arm64" False === "arm64-apple-ios15.0"
    , ledgerTriple appleLedger "arm64" True === "arm64-apple-ios15.0-simulator"
    , fmap triple (nativeTargetNamed "ios-arm64") === Just (Just "arm64-apple-ios15.0")
    , fmap triple (nativeTargetNamed "ios-simulator-arm64") === Just (Just "arm64-apple-ios15.0-simulator")
    ]
 where
  triple target = case nativeTargetPlatform target of
    ApplePlatform sdk -> Just (appleTriple sdk)
    AndroidPlatform -> Nothing

parsers :: Property
parsers =
  conjoin
    [ parseXcodeVersion "Xcode 26.6\nBuild version 17F113\n" === Just (release [26, 6])
    , parseXcodeVersion "xcodebuild: error: no developer directory\n" === Nothing
    , parseRuntimes runtimes === [Runtime "iOS 18.3" (release [18, 3]), Runtime "iOS 26.4" (release [26, 4])]
    , parseDeviceTypes devices
        === [ DeviceType "iPhone 17 Pro" "iPhone"
            , DeviceType "iPad Pro 13-inch (M5) (16GB)" "iPad"
            , DeviceType "Apple Watch Ultra 3 (49mm)" "Apple Watch"
            ]
    ]
 where
  runtimes =
    Text.unlines
      [ "== Runtimes =="
      , "iOS 18.3 (18.3.1 - 22D8075) - com.apple.CoreSimulator.SimRuntime.iOS-18-3"
      , "iOS 17.5 (17.5 - 21F79) - com.apple.CoreSimulator.SimRuntime.iOS-17-5 (unavailable, runtime missing)"
      , "watchOS 26.4 (26.4 - 23T5) - com.apple.CoreSimulator.SimRuntime.watchOS-26-4"
      , "iOS 26.4 (26.4 - 23E244) - com.apple.CoreSimulator.SimRuntime.iOS-26-4"
      ]
  devices =
    Text.unlines
      [ "== Device Types =="
      , "iPhone 17 Pro (com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro)"
      , "iPad Pro 13-inch (M5) (16GB) (com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB)"
      , "Apple Watch Ultra 3 (49mm) (com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-3-49mm)"
      , "an unrelated line"
      ]

wording :: Property
wording =
  conjoin
    [ counterexample "W6011" ("warning[W6011]: " `Text.isPrefixOf` Native.ledgerWarning (XcodeUntested (release [27, 0]) (release [26, 6])))
    , counterexample "W6012 due" ("warning[W6012]: " `Text.isPrefixOf` Native.ledgerWarning (StoreRuleDue 30 appStore))
    , counterexample "W6012 development" ("warning[W6012]: " `Text.isPrefixOf` Native.ledgerWarning (StoreRuleMissed Development appStore))
    , counterexample "E6009" ("E6009: " `Text.isPrefixOf` Native.ledgerFindingLine (XcodeBelowMinimum (release [25, 4]) (release [26, 0])))
    , counterexample "E6010 names its source" ("developer.apple.com" `Text.isInfixOf` Native.ledgerFindingLine (StoreRuleMissed Distribution appStore))
    ]

doctor :: Property
doctor =
  conjoin
    [ report
        === [ "pudu doctor: native toolchain for iOS"
            , "Xcode 26.6: minimum 26.0, tested 26.6"
            , "iphoneos SDK 26.5"
            , "iphonesimulator SDK 26.5"
            , "deployment target: iOS 15.0"
            , "App Store rule from 2026-04-28 (Xcode 26.0, SDK 26.0): met"
            , "capability glass-material: available (glass realization of materials on iOS 26 or later)"
            , "capability fold-posture: needs SDK 27.1 (hinge angle and reserved regions of the iPhone Duo)"
            , "simulator runtime iOS 26.4: iPad 1 device types, iPhone 2 device types"
            ]
    , counterexample "a tested toolchain is not refused" (not refused)
    , counterexample "an old Xcode is refused" (snd (doctorReport appleLedger today oldFacts))
    , counterexample "an old Xcode prints E6009" (any ("E6009: " `Text.isPrefixOf`) (fst (doctorReport appleLedger today oldFacts)))
    , counterexample "no Xcode is refused" (snd (doctorReport appleLedger today absent))
    , take 2 (fst (doctorReport appleLedger today absent)) === ["pudu doctor: native toolchain for iOS", "Xcode: unavailable (no xcrun)"]
    ]
 where
  current = Right (installed [26, 6] [26, 5])
  inventory =
    Right (Inventory [Runtime "iOS 26.4" (release [26, 4])] [DeviceType "iPhone 17" "iPhone", DeviceType "iPhone Air" "iPhone", DeviceType "iPad mini" "iPad"])
  (report, refused) = doctorReport appleLedger today (DoctorFacts current current inventory)
  oldFacts = DoctorFacts (Right (installed [25, 4] [18, 5])) (Right (installed [25, 4] [18, 5])) inventory
  absent = DoctorFacts (Left "no xcrun") (Left "no xcrun") (Left "no xcrun")

{-| An Xcode below the floor is refused with its finding, and nothing is
    compiled or written: the fake tools answer every question but compile. -}
refusedBuild :: IO Property
refusedBuild = withSystemTempDirectory "pudu-ledger" $ \root ->
  case nativeTargetNamed "ios-simulator-arm64" of
    Nothing -> pure (property False)
    Just target -> do
      let fake = root </> "fake-xcrun"
      TextIO.writeFile fake $ Text.unlines
        [ "#!/bin/sh"
        , "case \"$*\" in"
        , "  *--show-sdk-path*) printf '/some/sdk\\n' ;;"
        , "  *--show-sdk-version*) printf '18.5\\n' ;;"
        , "  xcodebuild*) printf 'Xcode 25.4\\nBuild version 1\\n' ;;"
        , "  *) printf 'unexpected %s\\n' \"$*\" >&2; exit 1 ;;"
        , "esac"
        ]
      permissions <- getPermissions fake
      setPermissions fake (setOwnerExecutable True permissions)
      result <- withEnvironment "PUDU_XCRUN" (Just fake) (compileLibrary (LibraryRequest "" (root </> "libMain.a") target []))
      files <- listDirectory root
      pure $ conjoin
        [ result === Left (ToolchainOutsideLedger "ios-simulator-arm64" (XcodeBelowMinimum (release [25, 4]) (release [26, 0])))
        , files === ["fake-xcrun"]
        ]

withEnvironment :: String -> Maybe String -> IO a -> IO a
withEnvironment name value action =
  bracket (lookupEnv name) (set name) (const (set name value >> action))
 where
  set key = maybe (unsetEnv key) (setEnv key)
