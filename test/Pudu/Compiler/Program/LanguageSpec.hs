{-| @Test.Compiler.Program.LanguageSpec — function literals, ranges, slices, and destructuring bindings -}
module Pudu.Compiler.Program.LanguageSpec
  ( testCapturedScope
  , testDestructuringBindings
  , testFunctionLiterals
  , testLanguageRefusals
  , testRangesAndSlices
  ) where

import qualified Data.Sequence as Seq
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Compiler.Program.Common
  ( codes, runEntry, runEntryValue, runtimeCodes, runtimeDetails )
import Pudu.Eval.Match (matchPattern)
import Pudu.Eval.Value (Captured (..), Closure (..), Value (..), intOf)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Pattern (..))
import Pudu.Source (SourceName (SourceName), emptySpan, newSource)
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
  existing <- runEntry (fixture "Lambdas")
  forms <- runEntry (fixture "LambdaForms")
  composition <- runEntry (fixture "LambdaComposition")
  asynchronous <- runEntry (fixture "AsyncLambda")
  pure $ conjoin
    [ counterexample "every literal spelling and position answers together"
        (existing === Just "201")
    , counterexample "both literal spellings work in every value position"
        (forms === Just "236")
    , counterexample "literals compose and cross collection boundaries"
        (composition === Just "167")
    , counterexample "an async short literal remains a cold task until awaited"
        (asynchronous === Just "42")
    ]

{-| A range is a value, and indexing by one is a slice.

    The range fixture walks twenty million values without building them, which
    is the property that matters: it finishes in the suite's own time and
    memory, and it would do neither if a range were the list it stands for. -}
testRangesAndSlices :: IO Property
testRangesAndSlices = do
  ranges <- runEntry (fixture "Ranges")
  slices <- runEntry (fixture "Slices")
  forms <- runEntry (fixture "RangeForms")
  loops <- runEntry (fixture "RangeLoops")
  methods <- runEntry (fixture "RangeMethods")
  sliceForms <- runEntry (fixture "SliceForms")
  pure $ conjoin
    [ counterexample "a range answers for its extent and hands back its values on request"
        (ranges === Just "66")
    , counterexample "indexing by a range reads the stretch it names"
        (slices === Just "147")
    , counterexample "every bounded and open range form remains a first-class value"
        (forms === Just "56")
    , counterexample "range loops stream across control-flow forms"
        (loops === Just "233")
    , counterexample "every range method answers at its boundary values"
        (methods === Just "231")
    , counterexample "array text and byte slices preserve their value kind"
        (sliceForms === Just "233")
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
  imported <- runEntryValue "test-fixtures/capturedependency/Main.pudu"
  let importedCapture = case imported of
        Just (FunctionValue Closure
          { closureCaptured = Just Captured
              { capturedEnvironment = frames
              , capturedModuleDepth = moduleDepth
              }
          }) ->
            let locals = take (length frames - moduleDepth) frames
                names = Map.keysSet (Map.unions locals)
             in Just
                  ( length locals
                  , Set.member "kept" names
                  , Set.member "unused" names
                  )
        _ -> Nothing
  pure $ conjoin
    [ counterexample "every way a literal reaches a name survives being carried away"
        (answer === Just "1155")
    , counterexample
        "an imported closure keeps its module boundary and only reachable call locals"
        (importedCapture === Just (1, True, False))
    ]

{-| A binding takes a record, a tuple, and a sequence apart, and the names it
    introduces belong to the block it stands in. -}
testDestructuringBindings :: IO Property
testDestructuringBindings = do
  existing <- runEntry (fixture "Destructuring")
  records <- runEntry (fixture "DestructureRecords")
  pure $ conjoin
    [ counterexample "every shape a binding takes apart answers together"
        (existing === Just "296")
    , counterexample "record bindings rename nest omit annotate and remain in scope"
        (records === Just "167")
    ]

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
  tupleSequence <- codes (fixture "RejectsTupleSequencePattern")
  pastEnd <- runtimeCodes (fixture "SliceOutOfBounds")
  reversedSlice <- runtimeDetails (fixture "SliceEndsBeforeStart")
  negativeInclusive <- runtimeDetails (fixture "SliceNegativeInclusive")
  lengthMismatch <- runtimeCodes (fixture "SequenceLengthMismatch")
  unbounded <- runtimeCodes (fixture "UnboundedRangeWalk")
  unboundedLength <- runtimeDetails (fixture "UnboundedRangeLength")
  openStartLength <- runtimeDetails (fixture "OpenStartRangeLength")
  openLength <- runtimeDetails (fixture "OpenRangeLength")
  zeroStep <- runtimeCodes (fixture "InvalidRangeStep")
  lengthOverflow <- runtimeDetails (fixture "RangeLengthOverflow")
  sumOverflow <- runtimeDetails (fixture "RangeSumOverflow")
  source <- newSource (SourceName "sequence-pattern-test.pudu") ""
  let at = emptySpan source
      first = Located at (BindingPattern (Located at "first"))
      sequencePattern = Located at (ArrayPattern [first] Nothing [])
      arrayMatch = matchPattern sequencePattern (ArrayValue (Seq.singleton (intOf 1)))
      tupleMatch = matchPattern sequencePattern (TupleValue [intOf 1])
      diagnostic code message help spanValue = [(code, message, Just help, spanValue)]
      extentAt = diagnostic "E7004" "length needs a range with both ends"
        "check isBounded first, or give the range a start and an end"
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
    , counterexample "a sequence pattern cannot claim one type for tuple members"
        (tupleSequence === ["E3001"])
    , counterexample "a slice past the end is reported, not clamped"
        (pastEnd === ["E7004"])
    , counterexample "a slice cannot end before it starts"
        ( reversedSlice
            === diagnostic "E7004" "slice range ends before it starts"
              "write the lower bound first" (237, 243)
        )
    , counterexample "an inclusive slice validates its written negative end"
        ( negativeInclusive
            === diagnostic "E7004" "slice range out of bounds"
              "the range must lie within the value; it has 3 elements" (237, 243)
        )
    , counterexample "a sequence of the wrong length is reported at the binding"
        (lengthMismatch === ["E7013"])
    , counterexample "a range with no end cannot hand back its values"
        (unbounded === ["E7004"])
    , counterexample "an unbounded range does not pretend to have zero length"
        (unboundedLength === extentAt (248, 264))
    , counterexample "a range with no start has no measurable extent"
        (openStartLength === extentAt (218, 234))
    , counterexample "a range with neither end has no measurable extent"
        (openLength === extentAt (148, 164))
    , counterexample "a range step must advance"
        (zeroStep === ["E7004"])
    , counterexample "a range length must fit its declared Int result"
        ( lengthOverflow
            === diagnostic "E7005" "Int cannot hold this range's length"
              "narrow the range or compute with BigInt values explicitly" (200, 234)
        )
    , counterexample "a range sum must fit its declared Int result"
        ( sumOverflow
            === diagnostic "E7005" "Int cannot hold this range's sum"
              "narrow the range or compute with BigInt values explicitly" (204, 253)
        )
    , counterexample "an array sequence pattern binds its element"
        (arrayMatch === Just [("first", intOf 1)])
    , counterexample "the evaluator does not admit a tuple as an array pattern"
        (tupleMatch === Nothing)
    ]
