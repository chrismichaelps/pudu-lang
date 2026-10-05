{-| @Test.Derive.TargetSpec — actual aggregate arguments and complete type reconstruction. -}
module Pudu.Derive.TargetSpec (targetProperties) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Compiler (FrontendResult (..), runFrontend)
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Derive.Catalogue
  ( Request (..), candidateFor, catalogueRequests, catalogueScopes, collectCatalogue )
import Pudu.Derive.State (runResidual)
import Pudu.Derive.Target (acceptsApplication, prepareTarget, reifyType)
import Pudu.Diagnostic (hasErrors)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( Module (..), TypeDeclarationValue (..), TypeDefinition (..), FieldDeclaration (..)
  , TypeParam (..), Variant (..), VariantPayload (..), Capability (RawCapability) )
import Pudu.Source (SourceName (..), emptySpan, newSource, spanOrigin)
import Pudu.Type.Formation (formBoundType)
import Pudu.Type.Value
  ( Type (..), TypeVar (..), Required (..), canonicalNominal, integerType, boolType, restrictedBy )
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

targetProperties :: [(String, IO Property)]
targetProperties =
  [ ("derive targets apply actual record and sum arguments", targetApplications)
  , ("derive targets preserve structured types and refuse erased contracts", reconstruction)
  ]

targetApplications :: IO Property
targetApplications = do
  modules <- units
    [ ("Strategy", "module Strategy\nexport trait Label[A] {}\nexport derive Label[Int] for T: Record {}\nexport derive Label[Int] for T: Sum {}")
    , ("Shapes", "module Shapes\nexport type Box[A] = {@wire(\"name\") mut value: A}\nexport type Choice[A] = None | Tuple(A, Bool) | Named{value: A}")
    , ("Consumer", "module Consumer\nimport Strategy\nimport Shapes\ntype Alias = Shapes.Box[Int]\nderive impl Strategy.Label[Int] for Alias\nderive impl Strategy.Label[Int] for Shapes.Choice[Bool]\ntype Generic[A] = {value: A} derives Strategy.Label[Int]\nderive impl Strategy.Label[Bool] for Alias")
    ]
  let (catalogue, errors) = collectCatalogue modules
      scopes = catalogueScopes catalogue
      requests = catalogueRequests catalogue
      prepare request = runResidual (requestAnchor request)
        (prepareTarget (scopes Map.! requestDeclarationModule request) request)
      payloadTypes request prepared =
        let scope = scopes Map.! requestModule request
            rigid = [(locatedValue (typeParamName value), typeParamArity value)
              | Located _ value <- typeTypeParams prepared]
            field (Located _ value) = formBoundType scope rigid (fieldType value)
         in case locatedValue (typeDefinition prepared) of
              RecordDefinition fields -> map field fields
              SumDefinition variants -> concatMap (\(Located _ value) -> case variantPayload value of
                UnitPayload -> []
                TuplePayload members -> map (formBoundType scope rigid) members
                RecordPayload fields -> map field fields) variants
              _ -> []
      result request = case prepare request of
        Right (value, []) -> Right (payloadTypes request value, length (typeTypeParams value))
        other -> Left (show other)
      selected request = maybe False (`acceptsApplication` request) (candidateFor catalogue request)
      recordAnchors prepared = case locatedValue (typeDefinition prepared) of
        RecordDefinition fields -> all ((== Nothing) . spanOrigin . locatedSpan) fields
        _ -> True
      exactFields request = case (locatedValue (typeDefinition (requestDeclaration request)), prepare request) of
        (RecordDefinition originals, Right (value, _)) -> case locatedValue (typeDefinition value) of
          RecordDefinition fields ->
            [(locatedSpan field, fieldName held, fieldMutable held, fieldAttributes held)
            | field@(Located _ held) <- fields] ==
            [(locatedSpan field, fieldName held, fieldMutable held, fieldAttributes held)
            | field@(Located _ held) <- originals]
          _ -> False
        _ -> True
  pure $ counterexample (show errors) $ conjoin
    [ property (not (hasErrors errors))
    , map result requests ===
        [Right ([integerType], 0), Right ([boolType, boolType, boolType], 0),
         Right ([RigidType "A"], 1), Right ([integerType], 0)]
    , map selected requests === [True, True, True, False]
    , property (all (\request -> case prepare request of
        Right (value, _) -> recordAnchors value
        _ -> False) requests)
    , property (all exactFields requests)
    ]

reconstruction :: IO Property
reconstruction = do
  source <- newSource (SourceName "Types.pudu") "module Types\ntrait Ready {}\ntype Box[A] = {value: A}"
  modules <- units [("Types", "module Types\ntrait Ready {}\ntype Box[A] = {value: A}")]
  let (catalogue, _) = collectCatalogue modules
      scope = snd (Map.findMin (catalogueScopes catalogue))
      owner = fst (Map.findMin modules)
      at = emptySpan source
      examples =
        [ integerType, ReferenceTypeValue True integerType
        , TupleTypeValue [boolType, ReferenceTypeValue False integerType]
        , FunctionTypeValue True [integerType] boolType
        , restrictedBy (Just [RawCapability]) (FunctionTypeValue False [integerType] integerType)
        , AppliedType (RigidType "F") [integerType]
        , NominalType (canonicalNominal owner "Box") [integerType]
        , DynamicTypeValue (canonicalNominal owner "Ready")
        , UnitTypeValue, NeverType
        ]
      roundTrip value = case runResidual at (reifyType 0 at value) of
        Right (written, []) -> formBoundType scope [("F", 1)] written === value
        failure -> counterexample (show failure) False
      refused value = case runResidual at (reifyType 0 at value) of Left _ -> True; _ -> False
  pure $ conjoin (map roundTrip examples <>
    [ property (refused ErrorType)
    , property (refused (VariableType (TypeVar 0)))
    , property (refused (FunctionTypeRequiring False [integerType, integerType] (Required 1) integerType))
    , property (case runResidual at (reifyType callDepthLimit at integerType) of Left _ -> True; _ -> False)
    ])

units :: [(Text, Text)] -> IO (Map.Map ModuleName Module)
units values = Map.fromList <$> mapM parse values
 where
  parse (name, contents) = do
    source <- newSource (SourceName (name <> ".pudu")) contents
    case runFrontend source of
      FrontendResult{frontendModule = Just value, frontendDiagnostics}
        | not (hasErrors frontendDiagnostics) -> pure (locatedValue (moduleName value), value)
      result -> fail ("target fixture failed to parse: " <> show result)
