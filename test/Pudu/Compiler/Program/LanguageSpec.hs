{-| @Test.Compiler.Program.LanguageSpec — function literals, ranges, slices, and destructuring bindings -}
module Pudu.Compiler.Program.LanguageSpec
  ( testCapturedScope
  , testDestructuringBindings
  , testFunctionLiterals
  , testLanguageRefusals
  , testRangesAndSlices
  ) where

import Pudu.Compiler.Program.Common (codes, runEntry, runtimeCodes)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

fixture :: String -> FilePath
fixture name = "test-fixtures/language/" <> name <> ".pudu"

{-| A function literal behaves as a value in every position a value goes.

    The fixture answers with one number built from every spelling and every
    placement — stored in a record, held in an array, returned from a call,
    called where it was made — so a literal that works only in the position it
    was first written in moves the total. -}
testFunctionLiterals :: IO Property
testFunctionLiterals = do
  answer <- runEntry (fixture "Lambdas")
  pure $
    counterexample "every literal spelling and position answers together"
      (answer === Just "201")

{-| A range is a value, and indexing by one is a slice.

    The range fixture walks twenty million values without building them, which
    is the property that matters: it finishes in the suite's own time and
    memory, and it would do neither if a range were the list it stands for. -}
testRangesAndSlices :: IO Property
testRangesAndSlices = do
  ranges <- runEntry (fixture "Ranges")
  slices <- runEntry (fixture "Slices")
  pure $ conjoin
    [ counterexample "a range answers for its extent and hands back its values on request"
        (ranges === Just "66")
    , counterexample "indexing by a range reads the stretch it names"
        (slices === Just "147")
    ]

{-| What a function literal can still reach after it leaves the scope it was
    written in.

    A literal holds the names it mentions and the program's own declarations,
    not everything that happened to be in scope beside it — so a literal stored
    in a table no longer holds the array that was standing next to it. That is a
    narrowing, and a narrowing is only safe if nothing it drops was reachable,
    which is what the fixture checks: every way a literal reaches a name, asked
    after the literal has been carried away from where it was written. -}
testCapturedScope :: IO Property
testCapturedScope = do
  answer <- runEntry (fixture "Captures")
  pure $
    counterexample "every way a literal reaches a name survives being carried away"
      (answer === Just "1155")

{-| A binding takes a record, a tuple, and a sequence apart, and the names it
    introduces belong to the block it stands in. -}
testDestructuringBindings :: IO Property
testDestructuringBindings = do
  answer <- runEntry (fixture "Destructuring")
  pure $
    counterexample "every shape a binding takes apart answers together"
      (answer === Just "296")

{-| What the three features refuse, and where.

    A malformed range and a binding whose pattern can fail are read off the
    shape the writer wrote, so they are parse diagnostics. A range over text and
    a slice of a tuple are about types. A slice past the end and a sequence of
    the wrong length are only knowable while the program runs, so they abort
    there rather than being guessed at earlier. -}
testLanguageRefusals :: IO Property
testLanguageRefusals = do
  chained <- codes (fixture "RejectsChainedRange")
  openInclusive <- codes (fixture "RejectsOpenInclusiveRange")
  fallible <- codes (fixture "RejectsFallibleBinding")
  tupleSlice <- codes (fixture "RejectsTupleSlice")
  sliceAssignment <- codes (fixture "RejectsSliceAssignment")
  unknownMethod <- codes (fixture "RejectsUnknownRangeMethod")
  textRange <- codes (fixture "RejectsTextRange")
  pastEnd <- runtimeCodes (fixture "SliceOutOfBounds")
  lengthMismatch <- runtimeCodes (fixture "SequenceLengthMismatch")
  unbounded <- runtimeCodes (fixture "UnboundedRangeWalk")
  pure $ conjoin
    [ counterexample "a range has two ends" (chained === ["E1062"])
    , counterexample "an inclusive range names the value it includes"
        (openInclusive === ["E1063"])
    , counterexample "a binding whose pattern can fail needs somewhere to go"
        (fallible === ["E1059"])
    , counterexample "a tuple has no one type to slice to" (tupleSlice === ["E3006"])
    , counterexample "a slice is a value, not a place" (sliceAssignment === ["E3077"])
    , counterexample "the range methods are a closed set" (unknownMethod === ["E3005"])
    , counterexample "a range counts, so its ends are whole numbers"
        (textRange === ["E3001"])
    , counterexample "a slice past the end is reported, not clamped"
        (pastEnd === ["E7004"])
    , counterexample "a sequence of the wrong length is reported at the binding"
        (lengthMismatch === ["E7013"])
    , counterexample "a range with no end cannot hand back its values"
        (unbounded === ["E7004"])
    ]
