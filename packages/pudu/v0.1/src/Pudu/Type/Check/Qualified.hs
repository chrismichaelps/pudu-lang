{-| @Type.Check.Qualified — canonical schemes for type-qualified methods. -}
module Pudu.Type.Check.Qualified (qualifiedScheme, concreteOwner) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (locatedValue)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker, DeclaredTypes (..), ambiguousProviders, lookupName, recordOwner, report )
import Pudu.Type.Value (NominalId (..), Scheme, Type (ErrorType), monotype, nominalKey, nominalName)

{-| A complete declared concrete owner, excluding ordinary qualified values. -}
concreteOwner :: DeclaredTypes -> Tree.Expression -> Checker (Maybe (Text, NominalId))
concreteOwner declared target = case ownerPath target of
  Just path | Just owner <- Map.lookup path (declaredNames declared)
    , not (Set.member owner (declaredTraitNames declared)) -> do
      value <- if Text.isInfixOf "." path then lookupName path else pure Nothing
      pure $ case value of
        Nothing -> Just (path, owner)
        Just _ -> Nothing
  _ -> pure Nothing

{-| Preserve legacy single-name qualification; extend only concrete owner paths. -}
qualifiedScheme :: DeclaredTypes -> Span -> Tree.Expression -> Text -> Checker (Maybe (NominalId, Scheme))
qualifiedScheme declared at target member = case target of
  Tree.NameExpression (first NonEmpty.:| []) -> case Map.lookup first (declaredNames declared) of
    Nothing -> do
      providers <- ambiguousProviders (first <> "." <> member)
      if null providers || Set.member first (declaredQualifiers declared)
        then pure Nothing
        else byType (NominalId Nothing first)
    Just owner -> do
      exported <- if Set.member first (declaredQualifiers declared)
        then lookupName (first <> "." <> member)
        else pure Nothing
      case exported of
        Just _ -> pure Nothing
        Nothing -> byType owner
  _ -> do
    found <- concreteOwner declared target
    maybe (pure Nothing) (byType . snd) found
 where
  byType owner = do
    let key = nominalKey owner <> "." <> member
    providers <- ambiguousProviders key
    case providers of
      _ : _ -> do
        report "E3013" at (member <> " is ambiguous for " <> nominalName owner)
          (Just ("name the trait instead: " <> Text.intercalate " or "
            [nominalName provider <> "." <> member <> "(value)" | provider <- providers]))
        pure (Just (owner, monotype ErrorType))
      [] -> do
        found <- lookupName key
        case found of
          Nothing -> pure Nothing
          Just scheme -> do
            if Set.member owner (declaredTraitNames declared)
              then pure ()
              else recordOwner at owner
            pure (Just (owner, scheme))

ownerPath :: Tree.Expression -> Maybe Text
ownerPath expression = case expression of
  Tree.NameExpression names -> Just (Text.intercalate "." (NonEmpty.toList names))
  Tree.MemberExpression target member ->
    (<> ("." <> locatedValue member)) <$> ownerPath (locatedValue target)
  _ -> Nothing
