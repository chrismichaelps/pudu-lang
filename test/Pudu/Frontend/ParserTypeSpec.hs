module Pudu.Frontend.ParserTypeSpec (parserTypeProperties) where

import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.State (runParser)
import Pudu.Frontend.Parser.Type (parseTypeSyntax)
import Pudu.Frontend.Syntax (Located (..), TypeSyntax (..), moduleNameText)
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

parserTypeProperties :: [(String, IO Property)]
parserTypeProperties =
  [ ("type parser preserves references and generic paths", testReferenceGeneric)
  , ("type parser distinguishes unit grouping and tuples", testParentheses)
  , ("empty generic arguments emit exact E1020", testEmptyArguments)
  , ("hostile type nesting emits one E1099", testNestingBudget)
  ]

testReferenceGeneric :: IO Property
testReferenceGeneric = do
  (syntax, diagnostics) <- parse "&mut Core.Box[Int]"
  pure $ case syntax of
    Located _ (ReferenceType True (Located _ (NamedType name [Located _ (NamedType argument [])]))) ->
      conjoin [moduleNameText name === "Core.Box", moduleNameText argument === "Int", diagnostics === []]
    _ -> counterexample ("unexpected type syntax: " <> show syntax) False

testParentheses :: IO Property
testParentheses = do
  (unit, unitDiagnostics) <- parse "()"
  (grouped, groupedDiagnostics) <- parse "(Int)"
  (tuple, tupleDiagnostics) <- parse "(Int, Str,)"
  pure $ conjoin [locatedValue unit === UnitType, isNamed "Int" grouped === True,
    tupleArity tuple === 2, unitDiagnostics <> groupedDiagnostics <> tupleDiagnostics === []]

testEmptyArguments :: IO Property
testEmptyArguments = do
  (syntax, diagnostics) <- parse "Box[]"
  pure $ conjoin [locatedValue syntax === InvalidType,
    map (diagnosticCodeText . diagnosticCode) diagnostics === ["E1020"]]

testNestingBudget :: IO Property
testNestingBudget = do
  (_, diagnostics) <- parse (Text.concat (replicate 520 "& ") <> "Int")
  pure (map (diagnosticCodeText . diagnosticCode) diagnostics === ["E1099"])

parse :: Text.Text -> IO (Located TypeSyntax, [Diagnostic])
parse input = do
  source <- newSource (SourceName "type.pudu") input
  let LexResult{lexTokens} = lexSource source
  pure (runParser source parseTypeSyntax lexTokens)

isNamed :: Text.Text -> Located TypeSyntax -> Bool
isNamed expected (Located _ (NamedType name [])) = moduleNameText name == expected
isNamed _ _ = False

tupleArity :: Located TypeSyntax -> Int
tupleArity (Located _ (TupleType members)) = length members
tupleArity _ = 0
