{-| @Type.Check.Pattern.Module — checks patterns against the type they match -}
module Pudu.Type.Check.Pattern
  ( bindPattern
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree (FieldPattern (..), Pattern (..))
import Pudu.Type.Check.Rule (countText, literalType)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes
  , bindName
  , freshVariable
  , lookupField
  , lookupVariant
  , report
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (Scheme (..), Type (..))

{-| Check a pattern against the type it matches, binding the names it
    introduces at the types their positions imply. -}
bindPattern :: DeclaredTypes -> [Text] -> Located Pattern -> Type -> Checker ()
bindPattern declared rigid (Located patternSpan pattern') subjectType = case pattern' of
  WildcardPattern -> pure ()
  BindingPattern name -> bindName (locatedValue name) (Scheme [] subjectType)
  LiteralPattern literal -> do
    _ <- unify patternSpan subjectType (literalType literal)
    pure ()
  RangePattern lower _ _ -> do
    _ <- unify patternSpan subjectType (literalType lower)
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
    declaredFieldTypes <- recordFieldsFor path subjectType
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

recordFieldsFor :: Maybe ModuleName -> Type -> Checker [(Text, Type)]
recordFieldsFor path subjectType = do
  resolved <- zonk subjectType
  let name = case path of
        Just modulePath -> Just (NonEmpty.last (moduleNameSegments modulePath))
        Nothing -> case resolved of
          NominalType nominal _ -> Just nominal
          _ -> Nothing
  case name of
    Nothing -> pure []
    Just found -> maybe [] id <$> lookupField found

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
    Nothing -> bindName name (Scheme [] fieldType)
