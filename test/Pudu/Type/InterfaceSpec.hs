module Pudu.Type.InterfaceSpec (interfaceProperties) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function (..)
  , Module (..)
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Pudu.Type.Interface
  ( interfaceDeclarations
  , interfaceDefaults
  , interfacePrivateDeclarations
  , interfaceSkeleton
  )
import Pudu.Type.Interface.Graph (ImportTypes (..), importsFor, prepareInterfaces)
import Pudu.Type.Value (canonicalNominal)
import Pudu.Compiler.Program.Common (codes, runEntry)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

interfaceProperties :: [(String, IO Property)]
interfaceProperties =
  [ ("type interfaces strip executable bodies", testBodyFree)
  , ("type interfaces retain private nominal shells", testPrivateShells)
  , ("selected imports map canonical names and values", testSelectedImports)
  , ("trait defaults remain discoverable without bodies", testDefaults)
  , ("imported record fields expand later chained function aliases", testLateAliases)
  , ("a package alias cannot replace the HTTP server's Listener", testListenerIdentity)
  ]

testListenerIdentity :: IO Property
testListenerIdentity = do
  accepted <- codes "test-fixtures/listeneridentity/Main.pudu"
  reversed <- codes "test-fixtures/listeneridentity/Reverse.pudu"
  reversedResult <- runEntry "test-fixtures/listeneridentity/Reverse.pudu"
  result <- runEntry "test-fixtures/listeneridentity/Main.pudu"
  refused <- codes "test-fixtures/listeneridentity/RejectsWrongListener.pudu"
  pure $ conjoin
    [ accepted === []
    , reversed === []
    , reversedResult === Just "0"
    , result === Just "0"
    , refused === ["E3001"]
    ]

testLateAliases :: IO Property
testLateAliases = do
  accepted <- codes "test-fixtures/latealias/Main.pudu"
  result <- runEntry "test-fixtures/latealias/Main.pudu"
  refused <- codes "test-fixtures/latealias/RejectsWrongCallback.pudu"
  pure $ conjoin
    [ accepted === []
    , result === Just "0"
    , refused === ["E3001"]
    ]

testBodyFree :: IO Property
testBodyFree = withModule librarySource $ \library ->
  let declarations = interfaceDeclarations (interfaceSkeleton library)
      bodies =
        [ functionBody function
        | Located _ (FunctionDeclaration function) <- declarations
        ]
   in conjoin
        [ counterexample "only complete exported ABI declarations survive"
            (length declarations === 3)
        , counterexample "function bodies are absent" (bodies === [Nothing])
        ]

testPrivateShells :: IO Property
testPrivateShells = withModule librarySource $ \library ->
  case interfacePrivateDeclarations (interfaceSkeleton library) of
    [Located _ (TypeDeclaration _)] -> property True
    declarations -> counterexample ("unexpected private shells: " <> show declarations) False

testSelectedImports :: IO Property
testSelectedImports = withModules librarySource consumerSource $ \library consumer ->
  let interface = interfaceSkeleton library
      imports = importsFor (prepareInterfaces (Map.singleton (moduleIdentity library) interface)) consumer
   in conjoin
        [ Map.lookup "User" (importedNames imports)
            === Just (canonicalNominal (moduleIdentity library) "User")
        , Map.lookup "make" (importedValues imports) === Just "Library.make"
        , property (Map.notMember "Hidden" (importedNames imports))
        ]

testDefaults :: IO Property
testDefaults = withModule librarySource $ \library ->
  let defaults = interfaceDefaults (interfaceSkeleton library)
   in property
        (Set.member (canonicalNominal (moduleIdentity library) "Show", "show") defaults)

librarySource :: Text
librarySource =
  Text.unlines
    [ "module Library"
    , "type Hidden = { value: Int }"
    , "export type User = { name: Str }"
    , "export fn make(name: Str) -> User { User { name } }"
    , "export fn inferred(value) { value }"
    , "export trait Show {"
    , "  fn show(self: &Self) -> Str = \"user\""
    , "}"
    ]

consumerSource :: Text
consumerSource = "module Consumer\nimport Library {User, make}\n"

withModule :: Text -> (Module -> Property) -> IO Property
withModule input assertion = do
  parsed <- parse input
  pure $ maybe (counterexample "module did not parse" False) assertion parsed

withModules :: Text -> Text -> (Module -> Module -> Property) -> IO Property
withModules left right assertion = do
  leftModule <- parse left
  rightModule <- parse right
  pure $ case (leftModule, rightModule) of
    (Just first, Just second) -> assertion first second
    _ -> counterexample "modules did not parse" False

parse :: Text -> IO (Maybe Module)
parse input = do
  source <- newSource (SourceName "interface.pudu") input
  let LexResult{lexTokens} = lexSource source
      ParseResult{parseModuleValue} = parseModule source lexTokens
  pure parseModuleValue

moduleIdentity :: Module -> ModuleName
moduleIdentity = locatedValue . moduleName
