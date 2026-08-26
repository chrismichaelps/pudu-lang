module Pudu.Frontend.ParserModuleSpec (parserModuleProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (FrontendResult (..), runFrontend)
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Frontend.Parser (ParseResult (..), parseModule)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Syntax
  ( Declaration (..)
  , Function (..)
  , Import (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , Located (..)
  , Module (..)
  , Visibility (..)
  , moduleNameText
  )
import Pudu.Source (Source, SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

type Parsed = (Maybe Module, [Diagnostic])

parserModuleProperties :: [(String, IO Property)]
parserModuleProperties =
  [ ("a complete module preserves header imports and declarations", testCompleteModule)
  , ("export ownership stays with the orchestrator", testVisibility)
  , ("a missing module header yields no module", testMissingHeader)
  , ("misplaced imports are preserved with E1034", testImportOrdering)
  , ("module let and var are rejected once without cascade", testModuleBindings)
  , ("reserved and unexpected module entries recover exactly", testModuleRecovery)
  , ("every admitted declaration form parses in one module", testAllDeclarationForms)
  , ("the frontend withholds a module only when errors exist", testFrontendGating)
  ]

completeSource :: Text
completeSource =
  Text.unlines
    [ "module Core.Net"
    , "import Core.Text"
    , "import Core.Io as Io"
    , "export const MAX_RETRIES: Int = 3"
    , "export async fn fetch(url: Text) -> Response {"
    , "  let client = Io.open(url)"
    , "  client.read()"
    , "}"
    , "fn double(value: Int) -> Int = value * 2"
    ]

testCompleteModule :: IO Property
testCompleteModule = do
  result <- parse completeSource
  pure $ conjoin
    [ counterexample "diagnostics" (codes result === [])
    , moduleShape result === "Core.Net|Core.Text,Core.Io as Io|const MAX_RETRIES,fn fetch,fn double"
    ]

testVisibility :: IO Property
testVisibility = do
  result <- parse "module M\nexport const A = 1\nconst B = 2\nexport fn f() {}\nfn g() {}\n"
  pure $ conjoin
    [ codes result === []
    , visibilities result === [Exported, Private, Exported, Private]
    ]

testMissingHeader :: IO Property
testMissingHeader = do
  headerless <- parse "const A = 1\n"
  empty <- parse ""
  pure $ conjoin
    [ counterexample "headerless" (codes headerless === ["E1001"])
    , counterexample "no module node" (property (not (hasModule headerless)))
    , counterexample "empty source" (codes empty === ["E1000"])
    ]

testImportOrdering :: IO Property
testImportOrdering = do
  result <- parse "module M\nconst A = 1\nimport Core.Late\n"
  pure $ conjoin
    [ codes result === ["E1034"]
    , counterexample "the import is still recorded"
        (moduleShape result === "M|Core.Late|const A")
    ]

testModuleBindings :: IO Property
testModuleBindings = do
  moduleLet <- parse "module M\nlet value = 1\nconst A = 2\n"
  moduleVar <- parse "module M\nvar value = 1\n"
  pure $ conjoin
    [ counterexample "one rejection" (codes moduleLet === ["E1001"])
    , counterexample "the next declaration still parses"
        (moduleShape moduleLet === "M||invalid,const A")
    , counterexample "var rejection" (codes moduleVar === ["E1001"])
    ]

testModuleRecovery :: IO Property
testModuleRecovery = do
  reserved <- parse "module M\nstruct Point {}\nconst A = 1\n"
  stray <- parse "module M\n}\nconst A = 1\n"
  pure $ conjoin
    [ counterexample "reserved declaration" (codes reserved === ["E1039"])
    , counterexample "recovery keeps the next declaration"
        (moduleShape reserved === "M||invalid,const A")
    , counterexample "stray delimiter" (codes stray === ["E1038"])
    , counterexample "stray recovery keeps the next declaration"
        (moduleShape stray === "M||invalid,const A")
    ]

richSource :: Text
richSource =
  Text.unlines
    [ "module Core.Domain"
    , "import Core.Text {Builder}"
    , ""
    , "export type User = { id: Int64, mut name: Str }"
    , ""
    , "export type Outcome[T] ="
    , "  | Ok(T)"
    , "  | Err(Str)"
    , ""
    , "type Handler = fn(User) -> Outcome[User]"
    , ""
    , "export trait Show {"
    , "  fn show(self: &Self) -> Str"
    , "  fn describe(self: &Self) -> Str = \"value\""
    , "}"
    , ""
    , "impl[T] Show for Outcome[T] where T: Show {"
    , "  fn show(self: &Self) -> Str {"
    , "    match self {"
    , "      case Ok(inner) if inner.ready => inner.show()"
    , "      case Ok(_) => \"pending\""
    , "      case Err(message) => message"
    , "    }"
    , "  }"
    , "}"
    , ""
    , "export async fn run(users: List[User], retries: Int = 3) -> Outcome[User] {"
    , "  var attempts = 0"
    , "  for user in users {"
    , "    if attempts > retries {"
    , "      break"
    , "    }"
    , "    let shown = user.show()"
    , "    attempts = attempts &+ 1"
    , "  }"
    , "  while attempts > 0 {"
    , "    attempts = attempts - 1"
    , "  }"
    , "  let first = users[0]"
    , "  let loaded = fetch(first).await"
    , "  Ok(loaded?)"
    , "}"
    ]

testAllDeclarationForms :: IO Property
testAllDeclarationForms = do
  result <- parse richSource
  frontendResult <- frontend richSource
  pure $ conjoin
    [ counterexample "diagnostics" (codes result === [])
    , moduleShape result
        === "Core.Domain|Core.Text {Builder}|type User,type Outcome,type Handler,trait Show,impl,fn run"
    , counterexample "the frontend admits the module" (property (frontendHasModule frontendResult))
    ]

testFrontendGating :: IO Property
testFrontendGating = do
  valid <- frontend completeSource
  invalid <- frontend "module M\nconst A =\n"
  lexical <- frontend "module M\nconst A = §\n"
  pure $ conjoin
    [ counterexample "valid module is exposed" (property (frontendHasModule valid))
    , counterexample "parser errors withhold the module"
        (property (not (frontendHasModule invalid)))
    , counterexample "lexical errors reach the same result"
        (property (not (frontendHasModule lexical)))
    , counterexample "tokens are preserved for tooling"
        (property (not (null (frontendTokens lexical))))
    ]

parse :: Text -> IO Parsed
parse input = do
  source <- pudu input
  let LexResult{lexTokens} = lexSource source
      ParseResult{parseModuleValue, parseDiagnostics} = parseModule source lexTokens
  pure (parseModuleValue, parseDiagnostics)

frontend :: Text -> IO FrontendResult
frontend input = runFrontend <$> pudu input

pudu :: Text -> IO Source
pudu = newSource (SourceName "module.pudu")

frontendHasModule :: FrontendResult -> Bool
frontendHasModule = maybe False (const True) . frontendModule

hasModule :: Parsed -> Bool
hasModule = maybe False (const True) . fst

codes :: Parsed -> [Text]
codes (_, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

visibilities :: Parsed -> [Visibility]
visibilities (moduleValue, _) = case moduleValue of
  Nothing -> []
  Just parsed -> map declarationVisibility (moduleDeclarations parsed)

declarationVisibility :: Located Declaration -> Visibility
declarationVisibility (Located _ declaration) = case declaration of
  BindingDeclaration visibility _ _ _ _ -> visibility
  FunctionDeclaration value -> functionVisibility value
  TypeDeclaration value -> typeVisibility value
  TraitDeclaration value -> traitVisibility value
  _ -> Private

moduleShape :: Parsed -> Text
moduleShape (Nothing, _) = "none"
moduleShape (Just parsed, _) =
  Text.intercalate "|"
    [ moduleNameText (locatedValue (moduleName parsed))
    , Text.intercalate "," (map importShape (moduleImports parsed))
    , Text.intercalate "," (map declarationShape (moduleDeclarations parsed))
    ]

importShape :: Located Import -> Text
importShape (Located _ value) =
  moduleNameText (locatedValue (importModule value))
    <> maybe Text.empty (\alias -> " as " <> locatedValue alias) (importAlias value)
    <> if null (importItems value) then Text.empty
       else " {" <> Text.intercalate "," (map locatedValue (importItems value)) <> "}"

declarationShape :: Located Declaration -> Text
declarationShape (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name _ _ -> "const " <> locatedValue name
  FunctionDeclaration value -> "fn " <> locatedValue (functionName value)
  TypeDeclaration value -> "type " <> locatedValue (typeName value)
  TraitDeclaration value -> "trait " <> locatedValue (traitName value)
  ImplDeclaration _ -> "impl"
  MacroDeclaration _ -> "macro"
  InvalidDeclaration -> "invalid"
