{-| @Test.Type.Check.DeriveSpec — derive definitions check once, generically -}
module Pudu.Type.Check.DeriveSpec
  ( testDeriveChecked
  , testDeriveFixtures
  , testDeriveLoopChecked
  , testDeriveLoopMistakeOnce
  , testDeriveMistakeOnce
  , testDeriveRequestUnchecked
  ) where

import Pudu.Type.Check.Common (codes)
import qualified Pudu.Compiler.Program.Common as Program
import Test.QuickCheck (Property, conjoin, counterexample, (===))

testDeriveChecked :: IO Property
testDeriveChecked = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str { \"tag\" }"
    , "}"
    ]
  pure $ counterexample "a sound derive checks clean" (found === [])

testDeriveMistakeOnce :: IO Property
testDeriveMistakeOnce = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str { 1 }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "one diagnostic" (length found === 1)
    , counterexample "a mismatch, not a cascade" (found === ["E3001"])
    ]

testDeriveLoopChecked :: IO Property
testDeriveLoopChecked = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str {"
    , "    var out = \"\""
    , "    comptime for x: Int in [1, 2] {"
    , "      out = out"
    , "    }"
    , "    out"
    , "  }"
    , "}"
    ]
  pure $ counterexample "a sound loop checks clean" (found === [])

testDeriveLoopMistakeOnce :: IO Property
testDeriveLoopMistakeOnce = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str {"
    , "    var out = \"\""
    , "    comptime for x: Int in [1, 2] {"
    , "      out = 1"
    , "    }"
    , "    out"
    , "  }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "one diagnostic" (length found === 1)
    , counterexample "reported at the loop body" (found === ["E3001"])
    ]

testDeriveRequestUnchecked :: IO Property
testDeriveRequestUnchecked = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive impl Tag for Line"
    , "type Line = { sku: Str }"
    ]
  pure $ counterexample "a request needs no checking" (found === [])

testDeriveFixtures :: IO Property
testDeriveFixtures = do
  main <- Program.codes "test-fixtures/derive/Main.pudu"
  mainResult <- Program.runEntry "test-fixtures/derive/Main.pudu"
  mistake <- Program.codes "test-fixtures/derive/Mistake.pudu"
  loopMistake <- Program.codes "test-fixtures/derive/LoopMistake.pudu"
  ordinary <- Program.codes "test-fixtures/derive/OrdinaryLoop.pudu"
  badClauses <- Program.codes "test-fixtures/derive/BadClauses.pudu"
  unknown <- Program.codes "test-fixtures/derive/UnknownNames.pudu"
  sums <- Program.codes "test-fixtures/derive/SumShapes.pudu"
  sumsResult <- Program.runEntry "test-fixtures/derive/SumShapes.pudu"
  pure $ conjoin
    [ counterexample "valid program checks clean" (main === [])
    , counterexample "valid program runs" (mainResult === Just "0")
    , counterexample "body mistake once" (mistake === ["E3001"])
    , counterexample "loop mistake once" (loopMistake === ["E3001"])
    , counterexample "ordinary loop refused" (ordinary === ["E3090"])
    , counterexample "each clause mistake once" (badClauses === ["E1064", "E1066", "E1065", "E1067", "E1068"])
    , counterexample "unknown names resolve nowhere" (unknown === ["E2011", "E2011", "E2011"])
    , counterexample "sums check clean" (sums === [])
    , counterexample "sums run" (sumsResult === Just "0")
    ]
