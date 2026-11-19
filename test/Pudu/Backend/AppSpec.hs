{-| @Test.Backend.AppSpec — the identity and property list of a simulator
    application built by `pudu build --app`. -}
module Pudu.Backend.AppSpec (appProperties) where

import qualified Data.Text as Text
import Pudu.Backend.Toolchain.App (bundleIdentifier, infoPlist)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

appProperties :: [(String, IO Property)]
appProperties =
  [ ("application identifiers derive from the program's name", pure testIdentifier)
  , ("application property lists name the bundle and escape their text", pure testPlist)
  ]

testIdentifier :: Property
testIdentifier = conjoin
  [ bundleIdentifier "Counter" === "org.pudu.Counter"
  , bundleIdentifier "my-app.v2" === "org.pudu.my-app.v2"
  , bundleIdentifier "Café Lists" === "org.pudu.Caf--Lists"
  ]

testPlist :: Property
testPlist =
  let plist = infoPlist "A&B" "org.pudu.A-B" []
      has fragment = counterexample (Text.unpack fragment) (property (fragment `Text.isInfixOf` plist))
   in conjoin
        [ has "<key>CFBundleIdentifier</key><string>org.pudu.A-B</string>"
        , has "<key>CFBundleExecutable</key><string>A&amp;B</string>"
        , has "<key>CFBundlePackageType</key><string>APPL</string>"
        , has "<key>MinimumOSVersion</key><string>15.0</string>"
        , has "<string>iPhoneSimulator</string>"
        , has "<key>UILaunchScreen</key><dict/>"
        , has "<key>CADisableMinimumFrameDurationOnPhone</key><true/>"
        , counterexample "an unescaped ampersand" (property (not ("A&B<" `Text.isInfixOf` plist)))
        ]
