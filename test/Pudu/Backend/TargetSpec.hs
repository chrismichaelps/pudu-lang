{-| @Test.Backend.TargetSpec — native target names and foreign library paths. -}
module Pudu.Backend.TargetSpec (backendTargetProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Backend.Target (NativeTarget, TargetRefusal (..), nativeTargetNamed, nativeTargetNames, targetRefusals)
import Test.QuickCheck (Property, conjoin, counterexample, once, (===))

backendTargetProperties :: [(String, IO Property)]
backendTargetProperties =
  [("mobile targets select library paths and refuse escapes", pure (once targetPaths))]

targetPaths :: Property
targetPaths = withTarget "ios-simulator-arm64" $ \ios ->
  withTarget "android-arm64" $ \android ->
    conjoin
      [ nativeTargetNames === ["android-arm64", "android-x86_64", "ios-arm64", "ios-simulator-arm64"]
      , nativeTargetNamed "linux-musl-x86_64" === Nothing
      , nativeTargetNamed "ios" === Nothing
      , targetRefusals ios Set.empty (unversioned ["c", "sqlite3", framework, bundled]) === []
      , map refusedConstruct (targetRefusals ios Set.empty [("sqlite3", Just "../../external")]) === [label "sqlite3"]
      , refused ios [outside, outside, traversal] === [label outside, label traversal]
      , refused android ["sqlite3", framework, bundled] === [label framework, label bundled]
      ]
 where
  framework = "/System/Library/Frameworks/Foo.framework/Foo"
  bundled = "@rpath/Foo.framework/Foo"
  outside = "/tmp/libfoo.dylib"
  traversal = "@executable_path/../../libfoo.dylib"
  label library = "the foreign library \"" <> library <> "\""
  unversioned = map (, Nothing)
  refused target = map refusedConstruct . targetRefusals target Set.empty . unversioned

withTarget :: Text -> (NativeTarget -> Property) -> Property
withTarget name test = maybe (counterexample ("missing target " <> show name) False) test (nativeTargetNamed name)
