module Pudu.Frontend.ParserStateNameSpec (parserStateNameProperties) where

import qualified Data.Text as Text
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser, advanceToken, isAtEnd, matchSymbol, peekToken, runParser, withRecursionBudget )
import Pudu.Frontend.Syntax (Located (..), moduleNameText)
import Pudu.Frontend.Token (Token (..), TokenKind (EndOfFile), tokenKind)
import Pudu.Source (SourceName (SourceName), emptySpan, newSource, spanEnd, spanSource, spanStart, unOffset)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

parserStateNameProperties :: [(String, IO Property)]
parserStateNameProperties =
  [ ("parser state normalizes exact source-end EOF", testEofNormalization)
  , ("closed symbol matching advances exactly once", testSymbolAdvance)
  , ("recursion exhaustion emits one E1099", testRecursionBudget)
  , ("module paths preserve segments and diagnose casing/trailing dot", testModulePaths)
  ]

testEofNormalization :: IO Property
testEofNormalization = do
  source <- newSource (SourceName "empty-tokens.pudu") "abc"
  foreignSource <- newSource (SourceName "foreign.pudu") ""
  let foreignEof = Token EndOfFile "" (emptySpan foreignSource) []
  let ((first, second, third), diagnostics) = runParser source action []
      (normalized, foreignDiagnostics) = runParser source peekToken [foreignEof]
      action = (,,) <$> peekToken <*> advanceToken <*> peekToken
  pure $ conjoin [map tokenKind [first, second, third] === replicate 3 EndOfFile,
    unOffset (spanStart (tokenSpan first)) === 3, unOffset (spanEnd (tokenSpan first)) === 3,
    spanSource (tokenSpan normalized) === SourceName "empty-tokens.pudu",
    unOffset (spanStart (tokenSpan normalized)) === 3, diagnostics <> foreignDiagnostics === []]

testSymbolAdvance :: IO Property
testSymbolAdvance = do
  source <- newSource (SourceName "symbol.pudu") "."
  let LexResult{lexTokens} = lexSource source
      ((matched, ended), diagnostics) = runParser source ((,) <$> matchSymbol "." <*> isAtEnd) lexTokens
  pure $ conjoin [maybe False (const True) matched === True, ended === True, diagnostics === []]

testRecursionBudget :: IO Property
testRecursionBudget = do
  source <- newSource (SourceName "budget.pudu") ""
  let LexResult{lexTokens} = lexSource source
      (_, diagnostics) = runParser source (nest 513) lexTokens
  pure $ case diagnostics of
    [finding] -> diagnosticCodeText (diagnosticCode finding) === "E1099"
    _ -> counterexample "recursion budget did not emit exactly one diagnostic" False

testModulePaths :: IO Property
testModulePaths = do
  validSource <- newSource (SourceName "valid-name.pudu") "Core.Util"
  invalidSource <- newSource (SourceName "invalid-name.pudu") "core."
  deepSource <- newSource (SourceName "deep-name.pudu") (Text.intercalate "." (replicate 520 "Core"))
  let LexResult{lexTokens = validTokens} = lexSource validSource
      LexResult{lexTokens = invalidTokens} = lexSource invalidSource
      LexResult{lexTokens = deepTokens} = lexSource deepSource
      (Located validSpan validName, validDiagnostics) = runParser validSource parseModuleName validTokens
      (Located _ invalidName, invalidDiagnostics) = runParser invalidSource parseModuleName invalidTokens
      (_, deepDiagnostics) = runParser deepSource parseModuleName deepTokens
  pure $ conjoin [moduleNameText validName === "Core.Util", unOffset (spanStart validSpan) === 0,
    unOffset (spanEnd validSpan) === 9, validDiagnostics === [], moduleNameText invalidName === "core",
    map (diagnosticCodeText . diagnosticCode) invalidDiagnostics === ["E1011", "E1000"],
    map (unOffset . spanStart . diagnosticSpan) invalidDiagnostics === [0, 5],
    map (diagnosticCodeText . diagnosticCode) deepDiagnostics === ["E1099"]]

nest :: Int -> Parser ()
nest remaining
  | remaining <= 0 = pure ()
  | otherwise = withRecursionBudget (nest (remaining - 1)) >> pure ()
