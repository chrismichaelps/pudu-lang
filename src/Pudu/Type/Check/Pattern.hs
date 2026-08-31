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
import qualified Data.Text as Text
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
  , lookupVariantFields
  , report
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (NominalId, Type (..), monotype)

{-| Check a pattern against the type it matches, binding the names it
    introduces at the types their positions imply. -}
bindPattern :: DeclaredTypes -> [(Text, Int)] -> Located Pattern -> Type -> Checker ()
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
    {-| A variant that named its payload is matched by naming it, for the
        reason it is built that way: one spelling reaches the value, so the
        other can only ever fail to match. -}
    named <- lookupVariantFields name
    case named of
      Just names
        | not (null arguments) ->
            report "E3034" patternSpan (name <> " names its payload")
              ( Just
                  ( "write case " <> name <> "{" <> Text.intercalate ", " names
                      <> "} rather than matching it by position"
                  )
              )
      _ -> pure ()
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
    variantShape <- namedVariantShapeFor path
    case variantShape of
      Just (owner, ownerParams, declaredShape) -> do
        replacements <- freshFor ownerParams
        let ownerType = NominalType owner (map snd replacements)
            expected =
              [ (fieldName, substituteRigid replacements fieldType)
              | (fieldName, fieldType) <- declaredShape
              ]
        _ <- unify patternSpan subjectType ownerType
        mapM_ (bindFieldPattern declared rigid expected) fields
      Nothing -> do
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

{-| The payload a variant named, when the pattern's path names such a variant.

    A record pattern reaches a sum only this way: `case Circle{r}` names one
    variant of the type, so the subject is that variant's owner and the fields
    stand for its payload. A record type's own pattern has no variant to find
    and takes the other path. -}
namedVariantShapeFor
  :: Maybe ModuleName -> Checker (Maybe (NominalId, [Text], [(Text, Type)]))
namedVariantShapeFor path = case path of
  Nothing -> pure Nothing
  Just modulePath -> do
    let name = NonEmpty.last (moduleNameSegments modulePath)
    fieldNames <- lookupVariantFields name
    variant <- lookupVariant name
    pure $ case (fieldNames, variant) of
      (Just names, Just (owner, ownerParams, payload))
        | length names == length payload -> Just (owner, ownerParams, zip names payload)
      _ -> Nothing

throughReferences :: Type -> Type
throughReferences typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReferences target
  other -> other

bindFieldPattern
  :: DeclaredTypes -> [(Text, Int)] -> [(Text, Type)] -> Located FieldPattern -> Checker ()
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
