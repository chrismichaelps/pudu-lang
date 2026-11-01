{-| @Semantic.VariantNamespaceSpec — owner-scoped admission and source diagnostics. -}
module Pudu.Semantic.VariantNamespaceSpec (variantNamespaceProperties) where

import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (Diagnostic, Related (..), diagnosticCode, diagnosticCodeText, diagnosticRelated, diagnosticSpan)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Visibility (Private))
import Pudu.Semantic.Resolve.Context
  (ResolverProducts (..), declareNamed, inScope, recordVariantSymbol, resolveExpressionName, runResolver)
import Pudu.Semantic.Symbol (Namespace (ValueSpace), Reference (..), Symbol (..), SymbolOrigin (ParameterOrigin))
import Pudu.Source (SourceName (..), emptySpan, newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

variantNamespaceProperties :: [(String, IO Property)]
variantNamespaceProperties =
  [ ("variant namespaces admit qualified owners and lexical shadows", admission)
  , ("variant namespaces retain ambiguity and duplicate provenance", diagnostics)
  ]

header :: [Text]
header = ["module Main", "type One = Empty | Chosen(Int)", "type Two = Empty | Chosen(Int)"]

admission :: IO Property
admission = do
  qualified <- check (header <> ["fn pick() -> (One, Two) { (One.Chosen(1), Two.Chosen(2)) }"])
  collision <- check ["module Main", "type One = One | Chosen(Int)",
    "type Two = One | Chosen(Int)", "fn pick() -> One { One.Chosen(1) }"]
  bare <- check ["module Main", "type One = One | Chosen(Int)",
    "type Two = One | Chosen(Int)", "fn pick() -> One { One }"]
  source <- newSource (SourceName "scoped-variant") "Chosen"
  let at = emptySpan source
      shadow = runResolver $ do
        recordVariantSymbol "One" (Located at "Chosen")
        recordVariantSymbol "Two" (Located at "Chosen")
        inScope $ do
          declareNamed ValueSpace ParameterOrigin Private False (Located at "Chosen")
          resolveExpressionName at "Chosen"
  pure $ conjoin [counterexample "qualified owners" (codes qualified === []),
    counterexample "type qualifier wins over a variant alias" (codes collision === []),
    codes bare === ["E2012"],
    counterexample "nearer value shadows aliases" (codes (producedDiagnostics shadow) === []),
    map referenceSymbol (producedReferences shadow) ===
      [symbolId symbol | symbol <- producedSymbols shadow, symbolOrigin symbol == ParameterOrigin]]

diagnostics :: IO Property
diagnostics = do
  ambiguous <- check (header <> ["fn pick() -> One { Chosen(1) }"])
  duplicate <- check ["module Main", "type One = Empty | Chosen(Int) | Chosen(Int)"]
  values <- check ["module Main", "fn same() -> Int { 1 }", "fn same() -> Int { 2 }"]
  types <- check ["module Main", "type Same = { value: Int }", "type Same = { other: Int }"]
  let start = Text.length (Text.unlines header) + Text.length "fn pick() -> One { "
      candidates = [Text.length "module Main\ntype One = Empty | ",
        Text.length (Text.unlines (take 2 header)) + Text.length "type Two = Empty | "]
      locations finding = (unOffset (spanStart (diagnosticSpan finding)),
        unOffset (spanEnd (diagnosticSpan finding)),
        sort (map (unOffset . spanStart . relatedSpan) (diagnosticRelated finding)))
  pure $ conjoin
    [ codes ambiguous === ["E2012"]
    , map locations ambiguous === [(start, start + Text.length "Chosen", candidates)]
    , codes duplicate === ["E2001"]
    , map (length . diagnosticRelated) duplicate === [1]
    , codes values === ["E2001"]
    , codes types === ["E2001"]
    ]

check :: [Text] -> IO [Diagnostic]
check lines' = do
  source <- newSource (SourceName "variant-namespaces.pudu") (Text.unlines lines')
  compileDiagnostics <$> runCompile source

codes :: [Diagnostic] -> [Text]
codes = map (diagnosticCodeText . diagnosticCode)
