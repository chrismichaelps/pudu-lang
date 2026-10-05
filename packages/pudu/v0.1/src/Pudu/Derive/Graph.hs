{-| @Derive.Graph — admits definition-scoped generated evidence before body checking. -}
module Pudu.Derive.Graph (elaborateGraph) where

import Data.List (nub)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Comptime.Limits (callDepthLimit, iterationLimit)
import Pudu.Derive.Catalogue
  ( Candidate (..), Catalogue, Request (..), catalogueRequests, catalogueScopes, collectCatalogueWith )
import Pudu.Derive.Coherence (generatedCoherence, requestOwnership)
import Pudu.Derive.Definition
  ( ValidatedDefinitions, definitionCandidate, definitionReflection, validateDefinitions, validatedCandidate )
import Pudu.Derive.Record (instantiateAggregateIn)
import Pudu.Derive.State
  ( ExpansionFailure (..), FieldObligation (..), refuse, runResidual )
import qualified Pudu.Derive.State as Residual
import Pudu.Derive.Target (acceptsApplication, prepareTarget, reifyType)
import Pudu.Diagnostic
  ( Diagnostic, Related (..), Severity (Error), diagnostic, diagnosticSpan, hasErrors
  , mkDiagnosticCode, sortDiagnostics, withRelated )
import Pudu.Frontend.Expand (expandModule)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Impl (..), Module (..), TypeDeclarationValue (..), TypeParam (..) )
import Pudu.Semantic (exportIndex)
import Pudu.Source (Span, authoredSpan, sameSpanSource)
import Pudu.Type.Env (DeclaredTypes (..), evalChecker, withDeclared, withRigidBounds)
import Pudu.Type.Formation (formBoundFor, formBoundType)
import Pudu.Type.Interface (interfaceSkeleton)
import Pudu.Type.Interface.Graph (graphDeclared, prepareInterfaces)
import Pudu.Type.Proof (TraitProof (..), deriveRequirements)
import Pudu.Type.Value (Type, renderType)

type Findings = Map ModuleName [Diagnostic]
type Bounds = [(Text, [Type])]

data Generated = Generated
  { generatedRequest :: !Request
  , generatedOwner :: !ModuleName
  , generatedDeclaration :: !(Located Declaration)
  , generatedImplementation :: !Impl
  , generatedObligations :: ![FieldObligation]
  , generatedBounds :: !Bounds
  }

elaborateGraph :: Map ModuleName Module -> (Map ModuleName Module, Findings)
elaborateGraph modules
  | not (any containsDerive (Map.elems modules)) = (modules, Map.empty)
  | failed expansionErrors = (expanded, expansionErrors)
  | failed definitionErrors = (expanded, combine expansionErrors definitionErrors)
  | hasErrors catalogueErrors = (expanded, combine expansionErrors (partitionFindings expanded catalogueErrors))
  | failed ownershipErrors = (expanded, combine expansionErrors ownershipErrors)
  | otherwise = case buildAll Map.empty of
      Left errors -> (expanded, combine expansionErrors errors)
      Right initial
        | failed (coherence initial) -> (expanded, combine expansionErrors (coherence initial))
        | otherwise -> case settle 0 iterationLimit Map.empty initial of
            Left errors -> (expanded, combine expansionErrors errors)
            Right settled -> (publish settled, combine expansionErrors definitionErrors)
 where
  products = Map.map expandModule modules
  expanded = Map.map fst products
  expansionErrors = Map.map snd products
  interfaces = prepareInterfaces (Map.map interfaceSkeleton expanded)
  (catalogue, catalogueErrors) = collectCatalogueWith interfaces expanded
  (definitions, definitionErrors) = validateDefinitions catalogue interfaces (exportIndex expanded) expanded
  requests = catalogueRequests catalogue
  ownershipErrors = Map.fromListWith (<>)
    [(requestModule request, requestOwnership request) | request <- requests]
  scopes = catalogueScopes catalogue
  buildAll extra = gather expanded
    [(request, buildRequest catalogue definitions request
      (Map.findWithDefault [] (requestAnchor request) extra)) | request <- requests]
  coherence generated = generatedCoherence scopes expanded
    [(generatedRequest value, generatedImplementation value) | value <- generated]
  publish generated = Map.mapWithKey append (Map.map executable expanded)
   where
    append owner unit = unit{moduleDeclarations = moduleDeclarations unit <>
      [generatedDeclaration value | value <- generated, generatedOwner value == owner]}
  settle rounds fuel previous generated
    | rounds >= callDepthLimit || fuel <= 0 = Left (budget requests)
    | otherwise =
        let graph = prepareInterfaces (Map.map interfaceSkeleton (publish generated))
            requirements = [(value, infer (graphDeclared graph) value) | value <- generated]
            errors = Map.fromListWith (<>)
              [(requestModule (generatedRequest value), diagnostics) | (value, (_, diagnostics)) <- requirements]
            next = Map.fromList
              [(requestAnchor (generatedRequest value), mergeBounds
                (Map.findWithDefault [] (requestAnchor (generatedRequest value)) previous) bounds)
              | (value, (bounds, _)) <- requirements]
            visits = sum [max 1 (sum (map (length . obligationBounds) (generatedObligations value)))
              | value <- generated]
         in if failed errors then Left errors else if next == previous || null generated
              then Right generated
              else buildAll next >>= settle (rounds + 1) (fuel - visits) next
  infer declared value =
    let request = generatedRequest value
        own = scopes Map.! generatedOwner value
        -- Field types are canonical, written for any module, so the graph's
        -- qualified names extend the defining scope; its own names still win.
        scope = own
          { declaredImpls = declaredImpls declared
          , declaredNames = Map.union (declaredNames own) (declaredNames declared)
          , declaredParams = Map.union (declaredParams own) (declaredParams declared)
          , declaredKinds = Map.union (declaredKinds own) (declaredKinds declared)
          , declaredTraitNames = Set.union (declaredTraitNames own) (declaredTraitNames declared)
          }
        rigid = parameterEntries (implTypeParams (generatedImplementation value))
        parameters = map fst rigid
        one obligation bound =
          let subject = formBoundType scope rigid (obligationType obligation)
              required = formBoundType scope rigid bound
              (answer, inferred) = evalChecker $ do
                withDeclared scope
                withRigidBounds (generatedBounds value) (deriveRequirements parameters subject required)
              errors = case answer of
                Proven -> []
                Unproved -> map (withRelated (Related (requestAnchor request) "derive requested here"))
                  (finding "E3092" (authoredSpan (obligationField obligation))
                    (obligationLabel obligation <> ": " <> renderType subject <> " does not implement "
                      <> renderType required <> ", which derive " <> renderType (requestTrait request)
                      <> " requires of every field"))
                _ -> finding "E3093" (requestAnchor request) "derive field proof exhausted its compile-time work budget"
           in (inferred, errors)
        answers = [one obligation bound | obligation <- generatedObligations value, bound <- obligationBounds obligation]
     in (foldr mergeBounds [] (map fst answers), concatMap snd answers)

