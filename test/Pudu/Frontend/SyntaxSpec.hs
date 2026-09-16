module Pudu.Frontend.SyntaxSpec (syntaxProperties) where

import Data.List.NonEmpty (NonEmpty ((:|)))
import Pudu.Frontend.Syntax
  ( Declaration (InvalidDeclaration), Located (Located), Module (Module)
  , ModuleName (ModuleName), locatedSpan, locatedValue, mapLocated
  , mergeLocatedSpan, moduleDeclarations, moduleNameText
  )
import Pudu.Source (SourceName (SourceName), emptySpan, newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

syntaxProperties :: [(String, IO Property)]
syntaxProperties =
  [ ("located mapping preserves provenance", testLocated)
  , ("module names retain non-empty segments", testModuleName)
  , ("syntax tree retains explicit recovery poison", testRecoveryTree)
  ]

testLocated :: IO Property
testLocated = do
  source <- newSource (SourceName "located.pudu") "x"
  otherSource <- newSource (SourceName "foreign.pudu") "x"
  let first = Located (emptySpan source) (1 :: Int)
      second = Located (emptySpan source) True
      other = Located (emptySpan otherSource) True
      mapped = mapLocated (+ 1) first
  pure $ conjoin [locatedValue mapped === 2, locatedSpan mapped === locatedSpan first,
    mergeLocatedSpan first second === Just (emptySpan source), mergeLocatedSpan first other === Nothing]

testModuleName :: IO Property
testModuleName =
  pure (moduleNameText (ModuleName ("Pudu" :| ["Frontend", "Syntax"])) === "Pudu.Frontend.Syntax")

testRecoveryTree :: IO Property
testRecoveryTree = do
  source <- newSource (SourceName "tree.pudu") "module App"
  let spanValue = emptySpan source
      tree = Module spanValue (Located spanValue (ModuleName ("App" :| []))) []
        [Located spanValue InvalidDeclaration]
  pure $ case moduleDeclarations tree of
    [Located foundSpan InvalidDeclaration] -> foundSpan === spanValue
    _ -> counterexample "recovery declaration was not retained" False
