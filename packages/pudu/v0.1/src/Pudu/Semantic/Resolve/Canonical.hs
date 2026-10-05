{-| @Semantic.Resolve.Canonical — lexical heads and already formed generated paths. -}
module Pudu.Semantic.Resolve.Canonical
  ( resolveHead, resolveMemberHead, resolveConstructorPath, resolveTypePath ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Semantic.Resolve.Context
  ( Resolver, canonicalTypesInScope, resolveExpressionName, resolveTypeName, resolveValueName )
import Pudu.Source (Span, spanOrigin)

resolveHead :: Span -> NonEmpty Text -> Resolver ()
resolveHead = resolvePath resolveExpressionName

resolveMemberHead :: Span -> NonEmpty Text -> Resolver ()
resolveMemberHead = resolvePath resolveValueName

resolveConstructorPath :: Span -> ModuleName -> Resolver ()
resolveConstructorPath at (ModuleName path) = resolvePath resolveValueName at path

resolveTypePath :: Span -> ModuleName -> Resolver ()
resolveTypePath at (ModuleName path) = resolvePath resolveTypeName at path

resolvePath :: (Span -> Text -> Resolver ()) -> Span -> NonEmpty Text -> Resolver ()
resolvePath resolve at (first :| rest) = do
  formed <- canonicalTypesInScope
  case (formed, spanOrigin at, rest) of
    (True, Just _, _ : _) -> pure ()
    _ -> resolve at first
