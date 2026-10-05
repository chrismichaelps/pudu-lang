{-| @Derive.Target — applies canonical target arguments before residualization. -}
module Pudu.Derive.Target (prepareTarget, reifyType, acceptsApplication) where

import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Derive.Catalogue (Candidate (..), Request (..))
import Pudu.Derive.State (Residual, generated, refuse, withinDepth)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import Pudu.Frontend.Syntax.Tree
  ( Derive (..), FieldDeclaration (..), TypeDeclarationValue (..), TypeDefinition (..)
  , TypeParam (..), TypeSyntax (..), Variant (..), VariantPayload (..) )
import Pudu.Source (Span)
import Pudu.Type.Env (DeclaredTypes)
import Pudu.Type.Formation (formBoundType)
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Value (NominalId (..), Type (..), canonicalNominal, capabilityList, requiredCount)

acceptsApplication :: Candidate -> Request -> Bool
acceptsApplication candidate request =
  substituteRigid [(locatedValue (deriveParameter (locatedValue (candidateSyntax candidate))), requestTarget request)]
    (candidateTrait candidate) == requestTrait request

prepareTarget :: DeclaredTypes -> Request -> Residual TypeDeclarationValue
prepareTarget scope request = case requestTarget request of
  NominalType owner arguments
    | owner == canonicalNominal (requestDeclarationModule request) (locatedValue (typeName target))
    , length arguments == length declaredParameters -> do
        definition <- shape (locatedValue (typeDefinition target))
        pure target{typeTypeParams = requestParameters request,
          typeDefinition = (typeDefinition target){locatedValue = definition}, typeDerives = []}
   where
    replacements = zip (map fst declaredParameters) arguments
    applied (Located at written) = reifyType 0 at
      (substituteRigid replacements (formBoundType scope declaredParameters (Located at written)))
    field (Located at value) = do
      held <- applied (fieldType value)
      pure (Located at value{fieldType = held})
    variant (Located at value) = do
      payload <- case variantPayload value of
        UnitPayload -> pure UnitPayload
        TuplePayload members -> TuplePayload <$> mapM applied members
        RecordPayload fields -> RecordPayload <$> mapM field fields
      pure (Located at value{variantPayload = payload})
    shape value = case value of
      RecordDefinition fields -> RecordDefinition <$> mapM field fields
      SumDefinition variants -> SumDefinition <$> mapM variant variants
      _ -> refuse (locatedSpan (typeDefinition target)) "a derive target must have an aggregate shape"
  _ -> refuse (requestAnchor request) "a derive target requires its complete argument vector"
 where
  target = requestDeclaration request
  declaredParameters =
    [(locatedValue (typeParamName value), typeParamArity value) | Located _ value <- typeTypeParams target]

reifyType :: Int -> Span -> Type -> Residual (Located TypeSyntax)
reifyType depth at value = do
  withinDepth depth at
  written <- case value of
    NominalType owner arguments -> NamedType (nominalPath owner) <$> mapM recurse arguments
    DynamicTypeValue owner -> pure (DynamicType (nominalPath owner))
    ReferenceTypeValue mutable held -> ReferenceType mutable <$> recurse held
    TupleTypeValue members -> TupleType <$> mapM recurse members
    FunctionTypeRequiring async inputs required result
      | requiredCount required == length inputs -> FunctionType async <$> mapM recurse inputs <*> recurse result
      | otherwise -> refuse at "a function's default-arity contract cannot be erased into type syntax"
    RestrictedType capabilities held -> do
      caps <- mapM (generated at) (capabilityList capabilities)
      UnsafeType caps <$> recurse held
    RigidType name -> pure (NamedType (ModuleName (name :| [])) [])
    AppliedType (RigidType name) arguments -> NamedType (ModuleName (name :| [])) <$> mapM recurse arguments
    UnitTypeValue -> pure UnitType
    NeverType -> pure (NamedType (ModuleName ("Never" :| [])) [])
    AppliedType _ _ -> refuse at "an applied type needs a named canonical constructor"
    VariableType _ -> refuse at "an unresolved type cannot enter a generated implementation"
    ErrorType -> refuse at "an invalid type cannot enter a generated implementation"
  generated at written
 where
  recurse = reifyType (depth + 1) at

nominalPath :: NominalId -> ModuleName
nominalPath owner = ModuleName $ case nominalModule owner of
  Nothing -> nominalName owner :| []
  Just declared -> moduleNameSegments declared <> (nominalName owner :| [])
