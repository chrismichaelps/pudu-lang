{-| @Test.Derive.CatalogueSpec — canonical graph inventory and admission refusals. -}
module Pudu.Derive.CatalogueSpec (catalogueProperties) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler (FrontendResult (..), runFrontend)
import Pudu.Derive.Catalogue
  ( Candidate (..), Request (..), candidateFor, catalogueCandidates
  , catalogueRequests, collectCatalogue )
import Pudu.Diagnostic (diagnosticMessage, hasErrors)
import Pudu.Derive.Definition (validateDefinitions, validatedCandidate)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree (Module (..), TypeParam (..))
import Pudu.Source (SourceName (..), newSource)
import Pudu.Semantic (exportIndex)
import Pudu.Type.Interface (interfaceSkeleton)
import Pudu.Type.Interface.Graph (prepareInterfaces)
import Pudu.Type.Value (Type (..), nominalKey)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

catalogueProperties :: [(String, IO Property)]
catalogueProperties =
  [ ("derive catalogue canonicalizes aliases and generic targets", canonicalRequests)
  , ("derive catalogue distinguishes shapes and private strategies", shapesAndVisibility)
  , ("derive catalogue refuses duplicate and malformed requests", refusals)
  , ("derive definitions admit once before ordinary bodies", definitionAdmission)
  ]

canonicalRequests :: IO Property
canonicalRequests = do
  modules <- units
    [ ("Strategy", "module Strategy\nexport trait Label {}\nexport derive Label for T: Record {}")
    , ("Consumer", "module Consumer\nimport Strategy as S\nimport Strategy {Label}\ntype Box[A] = {value: A} derives S.Label\ntype Alias = Box[Int]\nderive impl Label for Alias")
    ]
  let (catalogue, diagnostics) = collectCatalogue modules
      requests = catalogueRequests catalogue
      target (NominalType owner arguments) = (nominalKey owner, arguments)
      target other = ("unexpected", [other])
  pure $ counterexample (show diagnostics) $ conjoin
    [ property (not (hasErrors diagnostics))
    , map (target . requestTrait) requests === [("Strategy.Label", []), ("Strategy.Label", [])]
    , map (target . requestTarget) requests ===
        [("Consumer.Box", [RigidType "A"]), ("Consumer.Box", [NominalType "Int" []])]
    , map (map (locatedValue . typeParamName . locatedValue) . requestParameters) requests === [["A"], []]
    , map (fmap (moduleNameText . candidateModule) . candidateFor catalogue) requests ===
        [Just "Strategy", Just "Strategy"]
    ]

shapesAndVisibility :: IO Property
shapesAndVisibility = do
  modules <- units
    [ ("Strategy", "module Strategy\nexport trait Label {}\nderive Label for T: Record {}\nexport derive Label for T: Sum {}\ntype Local = {value: Int} derives Label")
    , ("Consumer", "module Consumer\nimport Strategy\ntype Record = {value: Int} derives Strategy.Label\ntype Sum = Left | Right derives Strategy.Label")
    ]
  let (catalogue, diagnostics) = collectCatalogue modules
      selected = [fmap (moduleNameText . candidateModule) (candidateFor catalogue request)
        | request <- catalogueRequests catalogue]
  pure $ counterexample (show diagnostics) $ conjoin
    [ property (not (hasErrors diagnostics))
    , Map.size (catalogueCandidates catalogue) === 2
    , selected === [Nothing, Just "Strategy", Just "Strategy"]
    ]

refusals :: IO Property
refusals = do
  results <- mapM one
    [ ("duplicate alias request", "import Strategy as S\nimport Strategy {Label}\ntype Box = {value: Int} derives S.Label, Label", "same canonical trait")
    , ("trait arity", "import Strategy\ntype Box = {value: Int} derives Strategy.Label[Int]", "complete arguments")
    , ("scalar target", "import Strategy\nderive impl Strategy.Label for Int", "fully applied record or sum")
    , ("unsaturated target", "import Strategy\ntype Box[A] = {value: A}\nderive impl Strategy.Label for Box", "fully applied record or sum")
    ]
  duplicate <- units
    [ ("Strategy", "module Strategy\nexport trait Label {}\nexport derive Label for T: Record {}")
    , ("Other", "module Other\nimport Strategy\nexport derive Strategy.Label for T: Record {}")
    ]
  let (ambiguous, diagnostics) = collectCatalogue duplicate
  pure (conjoin
    ( (Map.size (catalogueCandidates ambiguous) === 0)
    : property (any ((== "a derive strategy already exists for this canonical trait and shape") . diagnosticMessage) diagnostics)
    : results))
 where
  one :: (String, Text, Text) -> IO Property
  one (label, body, expected) = do
    modules <- units
      [ ("Strategy", "module Strategy\nexport trait Label {}\nexport derive Label for T: Record {}")
      , ("Consumer", "module Consumer\n" <> body)
      ]
    let (_, diagnostics) = collectCatalogue modules
    pure $ counterexample (label <> ": " <> show diagnostics) $
      map diagnosticMessage diagnostics === [case expected of
        "same canonical trait" -> "this type requests the same canonical trait more than once"
        "complete arguments" -> "a derive request must name a trait with its complete arguments"
        _ -> "a derive request needs a fully applied record or sum type"]

units :: [(Text, Text)] -> IO (Map.Map ModuleName Module)
units values = Map.fromList <$> mapM parse values
 where
  parse (name, contents) = do
    source <- newSource (SourceName (name <> ".pudu")) contents
    case runFrontend source of
      FrontendResult{frontendModule = Just value, frontendDiagnostics}
        | not (hasErrors frontendDiagnostics) -> pure (locatedValue (moduleName value), value)
      result -> fail ("catalogue fixture failed to parse: " <> show result)

definitionAdmission :: IO Property
definitionAdmission = conjoin <$> mapM check
  [ ("generic body refusal", "trait Label {fn label(self: &Self) -> Str}\nderive Label for T: Record {fn label(self: &T) -> Str = false}", False)
  , ("local defaults", "trait Label {fn label(self: &Self) -> Str = \"default\"}\nderive Label for T: Record {}", True)
  , ("unused valid template", "trait Label {fn label(self: &Self) -> Str}\nderive Label for T: Record {fn label(self: &T) -> Str = \"label\"}", True)
  ]
 where
  check (label, body, expected) = do
    modules <- units [("Probe", "module Probe\n" <> body <>
      "\nfn ordinary() -> Int = true\nfn unresolved() -> Int = missing\nconst BAD: Int = false\ntype First = {value: Int} derives Label\ntype Second = {value: Bool} derives Label")]
    let (catalogue, inventoryErrors) = collectCatalogue modules
        graph = prepareInterfaces (Map.map interfaceSkeleton modules)
        (validated, findings) = validateDefinitions catalogue graph (exportIndex modules) modules
        errors = concat (Map.elems findings)
        admitted request = case validatedCandidate validated request of Just _ -> True; Nothing -> False
    pure $ counterexample (label <> ": " <> show errors) $ conjoin
      [ property (not (hasErrors inventoryErrors))
      , length errors === if expected then 0 else 1
      , map admitted (catalogueRequests catalogue) === replicate 2 expected
      ]
