{-| @Semantic.VariantNamespaceSpec — owner-scoped admission and source diagnostics. -}
module Pudu.Semantic.VariantNamespaceSpec (variantNamespaceProperties) where

import Data.List (sort)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), FrontendResult (..), runCompile, runFrontend)
import Pudu.Diagnostic (Diagnostic, Related (..), diagnosticCode, diagnosticCodeText, diagnosticRelated, diagnosticSpan)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Module (..), Visibility (Private))
import Pudu.Semantic.Interface (ImportedVariant (..), exportIndex)
import Pudu.Semantic.Resolve (resolveModuleWith)
import Pudu.Semantic.Resolve.Ambiguity (recordImportedVariants)
import Pudu.Semantic.Resolve.Context
  (ResolverProducts (..), declareNamed, inScope, recordVariantSymbol, resolveExpressionName, runResolver)
import Pudu.Semantic.Symbol (Namespace (ValueSpace), Reference (..), Symbol (..), SymbolOrigin (ParameterOrigin, ImportOrigin))
import Pudu.Source (SourceName (..), emptySpan, newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

variantNamespaceProperties :: [(String, IO Property)]
variantNamespaceProperties =
  [ ("variant namespaces admit qualified owners and lexical shadows", admission)
  , ("variant namespaces retain ambiguity and duplicate provenance", diagnostics)
  , ("imported variant ambiguity retains every declaration and lexical shadow", imported)
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

imported :: IO Property
imported = do
  cases <- sequence [importedCase reversed qualified | reversed <- [False, True], qualified <- [False, True]]
  source <- newSource (SourceName "import-shadow") "Chosen"
  let at = emptySpan source
      shadow = runResolver $ do
        declareNamed ValueSpace ImportOrigin Private False (Located at "Chosen")
        recordImportedVariants "Chosen" (Map.singleton [] (ImportedVariant [at, at] False))
        inScope $ do
          declareNamed ValueSpace ParameterOrigin Private False (Located at "Chosen")
          resolveExpressionName at "Chosen"
  pure $ conjoin ((codes (producedDiagnostics shadow) === ["W2001"]) :
    (map referenceSymbol (producedReferences shadow) ===
      [symbolId symbol | symbol <- producedSymbols shadow, symbolOrigin symbol == ParameterOrigin]) : cases)

importedCase :: Bool -> Bool -> IO Property
importedCase reversed qualified = do
  let first = "export type First = First | Chosen(Int)"
      second = "export type Second = First | Chosen(Int)"
      (leading, following) = if reversed then (second, first) else (first, second)
      ordered = [leading, following]
      producer = Text.unlines ("module Choices" : ordered)
      imports = ["module Main", "import Choices as C"] <> if qualified then [] else ["import Choices { Chosen }"]
      prefix = Text.unlines imports <> "fn pick() -> C.First { "
      written = if qualified then "C.Chosen" else "Chosen"
      consumer = prefix <> written <> "(1) }\n"
      firstOffset = Text.length "module Choices\n"
      candidateOffsets = [firstOffset + Text.length (fst (Text.breakOn "Chosen" leading)),
        firstOffset + Text.length leading + 1 + Text.length (fst (Text.breakOn "Chosen" following))]
  producerSource <- newSource (SourceName "Choices.pudu") producer
  consumerSource <- newSource (SourceName "Main.pudu") consumer
  goodSource <- newSource (SourceName "Main.pudu") (prefix <> "C.First.Chosen(1) }\n")
  let frontends = map runFrontend [producerSource, consumerSource, goodSource]
  pure $ case map frontendModule frontends of
    [Just exporting, Just consuming, Just good] ->
      let index = exportIndex (Map.singleton (locatedValue (moduleName exporting)) exporting)
          (_, findings) = resolveModuleWith index consuming
          (_, admitted) = resolveModuleWith index good
          locations finding = (unOffset (spanStart (diagnosticSpan finding)),
            unOffset (spanEnd (diagnosticSpan finding)),
            sort [(unOffset (spanStart (relatedSpan note)), unOffset (spanEnd (relatedSpan note)))
              | note <- diagnosticRelated finding])
      in conjoin [codes findings === ["E2012"], codes admitted === [],
        map locations findings === [(Text.length prefix, Text.length prefix + Text.length written,
          sort [(offset, offset + Text.length "Chosen") | offset <- candidateOffsets])]]
    _ -> counterexample (show (map frontendDiagnostics frontends)) (property False)
