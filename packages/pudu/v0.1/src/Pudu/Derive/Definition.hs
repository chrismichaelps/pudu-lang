{-| @Derive.Definition — abstract admission of generically checked templates. -}
module Pudu.Derive.Definition
  ( ValidatedDefinitions, ValidatedDefinition
  , validateDefinitions, validatedCandidate, definitionCandidate
  , definitionReflection, definitionResolution
  ) where

import Data.Map.Strict (Map)
import Data.List (nub)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Derive.Catalogue (Catalogue, Candidate (..), Request, candidateFor)
import Pudu.Derive.Reflection (ReflectionBinding, reflectionReferences)
import Pudu.Derive.Inference (inferenceCaptures, inferenceErrors)
import Pudu.Diagnostic (Diagnostic, hasErrors, sortDiagnostics)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Function (..), Impl (..)
  , Expression (TupleExpression), Module (..), Trait (..) )
import Pudu.Semantic (ExportIndex, Resolution, resolveModuleWith, writableReferences)
import Pudu.Source (Span)
import Pudu.Type.Check (checkDeriveDefinitionsWith)
import Pudu.Type.Interface.Graph (InterfaceGraph, importsFor)

data ValidatedDefinitions = ValidatedDefinitions
  !Catalogue !(Map ModuleName (Resolution, Map Span ReflectionBinding))

data ValidatedDefinition = ValidatedDefinition
  { definitionCandidate :: !Candidate
  , definitionReflection :: !(Map Span ReflectionBinding)
  , definitionResolution :: !Resolution
  }

validateDefinitions
  :: Catalogue -> InterfaceGraph -> ExportIndex -> Map ModuleName Module
  -> (ValidatedDefinitions, Map ModuleName [Diagnostic])
validateDefinitions catalogue graph exports modules =
  let checked = Map.mapMaybe check modules
      admitted = Map.mapMaybe (\(result, _) -> result) checked
   in (ValidatedDefinitions catalogue admitted, Map.map snd checked)
 where
  check unit =
    let hasDefinitions = any isDefinition (moduleDeclarations unit)
        view = definitionView unit
        (headerResolution, headerErrors) = resolveModuleWith exports view
        (completeResolution, completeErrors) = resolveModuleWith exports unit
        captures = if hasDefinitions then inferenceCaptures unit completeResolution else Set.empty
        resolution = if Set.null captures then headerResolution else completeResolution
        resolutionErrors = nub (headerErrors <> inferenceErrors unit captures completeErrors)
        typingErrors = if hasErrors resolutionErrors || not hasDefinitions then []
          else checkDeriveDefinitionsWith captures (importsFor graph unit) (writableReferences resolution) unit
        errors = sortDiagnostics (resolutionErrors <> typingErrors)
        admitted = if hasErrors errors || not hasDefinitions then Nothing
          else Just (resolution, reflectionReferences view resolution)
     in Just (admitted, errors)
  isDefinition (Located _ (DeriveDeclaration _)) = True
  isDefinition _ = False

validatedCandidate :: ValidatedDefinitions -> Request -> Maybe ValidatedDefinition
validatedCandidate (ValidatedDefinitions catalogue modules) request = do
  candidate <- candidateFor catalogue request
  (resolution, reflection) <- Map.lookup (candidateModule candidate) modules
  pure (ValidatedDefinition candidate reflection resolution)

{-| The projection preserves all shared names and signature syntax. Only
    generic template bodies participate in this early checking boundary. -}
definitionView :: Module -> Module
definitionView unit = unit{moduleDeclarations = map project (moduleDeclarations unit)}
 where
  strip value = value{functionBody = Nothing}
  stripMember (Located at value) = Located at (strip value)
  project (Located at declaration) = Located at $ case declaration of
    FunctionDeclaration value -> FunctionDeclaration (strip value)
    TraitDeclaration value -> TraitDeclaration value{traitMembers = map stripMember (traitMembers value)}
    ImplDeclaration value -> ImplDeclaration value{implFunctions = map stripMember (implFunctions value)}
    BindingDeclaration visibility kind name written (Located valueAt _) ->
      BindingDeclaration visibility kind name written (Located valueAt (TupleExpression []))
    other -> other
