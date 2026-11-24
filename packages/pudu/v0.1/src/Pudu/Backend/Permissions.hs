{-| @Backend.Permissions — the permissions an application can ask for, and
    what its platforms must declare for them.

    Native lowering keeps only what `main` reaches, so a permission kind the
    lowered program constructs is one it can request. The permission module's
    own tables construct every kind to decode host reports; those functions
    are left out, so a kind counts only where a program, or a library it
    uses, builds it. A requested kind the manifest does not declare is refused,
    a declared kind nothing requests is reported, and each declared kind
    becomes the iOS usage keys, compile flag and framework and the Android
    manifest entries that kind needs. -}
module Pudu.Backend.Permissions
  ( PermissionKind (..)
  , Permission (..)
  , PermissionProblem (..)
  , androidEntries
  , appleFlags
  , appleFrameworks
  , appleUsageKeys
  , kindNamed
  , requestedKinds
  , settlePermissions
  ) where

import Data.Data (Data, cast, gmapQ)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Core (CoreExpression (..), CoreExpressionShape (..), CoreFunction (..), CoreModule (..), CoreType (..))

{-| A permission kind, named by its manifest key. -}
data PermissionKind
  = Camera
  | Microphone
  | Photos
  | PhotosAdd
  | Location
  | LocationAlways
  | Notifications
  | Contacts
  | Calendar
  | Bluetooth
  | Motion
  deriving stock (Bounded, Enum, Eq, Ord, Show)

{-| A declared permission: its kind and the reason the person reads. -}
data Permission = Permission { permissionKind :: !PermissionKind, permissionReason :: !Text }
  deriving stock (Eq, Show)

{-| What each kind needs: its manifest key and Pudu variant name, the iOS
    usage keys, compile flag and framework, and the Android permissions, each
    with the highest API level it applies to, if any. -}
data Needs = Needs
  { needsKey :: !Text
  , needsVariant :: !Text
  , needsUsage :: ![Text]
  , needsFlag :: !Text
  , needsFramework :: !Text
  , needsAndroid :: ![(Text, Maybe Int)]
  }

needs :: Map PermissionKind Needs
needs = Map.fromList
  [ (Camera, Needs "camera" "Camera" ["NSCameraUsageDescription"] "PUDU_PERMISSION_CAMERA" "AVFoundation" [("android.permission.CAMERA", Nothing)])
  , (Microphone, Needs "microphone" "Microphone" ["NSMicrophoneUsageDescription"] "PUDU_PERMISSION_MICROPHONE" "AVFoundation" [("android.permission.RECORD_AUDIO", Nothing)])
  , (Photos, Needs "photos" "Photos" ["NSPhotoLibraryUsageDescription"] "PUDU_PERMISSION_PHOTOS" "Photos"
      [("android.permission.READ_MEDIA_IMAGES", Nothing), ("android.permission.READ_MEDIA_VISUAL_USER_SELECTED", Nothing), ("android.permission.READ_EXTERNAL_STORAGE", Just 32)])
  , (PhotosAdd, Needs "photos-add" "PhotosAdd" ["NSPhotoLibraryAddUsageDescription"] "PUDU_PERMISSION_PHOTOS_ADD" "Photos"
      [("android.permission.WRITE_EXTERNAL_STORAGE", Just 28)])
  , (Location, Needs "location" "Location" ["NSLocationWhenInUseUsageDescription"] "PUDU_PERMISSION_LOCATION" "CoreLocation"
      [("android.permission.ACCESS_COARSE_LOCATION", Nothing), ("android.permission.ACCESS_FINE_LOCATION", Nothing)])
  , (LocationAlways, Needs "location-always" "LocationAlways" ["NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"]
      "PUDU_PERMISSION_LOCATION_ALWAYS" "CoreLocation"
      [("android.permission.ACCESS_COARSE_LOCATION", Nothing), ("android.permission.ACCESS_FINE_LOCATION", Nothing), ("android.permission.ACCESS_BACKGROUND_LOCATION", Nothing)])
  , (Notifications, Needs "notifications" "Notifications" [] "PUDU_PERMISSION_NOTIFICATIONS" "UserNotifications" [("android.permission.POST_NOTIFICATIONS", Nothing)])
  , (Contacts, Needs "contacts" "Contacts" ["NSContactsUsageDescription"] "PUDU_PERMISSION_CONTACTS" "Contacts" [("android.permission.READ_CONTACTS", Nothing)])
  , (Calendar, Needs "calendar" "Calendar" ["NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription"] "PUDU_PERMISSION_CALENDAR" "EventKit"
      [("android.permission.READ_CALENDAR", Nothing), ("android.permission.WRITE_CALENDAR", Nothing)])
  , (Bluetooth, Needs "bluetooth" "Bluetooth" ["NSBluetoothAlwaysUsageDescription"] "PUDU_PERMISSION_BLUETOOTH" "CoreBluetooth"
      [("android.permission.BLUETOOTH_CONNECT", Nothing), ("android.permission.BLUETOOTH_SCAN", Nothing), ("android.permission.BLUETOOTH", Just 30)])
  , (Motion, Needs "motion" "Motion" ["NSMotionUsageDescription"] "PUDU_PERMISSION_MOTION" "CoreMotion" [("android.permission.ACTIVITY_RECOGNITION", Nothing)])
  ]

