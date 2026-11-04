{-| @Semantic.Resolve.Canonical — lexical heads and already formed generated paths. -}
module Pudu.Semantic.Resolve.Canonical
  ( resolveHead, resolveMemberHead, resolveConstructorPath, resolveTypePath ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Semantic.Resolve.Context
  ( Resolver, canonicalTypesInScope, resolveExpressionName, resolveQualifierName, resolveTypeName, resolveValueName )
import Pudu.Semantic.Resolve.Ambiguity (PathUse (..), rejectImportedPath)
import Pudu.Source (Span, spanOrigin)

resolveHead :: Span -> NonEmpty Text -> Resolver ()
resolveHead at = resolvePath (Just (ValuePath, at)) resolveExpressionName at

resolveMemberHead :: Span -> Span -> NonEmpty Text -> Resolver ()
resolveMemberHead headAt at = resolvePath (Just (QualifierPath, at)) resolveQualifierName headAt

resolveConstructorPath :: Span -> ModuleName -> Resolver ()
resolveConstructorPath at (ModuleName path@(_ :| rest)) =
  resolvePath (Just (ValuePath, at)) (if null rest then resolveValueName else resolveQualifierName) at path

resolveTypePath :: Span -> ModuleName -> Resolver ()
resolveTypePath at (ModuleName path) = resolvePath Nothing resolveTypeName at path

resolvePath :: Maybe (PathUse, Span) -> (Span -> Text -> Resolver ()) -> Span -> NonEmpty Text -> Resolver ()
resolvePath checkValue resolve at path@(first :| rest) = do
  formed <- canonicalTypesInScope
  case (formed, spanOrigin at, rest) of
    (True, Just _, _ : _) -> pure ()
    _ -> do
      resolve at first
      case checkValue of
        Just (use, selectedAt) | not (null rest) -> rejectImportedPath use selectedAt path
        _ -> pure ()
