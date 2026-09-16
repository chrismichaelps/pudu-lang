{-| @Test.Pudu.LintSpec — typed lint findings and safe edits. -}
module Pudu.LintSpec (lintProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Lint
  ( LintFinding (..)
  , LintFix (..)
  , LintResult (..)
  , LintStats (..)
  , applySafeFixes
  , lintModule
  )
import Pudu.Source (Source, SourceName (..), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

lintProperties :: [(String, IO Property)]
lintProperties =
  [ ("typed Boolean comparisons publish exact safe fixes", testBooleanFixes)
  , ("negating Boolean comparisons remain untouched", testNegativeShapes)
  , ("parenthesized inner rewrites are withheld while the outer stays safe", testOverlap)
  , ("sequential lint traversal visits each expression once", testLinearTraversal)
  ]

testBooleanFixes :: IO Property
testBooleanFixes = do
  analyzed <- analyze booleanSource
  pure $ case analyzed of
    Nothing -> counterexample "the lint fixture did not compile" False
    Just (source, result) ->
      let findings = lintFindings result
       in conjoin
            [ map codeOf findings === replicate 4 "W7101"
            , map (fmap lintFixReplacement . lintFix) findings
                === map Just ["value", "value", "value", "value"]
            , applySafeFixes source findings === fixedBooleanSource
            ]

testNegativeShapes :: IO Property
testNegativeShapes = do
  analyzed <- analyze negativeSource
  pure $ case analyzed of
    Nothing -> counterexample "the negative lint fixture did not compile" False
    Just (_, result) -> lintFindings result === []

testOverlap :: IO Property
testOverlap = do
  analyzed <- analyze overlapSource
  pure $ case analyzed of
    Nothing -> counterexample "the overlapping lint fixture did not compile" False
    Just (source, result) -> conjoin
      [ property (length (lintFindings result) == 1)
      , applySafeFixes source (lintFindings result)
          === Text.replace "(value == true) == true" "(value == true)" overlapSource
      ]

testLinearTraversal :: IO Property
testLinearTraversal = do
  let binding index = "  let value" <> Text.pack (show index) <> " = value == true"
      count = 1000
      sourceText = Text.unlines
        (["module Linear", "", "fn check(value: Bool) -> Bool {"]
          <> map binding [1 .. count]
          <> ["  value", "}"])
  analyzed <- analyze sourceText
  pure $ case analyzed of
    Nothing -> counterexample "the linear lint fixture did not compile" False
    Just (_, result) -> conjoin
      [ lintVisitedExpressions (lintStats result) === count * 3 + 1
      , length (lintFindings result) === count
      ]

analyze :: Text -> IO (Maybe (Source, LintResult))
analyze contents = do
  source <- newSource (SourceName "LintFixture.pudu") contents
  compiled <- runCompile source
  pure $ do
    parsed <- compileModule compiled
    types <- compileTypes compiled
    pure (source, lintModule source types parsed)

codeOf :: LintFinding -> Text
codeOf = diagnosticCodeText . diagnosticCode . lintDiagnostic

booleanSource :: Text
booleanSource = Text.unlines
  [ "module BooleanFixes"
  , ""
  , "fn one(value: Bool) -> Bool { value == true }"
  , "fn two(value: Bool) -> Bool { true == value }"
  , "fn three(value: Bool) -> Bool { value != false }"
  , "fn four(value: Bool) -> Bool { false != value }"
  ]

fixedBooleanSource :: Text
fixedBooleanSource = Text.unlines
  [ "module BooleanFixes"
  , ""
  , "fn one(value: Bool) -> Bool { value }"
  , "fn two(value: Bool) -> Bool { value }"
  , "fn three(value: Bool) -> Bool { value }"
  , "fn four(value: Bool) -> Bool { value }"
  ]

negativeSource :: Text
negativeSource = Text.unlines
  [ "module NegativeFixes"
  , ""
  , "fn one(value: Bool) -> Bool { value == false }"
  , "fn two(value: Bool) -> Bool { value != true }"
  , "fn three(value: Bool) -> Bool { value && true }"
  ]

overlapSource :: Text
overlapSource = Text.unlines
  [ "module Overlap"
  , ""
  , "fn check(value: Bool) -> Bool { (value == true) == true }"
  ]
