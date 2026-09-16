module Pudu.Type.Check.ImportSpec (importTypeProperties) where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Pudu.Compiler (FrontendResult (..), runFrontend)
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticMessage)
import Pudu.Frontend.Syntax.Located (locatedValue)
import Pudu.Frontend.Syntax.Tree (Module (..))
import Pudu.Source (SourceName (SourceName), newSource)
import Pudu.Type (checkTypesWith)
import Pudu.Type.Interface (importsFor, interfaceSkeleton)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

importTypeProperties :: [(String, IO Property)]
importTypeProperties =
  [ ("imported functions retain their ABI types", testImportedFunction)
  , ("trait selection controls imported methods", testTraitSelection)
  , ("imported defaults survive body stripping", testImportedDefault)
  , ("imported and local methods diagnose ambiguity", testMixedAmbiguity)
  , ("same-spelling nominal mismatches name both modules", testQualifiedMismatch)
  ]

testImportedFunction :: IO Property
testImportedFunction = do
  accepted <- checked [functionLibrary] (consumer "size" ["fn run() -> Int { size(\"pudu\") }"])
  rejected <- checked [functionLibrary] (consumer "size" ["fn run() -> Int { size(1) }"])
  pure $ conjoin
    [ accepted === []
    , counterexample "the imported parameter type is enforced" (rejected === ["E3001"])
    ]

testTraitSelection :: IO Property
testTraitSelection = do
  visible <- checked [methodLibrary] (consumer "User, Show" [runShow])
  hidden <- checked [methodLibrary] (consumer "User" [runShow])
  pure $ conjoin
    [ visible === []
    , counterexample "a trait outside import scope provides no methods" (hidden === ["E3005"])
    ]

testImportedDefault :: IO Property
testImportedDefault =
  (=== []) <$> checked [defaultLibrary] (consumer "User, Show" [runShow])

testMixedAmbiguity :: IO Property
testMixedAmbiguity = do
  diagnostics <- checked [methodLibrary] $ consumer "User, Show"
    [ "trait Label { fn show(self: &Self) -> Str }"
    , "impl Label for User { fn show(self: &Self) -> Str = \"local\" }"
    , runShow
    ]
  pure $ counterexample "import order must not choose a method" (diagnostics === ["E3013"])

testQualifiedMismatch :: IO Property
testQualifiedMismatch = do
  diagnostics <- checkedDiagnostics [firstUser, secondUser] $ Text.unlines
    [ "module Consumer"
    , "import First as A"
    , "import Second as B"
    , "fn convert(value: A.User) -> B.User { value }"
    ]
  pure $ map diagnosticMessage diagnostics
    === ["expected Second.User, found First.User"]

functionLibrary :: Text
functionLibrary = Text.unlines
  [ "module Library"
  , "export fn size(value: Str) -> Int { 4 }"
  ]

methodLibrary :: Text
methodLibrary = Text.unlines
  [ "module Library"
  , "export type User = { name: Str }"
  , "export trait Show { fn show(self: &Self) -> Str }"
  , "impl Show for User { fn show(self: &Self) -> Str { self.name } }"
  ]

defaultLibrary :: Text
defaultLibrary = Text.unlines
  [ "module Library"
  , "export type User = { name: Str }"
  , "export trait Show { fn show(self: &Self) -> Str = \"default\" }"
  , "impl Show for User {}"
  ]

firstUser, secondUser :: Text
firstUser = "module First\nexport type User = { first: Int }\n"
secondUser = "module Second\nexport type User = { second: Int }\n"

runShow :: Text
runShow = "fn run(user: User) -> Str { user.show() }"

consumer :: Text -> [Text] -> Text
consumer selected body =
  Text.unlines ("module Consumer" : ("import Library {" <> selected <> "}") : body)

checked :: [Text] -> Text -> IO [Text]
checked dependencySources consumerSource = do
  diagnostics <- checkedDiagnostics dependencySources consumerSource
  pure (map (diagnosticCodeText . diagnosticCode) diagnostics)

checkedDiagnostics :: [Text] -> Text -> IO [Diagnostic]
checkedDiagnostics dependencySources consumerSource = do
  dependencies <- traverse parsed dependencySources
  consumerModule <- parsed consumerSource
  let interfaces = map interfaceSkeleton dependencies
      available = Map.fromList [(locatedValue (moduleName value), interface) | (value, interface) <- zip dependencies interfaces]
      imported = importsFor available consumerModule
      (_, diagnostics) = checkTypesWith imported consumerModule
  pure diagnostics

parsed :: Text -> IO Module
parsed input = do
  source <- newSource (SourceName "import-types.pudu") input
  let FrontendResult{frontendModule} = runFrontend source
  maybe (fail "type-import fixture did not parse") pure frontendModule
