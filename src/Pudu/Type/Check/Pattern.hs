{-| @Type.Check.Pattern.Module — checks patterns against the type they match -}
module Pudu.Type.Check.Pattern
  ( bindPattern
  , freshFor
  , recordFieldsFor
  , substituteRigid
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree (FieldPattern (..), Pattern (..))
import Pudu.Type.Check.Rule (countText, literalType)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , freshVariable
  , lookupField
  , lookupTypeParams
  , lookupVariant
  , report
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (Type (..), monotype)

{-| Check a pattern against the type it matches, binding the names it
    introduces at the types their positions imply. -}
bindPattern :: DeclaredTypes -> [Text] -> Located Pattern -> Type -> Checker ()
bindPattern declared rigid (Located patternSpan pattern') subjectType = case pattern' of
  WildcardPattern -> pure ()
  BindingPattern name -> bindName (locatedValue name) (monotype subjectType)
  LiteralPattern literal -> do
    literalTypeValue <- literalType patternSpan literal
    _ <- unify patternSpan subjectType literalTypeValue
    pure ()
  RangePattern lower _ upper -> do
    lowerType <- literalType patternSpan lower
    upperType <- literalType patternSpan upper
    _ <- unify patternSpan subjectType lowerType
    _ <- unify patternSpan subjectType upperType
    pure ()
  TuplePattern members -> do
    memberTypes <- mapM (const freshVariable) members
    _ <- unify patternSpan subjectType (TupleTypeValue memberTypes)
    sequence_ (zipWith (bindPattern declared rigid) members memberTypes)
  ConstructorPattern path arguments -> do
    let name = NonEmpty.last (moduleNameSegments path)
    variant <- lookupVariant name
    case variant of
      Nothing -> mapM_ (\argument -> bindPattern declared rigid argument ErrorType) arguments
      Just (owner, ownerParams, declaredPayload) -> do
        replacements <- freshFor ownerParams
        let ownerType = NominalType owner (map snd replacements)
            payload = map (substituteRigid replacements) declaredPayload
        _ <- unify patternSpan subjectType ownerType
        if length payload == length arguments
          then sequence_ (zipWith (bindPattern declared rigid) arguments payload)
          else do
            report "E3009" patternSpan
              (name <> " carries " <> countText (length payload))
              (Just "match one pattern per declared payload element")
            mapM_ (\argument -> bindPattern declared rigid argument ErrorType) arguments
  RecordPattern path fields _ -> do
    declaredFieldTypes <- recordFieldsFor declared path subjectType
    mapM_ (bindFieldPattern declared rigid declaredFieldTypes) fields
  AlternativePattern alternatives ->
    mapM_ (\alternative -> bindPattern declared rigid alternative subjectType) alternatives
  InvalidPattern -> pure ()

{-| A generic sum is instantiated at every pattern, so matching `Wrap(1)` gives
    the payload `Int` rather than the declaration's rigid parameter. -}
freshFor :: [Text] -> Checker [(Text, Type)]
freshFor = mapM (\name -> (,) name <$> freshVariable)

substituteRigid :: [(Text, Type)] -> Type -> Type
substituteRigid replacements typeValue = case typeValue of
  RigidType name -> maybe typeValue id (lookup name replacements)
  NominalType name arguments -> NominalType name (map (substituteRigid replacements) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substituteRigid replacements) members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous
      (map (substituteRigid replacements) inputs)
      (substituteRigid replacements result)
  ReferenceTypeValue mutable target ->
    ReferenceTypeValue mutable (substituteRigid replacements target)
  other -> other

{-| A record's declared field types, with the type's own parameters replaced by
    the arguments the subject carries.

    A generic record is instantiated wherever it is matched, exactly as a
    generic sum already was: matching a `Boxed[Int]` gives the field `Int`
    rather than the declaration's rigid parameter. -}
recordFieldsFor :: DeclaredTypes -> Maybe ModuleName -> Type -> Checker [(Text, Type)]
recordFieldsFor declared path subjectType = do
  resolved <- zonk subjectType
  let subjectArguments = case throughReferences resolved of
        NominalType _ arguments -> arguments
        _ -> []
      name = case path of
        Just modulePath -> Map.lookup (moduleNameText modulePath) (declaredNames declared)
        Nothing -> case throughReferences resolved of
          NominalType nominal _ -> Just nominal
          _ -> Nothing
  case name of
    Nothing -> pure []
    Just found -> do
      fields <- maybe [] id <$> lookupField found
      parameters <- maybe [] id <$> lookupTypeParams found
      replacements <-
        if length parameters == length subjectArguments
          then pure (zip parameters subjectArguments)
          else freshFor parameters
      pure [(fieldName, substituteRigid replacements fieldType) | (fieldName, fieldType) <- fields]

throughReferences :: Type -> Type
throughReferences typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReferences target
  other -> other

bindFieldPattern
  :: DeclaredTypes -> [Text] -> [(Text, Type)] -> Located FieldPattern -> Checker ()
bindFieldPattern declared rigid expected (Located fieldSpan field) = do
  let name = locatedValue (fieldPatternName field)
      fieldType = maybe ErrorType id (lookup name expected)
  case lookup name expected of
    Just _ -> pure ()
    Nothing ->
      report "E3005" fieldSpan ("no declared field " <> name)
        (Just "check the field name against the type declaration")
  case fieldPatternValue field of
    Just nested -> bindPattern declared rigid nested fieldType
    Nothing -> bindName name (monotype fieldType)
