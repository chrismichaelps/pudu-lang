{-| @Derive.Catalogue — canonical candidates and requests for one loaded graph. -}
module Pudu.Derive.Catalogue
  ( Catalogue, Candidate (..), Request (..)
  , catalogueCandidates, catalogueRequests, catalogueScopes, collectCatalogue, collectCatalogueWith
  , candidateFor
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Diagnostic
  ( Diagnostic, Severity (Error), diagnostic, mkDiagnosticCode, sortDiagnostics, withHelp )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Derive (..), DeriveRequest (..), DeriveShape (..), Module (..)
  , TypeDeclarationValue (..), TypeDefinition (..), TypeParam (..), TypeSyntax (..)
  , Visibility (Exported) )
import Pudu.Source (Span)
import Pudu.Type.Check.Import (collectImportedDeclared)
import Pudu.Type.Env (DeclaredTypes (..), evalChecker)
import Pudu.Type.Formation (collectDeclaredFrom, formBoundType)
import Pudu.Type.Interface (interfaceSkeleton)
import Pudu.Type.Interface.Graph (InterfaceGraph, importsFor, prepareInterfaces)
import Pudu.Type.Value (NominalId, Type (..), canonicalNominal)

{-| A candidate still requires generic definition admission. -}
data Candidate = Candidate
  { candidateModule :: !ModuleName
  , candidateSyntax :: !(Located Derive)
  , candidateTrait :: !Type
  }
  deriving stock (Eq, Show)

data Request = Request
  { requestModule :: !ModuleName
  , requestAnchor :: !Span
  , requestTrait :: !Type
  , requestTarget :: !Type
  , requestTraitSyntax :: !(Located TypeSyntax)
  , requestTargetSyntax :: !(Located TypeSyntax)
  , requestParameters :: ![Located TypeParam]
  , requestDeclaration :: !TypeDeclarationValue
  , requestDeclarationModule :: !ModuleName
  , requestShape :: !DeriveShape
  }
  deriving stock (Eq, Show)

data Catalogue = Catalogue
  { catalogueCandidates :: !(Map (NominalId, DeriveShape) Candidate)
  , catalogueRequests :: ![Request]
  , catalogueScopes :: !(Map ModuleName DeclaredTypes)
  }

collectCatalogue :: Map ModuleName Module -> (Catalogue, [Diagnostic])
collectCatalogue modules = collectCatalogueWith
  (prepareInterfaces (Map.map interfaceSkeleton modules)) modules

collectCatalogueWith :: InterfaceGraph -> Map ModuleName Module -> (Catalogue, [Diagnostic])
collectCatalogueWith graph modules =
  let scopes = Map.map (\unit -> evalChecker $ do
        imported <- collectImportedDeclared (importsFor graph unit)
        collectDeclaredFrom imported (locatedValue (moduleName unit)) (moduleDeclarations unit)) modules
      aggregates = Map.fromList
        [ (canonicalNominal owner (locatedValue (typeName value)), (owner, value))
        | (owner, unit) <- Map.toAscList modules
        , Located _ (TypeDeclaration value) <- moduleDeclarations unit
        , Just _ <- [shapeOf value]
        ]
      definitions = concatMap (definitionsOf scopes) (Map.toAscList modules)
      (candidates, _, definitionErrors) = foldl' insertCandidate (Map.empty, Set.empty, []) definitions
      requests = concatMap (requestsOf scopes aggregates) (Map.toAscList modules)
      admitted = [value | Right value <- requests]
      diagnostics = definitionErrors <> concat [errors | Left errors <- requests]
   in (Catalogue candidates admitted scopes, sortDiagnostics diagnostics)

candidateFor :: Catalogue -> Request -> Maybe Candidate
candidateFor catalogue request = do
  owner <- traitOwner (requestTrait request)
  selected <- Map.lookup (owner, requestShape request) (catalogueCandidates catalogue)
  if candidateModule selected == requestModule request
       || deriveVisibility (locatedValue (candidateSyntax selected)) == Exported
    then Just selected else Nothing

definitionsOf :: Map ModuleName DeclaredTypes -> (ModuleName, Module) -> [(Maybe (NominalId, DeriveShape), Candidate)]
definitionsOf scopes (owner, unit) =
  [ (key, Candidate owner (Located at value) formed)
  | Located at (DeriveDeclaration value) <- moduleDeclarations unit
  , let scope = scopes Map.! owner
        formed = formBoundType scope [(locatedValue (deriveParameter value), 0)] (deriveTrait value)
        key = (, locatedValue (deriveShape value)) <$> admittedTrait scope formed
  ]

