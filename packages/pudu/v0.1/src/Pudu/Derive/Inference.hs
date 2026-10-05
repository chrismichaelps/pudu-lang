{-| @Derive.Inference — resolved private contract dependencies for generic admission. -}
module Pudu.Derive.Inference (inferenceCaptures, inferenceErrors) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Pudu.Diagnostic (Diagnostic, diagnosticSpan)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Declaration (..), Function (..), Module (..), Parameter (..))
import Pudu.Semantic
  ( Namespace (ValueSpace), Reference (..), Resolution (..), Symbol (..), SymbolOrigin (ModuleOrigin) )
import Pudu.Source (Offset, Span, sameSpanSource, spanStart, spanEnd, spanOrigin)

inferenceCaptures :: Module -> Resolution -> Set Span
inferenceCaptures unit resolution = visit Set.empty seed
 where
  names = Map.fromList [(name, at) | Located at value <- moduleDeclarations unit, Just name <- [inferredName value]]
  symbols = Map.fromList [(symbolId value, value) | value <- resolutionSymbols resolution]
  extents = declarationExtents unit
  edges = Map.fromListWith Set.union
    [(owner, Set.singleton name)
    | reference <- resolutionReferences resolution
    , Just symbol <- [Map.lookup (referenceSymbol reference) symbols]
    , symbolOrigin symbol == ModuleOrigin, symbolNamespace symbol == ValueSpace
    , Just name <- [symbolSpan symbol], Map.member name names
    , Just owner <- [declarationAt extents (referenceSpan reference)]]
  seed = Set.unions [Map.findWithDefault Set.empty at edges
    | Located at (DeriveDeclaration _) <- moduleDeclarations unit]
  visit admitted pending = case Set.minView pending of
    Nothing -> admitted
    Just (name, rest) | Set.member name admitted -> visit admitted rest
    Just (name, rest) ->
      let next = maybe Set.empty (\at -> Map.findWithDefault Set.empty at edges) (Map.lookup name names)
       in visit (Set.insert name admitted) (Set.union rest next)

inferenceErrors :: Module -> Set Span -> [Diagnostic] -> [Diagnostic]
inferenceErrors unit selected = filter wanted
 where
  extents = declarationExtents unit
  declarations = Set.fromList [at | Located at value <- moduleDeclarations unit
    , Just name <- [inferredName value], Set.member name selected]
  wanted value = maybe False (`Set.member` declarations) (declarationAt extents (diagnosticSpan value))

inferredName :: Declaration -> Maybe Span
inferredName value = case value of
  FunctionDeclaration held
    | functionReturn held == Nothing || any ((== Nothing) . parameterType . locatedValue) (functionParameters held) ->
        Just (locatedSpan (functionName held))
  BindingDeclaration _ _ name Nothing _ -> Just (locatedSpan name)
  _ -> Nothing

declarationExtents :: Module -> Map Offset Span
declarationExtents unit = Map.fromList [(spanStart at, at) | Located at _ <- moduleDeclarations unit]

declarationAt :: Map Offset Span -> Span -> Maybe Span
declarationAt extents written = do
  let at = case spanOrigin written of Just (_, requested, _) -> requested; Nothing -> written
  (_, owner) <- Map.lookupLE (spanStart at) extents
  if sameSpanSource owner at && spanEnd at <= spanEnd owner then Just owner else Nothing
