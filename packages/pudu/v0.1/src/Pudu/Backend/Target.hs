{-| @Pudu.Backend.Target — the closed set of mobile native targets and what
    each refuses to carry.

    A target is chosen by name. Refusals are decided from the runtime parts an
    emitted unit selected and the foreign libraries it names, before any tool
    runs, so a construct a platform forbids is reported by name rather than as
    a C compiler error.
-}
module Pudu.Backend.Target
  ( AppleSdk (..)
  , NativeTarget (..)
  , TargetPlatform (..)
  , TargetRefusal (..)
  , nativeTargetNamed
  , nativeTargetNames
  , targetRefusals
  ) where

import Data.List (nub)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text

{-| @Backend.Target.AppleSdk — the SDK `xcrun` knows and the clang triple,
    minimum release included, that compiles for it. -}
data AppleSdk = AppleSdk
  { appleSdkName :: !Text
  , appleTriple :: !Text
  }
  deriving stock (Eq, Show)

{-| @Backend.Target.Platform — Android names are reserved: the platform is
    known, its toolchain fields arrive with the slice that builds it. -}
data TargetPlatform = ApplePlatform !AppleSdk | AndroidPlatform
  deriving stock (Eq, Show)

data NativeTarget = NativeTarget
  { nativeTargetName :: !Text
  , nativeTargetPlatform :: !TargetPlatform
  }
  deriving stock (Eq, Show)

{-| @Backend.Target.Refusal — the construct a target cannot carry and why. -}
data TargetRefusal = TargetRefusal
  { refusedConstruct :: !Text
  , refusedReason :: !Text
  }
  deriving stock (Eq, Show)

nativeTargets :: Map Text NativeTarget
nativeTargets = Map.fromList
  [ (name, NativeTarget name platform)
  | (name, platform) <-
      [ ("ios-arm64", ApplePlatform (AppleSdk "iphoneos" "arm64-apple-ios15.0"))
      , ("ios-simulator-arm64", ApplePlatform (AppleSdk "iphonesimulator" "arm64-apple-ios15.0-simulator"))
      , ("android-arm64", AndroidPlatform)
      , ("android-x86_64", AndroidPlatform)
      ]
  ]

nativeTargetNamed :: Text -> Maybe NativeTarget
nativeTargetNamed name = Map.lookup name nativeTargets

nativeTargetNames :: [Text]
nativeTargetNames = Map.keys nativeTargets

{-| Each refused base part: its construct, why iOS refuses it, and why Android
    does. Every dependent part closes over its base, so the base names it. -}
refusedParts :: Map Text (Text, Text, Text)
refusedParts = Map.fromList
  [ ("host_children", ("child programs", "the application sandbox forbids starting processes", androidUnmeasured))
  , ("host_signals", ("stop signals", "the system suspends and ends applications without them", androidUnmeasured))
  , ("host_exit", ("ending the process", "an application never quits itself", androidUnmeasured))
  , ("host_tls", ("TLS connections", "the platform ships no OpenSSL", "the NDK ships no OpenSSL"))
  , ("host_desktop", ("desktop windows", "the desktop adapter is AppKit, which runs only on macOS", macOnly))
  , ("host_audio", ("audio devices and streams", "the audio adapter is the macOS one", macOnly))
  ]
 where
  androidUnmeasured = "what an Android application may do here is not yet measured"
  macOnly = "the adapter runs only on macOS"

{-| Paths an iOS application may load from: system frameworks and libraries,
    and frameworks embedded in its own bundle. -}
appleLibraryPrefixes :: [Text]
appleLibraryPrefixes = ["/System/Library/Frameworks/", "/usr/lib/", "@rpath/", "@executable_path/"]

{-| What the target refuses of a unit with these selected parts and foreign
    library names: parts in table order, then libraries in first-seen order. -}
targetRefusals :: NativeTarget -> Set Text -> [(Text, Maybe Text)] -> [TargetRefusal]
targetRefusals target parts libraries =
  [ TargetRefusal construct (reasonFor apple android)
  | (part, (construct, apple, android)) <- Map.toList refusedParts
  , Set.member part parts
  ]
    <> [ TargetRefusal ("the foreign library \"" <> library <> "\"") libraryReason
       | library <- nub
           [ name
           | (name, version) <- libraries
           , ("/" `Text.isInfixOf` name && not (kept name))
               || maybe False (Text.isInfixOf "/") version
           ]
       ]
 where
  platform = nativeTargetPlatform target
  reasonFor apple android = case platform of
    ApplePlatform _ -> apple
    AndroidPlatform -> android
  kept library = case platform of
    ApplePlatform _ ->
      not (".." `elem` Text.splitOn "/" library)
        && any (`Text.isPrefixOf` library) appleLibraryPrefixes
    AndroidPlatform -> False
  libraryReason = case platform of
    ApplePlatform _ ->
      "an application loads only system libraries and frameworks inside its bundle; name a system library, a system framework, or an @rpath framework"
    AndroidPlatform ->
      "an application loads only libraries packaged with it; name the library without a path"