insertCandidate
  :: (Map (NominalId, DeriveShape) Candidate, Set.Set (NominalId, DeriveShape), [Diagnostic])
  -> (Maybe (NominalId, DeriveShape), Candidate)
  -> (Map (NominalId, DeriveShape) Candidate, Set.Set (NominalId, DeriveShape), [Diagnostic])
insertCandidate previous@(known, ambiguous, errors) (key, value) = case key of
  Nothing -> previous -- The definition checker reports invalid trait contracts.
  Just identity | Map.member identity known || Set.member identity ambiguous ->
    (Map.delete identity known, Set.insert identity ambiguous,
      refusal (locatedSpan (candidateSyntax value))
        "a derive strategy already exists for this canonical trait and shape" <> errors)
  Just identity -> (Map.insert identity value known, ambiguous, errors)

requestsOf
  :: Map ModuleName DeclaredTypes -> Map NominalId (ModuleName, TypeDeclarationValue)
  -> (ModuleName, Module) -> [Either [Diagnostic] Request]
requestsOf scopes aggregates (owner, unit) = concatMap one (moduleDeclarations unit)
 where
  scope = scopes Map.! owner
  one (Located at declaration) = case declaration of
    TypeDeclaration value -> inline value Set.empty (typeDerives value)
    DeriveImplDeclaration value ->
      [request at [] (deriveRequestTrait value) (deriveRequestTarget value)]
    _ -> []
  inline _ _ [] = []
  inline value seen (trait : rest) =
    let params = typeTypeParams value
        formed = formBoundType scope (parameterEntries params) trait
        writtenTarget = Located (locatedSpan (typeName value))
          (NamedType (ModuleName (locatedValue (typeName value) :| []))
            [Located (locatedSpan (typeParamName held))
              (NamedType (ModuleName (locatedValue (typeParamName held) :| [])) [])
            | Located _ held <- params])
        identity = traitOwner formed
        repeated = maybe False (`Set.member` seen) identity
        current = if repeated then Left (refusal (locatedSpan trait)
          "this type requests the same canonical trait more than once")
          else request (locatedSpan trait) params trait writtenTarget
        after = maybe seen (`Set.insert` seen) identity
     in current : inline value after rest
  request at params trait target = do
    let rigid = parameterEntries params
        formedTrait = formBoundType scope rigid trait
        formedTarget = formBoundType scope rigid target
    case admittedTrait scope formedTrait of
      Nothing -> Left (refusal (locatedSpan trait) "a derive request must name a trait with its complete arguments")
      Just _ -> pure ()
    case formedTarget of
      NominalType identity arguments -> case Map.lookup identity aggregates of
        Just (declaring, value)
          | length arguments == length (typeTypeParams value)
          , Just shape <- shapeOf value -> Right
              (Request owner at formedTrait formedTarget trait target params value declaring shape)
        _ -> invalidTarget
      _ -> invalidTarget
   where
    invalidTarget = Left (refusal (locatedSpan target)
      "a derive request needs a fully applied record or sum type")

parameterEntries :: [Located TypeParam] -> [(Text, Int)]
parameterEntries = map (\(Located _ value) -> (locatedValue (typeParamName value), typeParamArity value))

admittedTrait :: DeclaredTypes -> Type -> Maybe NominalId
admittedTrait scope value = case value of
  NominalType owner arguments
    | Set.member owner (declaredTraitNames scope)
    , length arguments == length (Map.findWithDefault [] owner (declaredKinds scope)) -> Just owner
  _ -> Nothing

traitOwner :: Type -> Maybe NominalId
traitOwner (NominalType owner _) = Just owner
traitOwner _ = Nothing

shapeOf :: TypeDeclarationValue -> Maybe DeriveShape
shapeOf value = case locatedValue (typeDefinition value) of
  RecordDefinition _ -> Just RecordShape
  SumDefinition _ -> Just SumShape
  _ -> Nothing

refusal :: Span -> Text -> [Diagnostic]
refusal at message = case mkDiagnosticCode "E3091" >>= \code -> diagnostic code Error at message of
  Nothing -> []
  Just value -> [withHelp "select one valid derive strategy for the canonical trait and target shape" value]
