module Pudu.Frontend.ParserStateNameSpec (parserStateNameProperties) where

import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Name (parseModuleName)
import Pudu.Frontend.Parser.State
  ( Parser, advanceToken, isAtEnd, matchSymbol, peekToken
  , runParser, withRecursionBudget )
import Pudu.Frontend.Syntax (Located (..), moduleNameText)
import Pudu.Frontend.Token (TokenKind (EndOfFile), tokenKind, tokenSpan)
import Pudu.Source (SourceName (SourceName), newSource, spanEnd, spanStart, unOffset)
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
  let ((first, second, third), diagnostics) = runParser source action []
      action = (,,) <$> peekToken <*> advanceToken <*> peekToken
  pure $ conjoin [map tokenKind [first, second, third] === replicate 3 EndOfFile,
    unOffset (spanStart (tokenSpan first)) === 3, unOffset (spanEnd (tokenSpan first)) === 3,
    diagnostics === []]

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
  let LexResult{lexTokens = validTokens} = lexSource validSource
      LexResult{lexTokens = invalidTokens} = lexSource invalidSource
      (Located validSpan validName, validDiagnostics) = runParser validSource parseModuleName validTokens
      (Located _ invalidName, invalidDiagnostics) = runParser invalidSource parseModuleName invalidTokens
  pure $ conjoin [moduleNameText validName === "Core.Util", unOffset (spanStart validSpan) === 0,
    unOffset (spanEnd validSpan) === 9, validDiagnostics === [], moduleNameText invalidName === "core",
    map (diagnosticCodeText . diagnosticCode) invalidDiagnostics === ["E1011", "E1001"],
    map (unOffset . spanStart . diagnosticSpan) invalidDiagnostics === [0, 5]]

nest :: Int -> Parser ()
nest remaining
  | remaining <= 0 = pure ()
  | otherwise = withRecursionBudget (nest (remaining - 1)) >> pure ()