buildRequest
  :: Catalogue -> ValidatedDefinitions -> Request -> Bounds
  -> Either ExpansionFailure Generated
buildRequest catalogue definitions request additional = do
  selected <- maybe (Left (ExpansionFailure (requestAnchor request)
    "no accessible derive strategy exists for this trait application and target shape")) Right
    (validatedCandidate definitions request)
  let candidate = definitionCandidate selected
      scope = catalogueScopes catalogue Map.! requestModule request
      rigid = parameterEntries (requestParameters request)
      base = [(locatedValue (typeParamName parameter),
        map (formBoundFor scope rigid (locatedValue (typeParamName parameter))) (typeParamBounds parameter))
        | Located _ parameter <- requestParameters request]
      bounds = mergeBounds base additional
  ((implementation, declaration), obligations) <- runResidual (requestAnchor request) $ do
    if acceptsApplication candidate request then pure () else
      refuse (requestAnchor request) "the derive strategy requires a different complete trait application"
    target <- prepareTarget (catalogueScopes catalogue Map.! requestDeclarationModule request) request
    parameters <- mapM (\(Located at parameter) -> do
      written <- mapM (reifyType 0 at)
        (maybe [] id (lookup (locatedValue (typeParamName parameter)) bounds))
      pure (Located at parameter{typeParamBounds = written})) (requestParameters request)
    trait <- reifyType 0 (locatedSpan (requestTraitSyntax request)) (requestTrait request)
    targetSyntax <- reifyType 0 (locatedSpan (requestTargetSyntax request)) (requestTarget request)
    implementation <- instantiateAggregateIn (definitionReflection selected)
      (candidateSyntax candidate) target{typeTypeParams = parameters} trait targetSyntax
    declaration <- Residual.generated (locatedSpan (candidateSyntax candidate)) (ImplDeclaration implementation)
    pure (implementation, declaration)
  pure (Generated request (candidateModule candidate) declaration implementation obligations bounds)

gather
  :: Map ModuleName Module -> [(Request, Either ExpansionFailure Generated)]
  -> Either Findings [Generated]
gather _ values =
  let errors = Map.fromListWith (<>)
        [(requestModule request, finding (if missing message then "E3091" else "E3093") at message)
        | (request, Left (ExpansionFailure at message)) <- values]
   in if failed errors then Left errors else Right [value | (_, Right value) <- values]
 where
  missing message = message == "no accessible derive strategy exists for this trait application and target shape"
    || message == "the derive strategy requires a different complete trait application"

containsDerive :: Module -> Bool
containsDerive unit = any held (moduleDeclarations unit)
 where
  held (Located _ declaration) = case declaration of
    DeriveDeclaration _ -> True
    DeriveImplDeclaration _ -> True
    TypeDeclaration value -> not (null (typeDerives value))
    _ -> False

executable :: Module -> Module
executable unit = unit{moduleDeclarations = foldr retain [] (moduleDeclarations unit)}
 where
  retain (Located _ (DeriveDeclaration _)) rest = rest
  retain (Located _ (DeriveImplDeclaration _)) rest = rest
  retain (Located at (TypeDeclaration value)) rest = Located at (TypeDeclaration value{typeDerives = []}) : rest
  retain value rest = value : rest

parameterEntries :: [Located TypeParam] -> [(Text, Int)]
parameterEntries = map (\(Located _ value) -> (locatedValue (typeParamName value), typeParamArity value))

mergeBounds :: Bounds -> Bounds -> Bounds
mergeBounds left right = Map.toAscList (Map.map nub (Map.fromListWith (<>) (left <> right)))

partitionFindings :: Map ModuleName Module -> [Diagnostic] -> Findings
partitionFindings modules errors = Map.map (\unit ->
  filter (sameSpanSource (moduleSpan unit) . diagnosticSpan) errors) modules

combine :: Findings -> Findings -> Findings
combine left right = Map.map sortDiagnostics (Map.unionWith (<>) left right)

failed :: Findings -> Bool
failed = any hasErrors . Map.elems

budget :: [Request] -> Findings
budget [] = Map.empty
budget (request : _) = Map.singleton (requestModule request)
  (finding "E3093" (requestAnchor request) "derive graph exhausted its compile-time work budget")

finding :: Text -> Span -> Text -> [Diagnostic]
finding name at message = case mkDiagnosticCode name >>= \code -> diagnostic code Error at message of
  Nothing -> []
  Just value -> [value]
