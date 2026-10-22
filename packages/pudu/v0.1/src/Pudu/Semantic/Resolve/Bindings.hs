{-| @Semantic.Resolve.Bindings — introduces pattern names in the active frame -}
module Pudu.Semantic.Resolve.Bindings (bindPattern, bindPatternWith) where

import Pudu.Frontend.Syntax.Located (Located (..))
import qualified Data.Set as Set
import Pudu.Diagnostic (Severity (Error))
import Pudu.Frontend.Syntax.Pattern (patternBindings)
import Pudu.Frontend.Syntax.Tree
  ( ArrayRest (..), FieldPattern (..), Pattern (..), Visibility (Private) )
import Pudu.Semantic.Resolve.Context (Resolver, declareNamed, emit, inScopeOver)
import Pudu.Semantic.Symbol (Namespace (ValueSpace), SymbolOrigin (PatternOrigin))
import Pudu.Semantic.Resolve.Canonical (resolveConstructorPath)
import Pudu.Source (spanStart, spanEnd, unOffset)

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
  AlternativePattern [] -> pure ()
  AlternativePattern (first : rest) -> do
    recurse first
    mapM_ (alternative (names first)) rest
  InvalidPattern -> pure ()
 where
  recurse = bindPatternWith mutable
  names = Set.fromList . map locatedValue . patternBindings
  alternative expected branch@(Located at _) = do
    if names branch == expected then pure () else
      emit "E2019" Error at "pattern alternatives bind different names"
        (Just "bind the same names in every alternative")
    inScopeOver (Just (unOffset (spanStart at), unOffset (spanEnd at))) (recurse branch)

bindFieldPatternWith :: Bool -> Located FieldPattern -> Resolver ()
bindFieldPatternWith mutable (Located _ field) = case fieldPatternValue field of
  Just nested -> bindPatternWith mutable nested
  Nothing ->
    declareNamed ValueSpace PatternOrigin Private mutable (fieldPatternName field)

