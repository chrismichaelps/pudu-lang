{-| @Semantic.Resolve.Bindings — introduces pattern names in the active frame -}
module Pudu.Semantic.Resolve.Bindings (bindPattern, bindPatternWith) where

import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( ArrayRest (..), FieldPattern (..), Pattern (..), Visibility (Private) )
import Pudu.Semantic.Resolve.Context (Resolver, declareNamed)
import Pudu.Semantic.Symbol (Namespace (ValueSpace), SymbolOrigin (PatternOrigin))
import Pudu.Semantic.Resolve.Canonical (resolveConstructorPath)

{-| Pattern bindings enter the arm's own frame; a constructor path is resolved
    in the type namespace, and its payload patterns bind in turn. -}
bindPattern :: Located Pattern -> Resolver ()
bindPattern = bindPatternWith False

{-| Bind a pattern's names, and say whether they may be assigned.

    A match arm and a `let` bind names that may not; `var (a, b) = pair` binds
    names that may, and the difference has to reach every name the pattern
    introduces rather than only the one an ordinary `var` would have named. -}
bindPatternWith :: Bool -> Located Pattern -> Resolver ()
bindPatternWith mutable (Located patternSpan value) = case value of
  WildcardPattern -> pure ()
  BindingPattern name -> declareNamed ValueSpace PatternOrigin Private mutable name
  LiteralPattern _ -> pure ()
  RangePattern{} -> pure ()
  TuplePattern members -> mapM_ recurse members
  ArrayPattern prefix rest suffix -> do
    mapM_ recurse prefix
    case rest of
      Just (BoundRest name) -> declareNamed ValueSpace PatternOrigin Private mutable name
      _ -> pure ()
    mapM_ recurse suffix
  ConstructorPattern path arguments -> do
    resolveConstructorPath patternSpan path
    mapM_ recurse arguments
  RecordPattern path fields _ -> do
    mapM_ (resolveConstructorPath patternSpan) path
    mapM_ (bindFieldPatternWith mutable) fields
  AlternativePattern alternatives -> mapM_ recurse alternatives
  InvalidPattern -> pure ()
 where
  recurse = bindPatternWith mutable

bindFieldPatternWith :: Bool -> Located FieldPattern -> Resolver ()
bindFieldPatternWith mutable (Located _ field) = case fieldPatternValue field of
  Just nested -> bindPatternWith mutable nested
  Nothing ->
    declareNamed ValueSpace PatternOrigin Private mutable (fieldPatternName field)

