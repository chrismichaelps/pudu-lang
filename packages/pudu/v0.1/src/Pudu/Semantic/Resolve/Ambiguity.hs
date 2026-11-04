{-| @Semantic.Resolve.Ambiguity — preserves owner candidates across lexical imports. -}
module Pudu.Semantic.Resolve.Ambiguity
  ( PathUse (..), recordImportedVariants, isVariantAlias, rejectAmbiguous, rejectImportedPath ) where

import Data.List (isPrefixOf)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic
  ( Related (..), Severity (Error), diagnostic, mkDiagnosticCode, withHelp, withRelated )
import Pudu.Semantic.Interface (ImportedVariant (..))
import Pudu.Semantic.Resolve.State (ResolveState (..), Resolver (..))
import Pudu.Semantic.Scope (lookupSymbol)
import Pudu.Semantic.Symbol (Namespace (ValueSpace), Symbol (..), SymbolOrigin (..))
import Pudu.Source (Span, spanOrigin)

data PathUse = ValuePath | QualifierPath deriving stock (Eq)

recordImportedVariants :: Text -> Map.Map [Text] ImportedVariant -> Resolver ()
recordImportedVariants name candidates
  | Map.null candidates = pure ()
  | otherwise = Resolver $ \state -> case lookupSymbol ValueSpace name (stateScopes state) of
      Nothing -> ((), state)
      Just symbol -> ((), state{stateImportedVariants =
        Map.insert (symbolId symbol) candidates (stateImportedVariants state)})

isVariantAlias :: Symbol -> Resolver Bool
isVariantAlias symbol = case symbolOrigin symbol of
  VariantOrigin -> pure True
  ImportOrigin -> Resolver $ \state ->
    (maybe False (Map.member []) (Map.lookup (symbolId symbol) (stateImportedVariants state)), state)
  _ -> pure False

{-| Reuse the selected lexical symbol; ordinary values need no second scope walk. -}
rejectAmbiguous :: Span -> Text -> Maybe Symbol -> Resolver Bool
rejectAmbiguous at name selected = case selected of
  Just symbol -> case symbolOrigin symbol of
    VariantOrigin -> do
      candidates <- Resolver $ \state ->
        (Map.findWithDefault Map.empty name (stateVariants state), state)
      let locations = [location | candidate <- Map.elems candidates, Just location <- [symbolSpan candidate]]
      if Map.size candidates > 1 then refuse at name locations else pure False
    ImportOrigin -> do
      candidates <- Resolver $ \state ->
        (Map.lookup (symbolId symbol) (stateImportedVariants state) >>= Map.lookup [], state)
      maybe (pure False) (refuse at name . variantDeclarations) candidates
    _ -> pure False
  Nothing -> pure False

{-| Only nonempty qualifier suffixes are checked here; bare refusals occur once above. -}
rejectImportedPath :: PathUse -> Span -> NonEmpty Text -> Resolver ()
rejectImportedPath use at (first :| rest) = do
  locations <- Resolver $ \state ->
    let found
          | Map.null (stateImportedVariants state) = Nothing
          | otherwise = do
              symbol <- lookupSymbol ValueSpace first (stateScopes state)
              Map.lookup (symbolId symbol) (stateImportedVariants state)
        qualified = maybe [] (concatMap (variantDeclarations . snd) . filter matches . Map.toList) found
        matches (suffix, candidate) = not (null suffix) && suffix `isPrefixOf` rest
          && not (variantTypeHead candidate && (use == QualifierPath || length rest > length suffix))
        formed = stateCanonicalTypes state && spanOrigin at /= Nothing && not (null rest)
    in (if formed then [] else qualified, state)
  if null locations then pure () else do
    _ <- refuse at (Text.intercalate "." (first : rest)) locations
    pure ()

refuse :: Span -> Text -> [Span] -> Resolver Bool
refuse at name locations = do
  let finding = do
        code <- mkDiagnosticCode "E2012"
        value <- diagnostic code Error at ("ambiguous variant name " <> name)
        pure (foldr (\location -> withRelated (Related location "candidate declared here"))
          (withHelp "qualify the variant with its type, as in Type.Variant" value) locations)
  case finding of
    Nothing -> pure ()
    Just value -> Resolver $ \state ->
      ((), state{stateDiagnosticsRev = value : stateDiagnosticsRev state})
  pure True