needsOf :: PermissionKind -> Needs
needsOf kind = needs Map.! kind

{-| The kind a manifest key names. -}
kindNamed :: Text -> Maybe PermissionKind
kindNamed key = lookup key [(needsKey (needsOf kind), kind) | kind <- [minBound .. maxBound]]

-- The canonical name of the permission kind type, and its module's prefix.
kindType, permissionModule :: Text
kindType = "Std.Mobile.Permission.Kind"
permissionModule = "Std.Mobile.Permission."

{-| Every kind the lowered program constructs outside the permission module. -}
requestedKinds :: CoreModule -> Set PermissionKind
requestedKinds core = Set.fromList
  [ kind
  | function <- coreModuleFunctions core
  , not (permissionModule `Text.isPrefixOf` coreFunctionName function)
  , CoreExpression{coreExpressionType = CoreSumType name _, coreExpressionShape = CoreConstruct variant _} <- expressions (coreFunctionBody function)
  , name == kindType
  , Just kind <- [lookup variant [(needsVariant (needsOf each), each) | each <- [minBound .. maxBound]]]
  ]

-- Every expression inside a value, outermost first.
expressions :: Data a => a -> [CoreExpression]
expressions value = case cast value of
  Just expression -> expression : concat (gmapQ expressions value)
  Nothing -> concat (gmapQ expressions value)

{-| Why a manifest's permissions cannot build: a kind the program requests
    and the manifest omits, a key no kind has, or a kind declared without a
    reason. Lines are the manifest's. -}
data PermissionProblem
  = Undeclared !Text
  | Unknown !Text !Int
  | ReasonMissing !Text !Int
  deriving stock (Eq, Show)

{-| The manifest's `[app.permissions]` entries against the kinds the program
    requests: the problems that refuse the build, the declared permissions,
    and the keys declared but never requested. -}
settlePermissions :: [(Text, Text, Int)] -> Set PermissionKind -> ([PermissionProblem], [Permission], [Text])
settlePermissions entries requested = (unknown <> unreasoned <> undeclared, declared, unused)
 where
  known = [(kind, reason, line, key) | (key, reason, line) <- entries, Just kind <- [kindNamed key]]
  unknown = [Unknown key line | (key, _, line) <- entries, kindNamed key == Nothing]
  unreasoned = [ReasonMissing key line | (_, reason, line, key) <- known, Text.null (Text.strip reason)]
  declaredKinds = Set.fromList [kind | (kind, _, _, _) <- known]
  undeclared = [Undeclared (needsKey (needsOf kind)) | kind <- Set.toList (Set.difference requested declaredKinds)]
  declared = [Permission kind reason | (kind, reason, _, _) <- known]
  unused = [key | (kind, _, _, key) <- known, not (Set.member kind requested)]

{-| The iOS Info.plist keys and their reasons for the declared permissions;
    a key two kinds share carries the first kind's reason. -}
appleUsageKeys :: [Permission] -> [(Text, Text)]
appleUsageKeys declared = Map.toList (Map.fromListWith (\_ first -> first)
  [(key, permissionReason permission) | permission <- declared, key <- needsUsage (needsOf (permissionKind permission))])

{-| The compile flags that build each declared kind's host code. -}
appleFlags :: [Permission] -> [Text]
appleFlags declared = Set.toList (Set.fromList ["-D" <> needsFlag (needsOf (permissionKind permission)) <> "=1" | permission <- declared])

{-| The frameworks the declared kinds' host code links. -}
appleFrameworks :: [Permission] -> [Text]
appleFrameworks declared = Set.toList (Set.fromList [needsFramework (needsOf (permissionKind permission)) | permission <- declared])

{-| The Android manifest's permission entries for the declared kinds. -}
androidEntries :: [Permission] -> [Text]
androidEntries declared = Map.foldrWithKey entry [] (Map.fromList
  [(name, bound) | permission <- declared, (name, bound) <- needsAndroid (needsOf (permissionKind permission))])
 where
  entry name bound rest = ("  <uses-permission android:name=\"" <> name <> "\"" <> maybe "" maxSdk bound <> " />") : rest
  maxSdk level = " android:maxSdkVersion=\"" <> Text.pack (show level) <> "\""
