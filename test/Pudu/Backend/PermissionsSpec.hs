{-| @Test.Backend.PermissionsSpec — an application's declared permissions
    against the kinds it requests, and the platform declarations each kind
    writes. -}
module Pudu.Backend.PermissionsSpec (permissionProperties) where

import qualified Data.Set as Set
import qualified Data.Text as Text
import Pudu.Backend.Permissions
  ( Permission (..)
  , PermissionKind (..)
  , PermissionProblem (..)
  , androidEntries
  , appleFlags
  , appleFrameworks
  , appleUsageKeys
  , kindNamed
  , settlePermissions
  )
import Pudu.Backend.Toolchain.Android (packageManifest)
import Pudu.Backend.Toolchain.App (infoPlist)
import Pudu.Compiler.Manifest (manifestPermissions, parseManifest)
import Test.QuickCheck (Property, conjoin, counterexample, once, (===))

permissionProperties :: [(String, IO Property)]
permissionProperties =
  [ ("the manifest's permission table is read in written order", pure (once manifestTable))
  , ("declared permissions that cover every request build", pure (once covered))
  , ("an undeclared request, an unknown key and a missing reason refuse the build", pure (once refused))
  , ("each kind writes its usage keys, flag, framework and manifest entries", pure (once declarations))
  , ("the property list and manifest carry the declarations", pure (once written))
  ]

manifestTable :: Property
manifestTable =
  manifestPermissions (parseManifest "[package]\nname = \"a\"\n[app.permissions]\ncamera = \"Scans\"\nmotion = 'Counts steps'\n")
    === [("camera", "Scans", 4), ("motion", "Counts steps", 5)]

covered :: Property
covered =
  let (problems, declared, unused) = settlePermissions [("camera", "Scans", 1), ("contacts", "Finds", 2)] (Set.fromList [Camera])
   in conjoin
        [ problems === []
        , declared === [Permission Camera "Scans", Permission Contacts "Finds"]
        , counterexample "contacts is declared and never requested" (unused === ["contacts"])
        ]

refused :: Property
refused =
  let (problems, _, _) = settlePermissions [("camra", "Scans", 3), ("contacts", "  ", 4)] (Set.fromList [Camera, Contacts])
   in problems === [Unknown "camra" 3, ReasonMissing "contacts" 4, Undeclared "camera"]

declarations :: Property
declarations =
  let always = [Permission LocationAlways "Tracks runs"]
      photos = [Permission Photos "Picks photos", Permission PhotosAdd "Saves photos"]
   in conjoin
        [ kindNamed "photos-add" === Just PhotosAdd
        , kindNamed "camra" === Nothing
        , appleUsageKeys always === [("NSLocationAlwaysAndWhenInUseUsageDescription", "Tracks runs"), ("NSLocationWhenInUseUsageDescription", "Tracks runs")]
        , appleFlags always === ["-DPUDU_PERMISSION_LOCATION_ALWAYS=1"]
        , appleFrameworks photos === ["Photos"]
        , appleUsageKeys [Permission Notifications "Reminds"] === []
        , counterexample "storage access is bounded to the levels that need it"
            (any ("READ_EXTERNAL_STORAGE\" android:maxSdkVersion=\"32\"" `Text.isInfixOf`) (androidEntries photos))
        , length (androidEntries [Permission Location "Maps", Permission LocationAlways "Tracks"]) === 3
        ]

written :: Property
written =
  let plist = infoPlist "A" "org.pudu.A" [("NSCameraUsageDescription", "Scans <receipts>")]
      manifest = packageManifest False "A" (androidEntries [Permission Camera "Scans"])
   in conjoin
        [ counterexample (Text.unpack plist) ("<key>NSCameraUsageDescription</key><string>Scans &lt;receipts&gt;</string>" `Text.isInfixOf` plist)
        , counterexample (Text.unpack manifest)
            ("<uses-permission android:name=\"android.permission.CAMERA\" />\n  <application" `Text.isInfixOf` manifest)
        ]
