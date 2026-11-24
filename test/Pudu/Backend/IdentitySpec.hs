{-| @Test.Backend.IdentitySpec — an application's identity from the
    manifest's `[app]` table, the values refused, and where each lands. -}
module Pudu.Backend.IdentitySpec (identityProperties) where

import qualified Data.Text as Text
import Pudu.Backend.Identity (Identity (..), IdentityProblem (..), defaultIdentity, settleIdentity)
import Pudu.Backend.Toolchain.Android (packageManifest)
import Pudu.Backend.Toolchain.App (infoPlist)
import Pudu.Compiler.Manifest (manifestApp, parseManifest)
import Test.QuickCheck (Property, conjoin, counterexample, once, (===))

identityProperties :: [(String, IO Property)]
identityProperties =
  [ ("the manifest's [app] table settles over the defaults", pure (once settled))
  , ("identifiers, versions, builds and schemes a store would refuse are refused", pure (once refused))
  , ("the property list and package manifest carry the identity and the schemes", pure (once written))
  ]

declared :: Identity
declared = case settleIdentity (defaultIdentity "Links" "org.pudu.Links") (manifestApp (parseManifest table)) of
  Right identity -> identity
  Left problems -> error (show problems)
 where
  table = "[app]\nname = \"Pudu Links\"\nidentifier = \"dev.pudu.my-links\"\nversion = \"2.3.1\"\nbuild = 42\nschemes = [\"PuduLinks\", \"pudu+x\"]\n"

settled :: Property
settled = conjoin
  [ declared === Identity "Pudu Links" "dev.pudu.my-links" "2.3.1" 42 ["pudulinks", "pudu+x"] True
  , settleIdentity (defaultIdentity "A" "org.pudu.A") [] === Right (defaultIdentity "A" "org.pudu.A")
  ]

refused :: Property
refused =
  let entries = [("identifier", "\"app\"", 2), ("version", "\"1.2.3.4\"", 3), ("build", "0", 4), ("schemes", "[\"1x\"]", 5), ("color", "\"red\"", 6)]
   in case settleIdentity (defaultIdentity "A" "org.pudu.A") entries of
        Left problems -> map (\problem -> (problemKey problem, problemLine problem)) problems
          === [("identifier", 2), ("version", 3), ("build", 4), ("schemes", 5), ("color", 6)]
        Right identity -> counterexample ("accepted " <> show identity) False

written :: Property
written =
  let plist = infoPlist "Links" declared []
      manifest = packageManifest False "Links" declared []
      plain = packageManifest False "Counter" (defaultIdentity "Counter" "org.pudu.Counter") []
   in conjoin
        [ counterexample (Text.unpack plist) (all (`Text.isInfixOf` plist)
            [ "<key>CFBundleIdentifier</key><string>dev.pudu.my-links</string>"
            , "<key>CFBundleDisplayName</key><string>Pudu Links</string>"
            , "<key>CFBundleShortVersionString</key><string>2.3.1</string>"
            , "<key>CFBundleVersion</key><string>42</string>"
            , "<string>pudulinks</string><string>pudu+x</string>" ])
        , counterexample (Text.unpack manifest) (all (`Text.isInfixOf` manifest)
            [ "package=\"dev.pudu.my_links\"", "android:versionCode=\"42\"", "android:versionName=\"2.3.1\""
            , "android:label=\"Pudu Links\"", "<data android:scheme=\"pudulinks\" />", "android:launchMode=\"singleTask\"" ])
        , counterexample (Text.unpack plain) ("package=\"org.pudu.counter\"" `Text.isInfixOf` plain && not ("PUDU_" `Text.isInfixOf` plain))
        ]
