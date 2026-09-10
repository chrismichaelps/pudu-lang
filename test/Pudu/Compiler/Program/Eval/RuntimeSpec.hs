{-| @Test.Compiler.Program.Eval.RuntimeSpec — language features, runtime, effects, and concurrency evaluation -}
module Pudu.Compiler.Program.Eval.RuntimeSpec
  ( testRuntimeEvaluation
  ) where

import Pudu.Compiler.Program.Common (runEntry)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

{-| Evaluates language semantics, generic traits, runtime concurrency, effects, and numeric widths. -}
testRuntimeEvaluation :: IO Property
testRuntimeEvaluation = do
  ran <- runEntry "test-fixtures/stdlib/RunsStd.pudu"
  everything <- runEntry "test-fixtures/stdlib/UsesAll.pudu"
  wide <- runEntry "test-fixtures/stdlib/UsesWide.pudu"
  effects <- runEntry "test-fixtures/stdlib/UsesIo.pudu"
  scheduling <- runEntry "test-fixtures/stdlib/UsesTime.pudu"
  numeric <- runEntry "test-fixtures/stdlib/UsesNumeric.pudu"
  hashing <- runEntry "test-fixtures/stdlib/UsesCrypto.pudu"
  parsing <- runEntry "test-fixtures/stdlib/UsesParse.pudu"
  labelled <- runEntry "test-fixtures/stdlib/UsesLabels.pudu"
  exact <- runEntry "test-fixtures/stdlib/UsesDecimal.pudu"
  generic <- runEntry "test-fixtures/stdlib/UsesGenericTraits.pudu"
  sequences <- runEntry "test-fixtures/stdlib/UsesIter.pudu"
  dynamic <- runEntry "test-fixtures/stdlib/UsesDynamic.pudu"
  registry <- runEntry "test-fixtures/stdlib/UsesRegistry.pudu"
  effectSurface <- runEntry "test-fixtures/stdlib/UsesEffects.pudu"
  routing <- runEntry "test-fixtures/stdlib/UsesRouter.pudu"
  named <- runEntry "test-fixtures/stdlib/UsesNamedVariants.pudu"
  ownSequence <- runEntry "test-fixtures/stdlib/UsesUserSequence.pudu"
  acrossModules <- runEntry "test-fixtures/namedvariants/Main.pudu"
  sumTraits <- runEntry "test-fixtures/stdlib/UsesSumTraits.pudu"
  longLoops <- runEntry "test-fixtures/stdlib/UsesLongLoops.pudu"
  widthPatterns <- runEntry "test-fixtures/stdlib/UsesWidthPatterns.pudu"
  declaredWidths <- runEntry "test-fixtures/stdlib/UsesWidths.pudu"
  widths <- runEntry "test-fixtures/stdlib/UsesNumericWidths.pudu"
  higherKinds <- runEntry "test-fixtures/stdlib/UsesHigherKinds.pudu"
  streams <- runEntry "test-fixtures/stdlib/UsesStreams.pudu"
  paths <- runEntry "test-fixtures/stdlib/UsesPath.pudu"
  identifiers <- runEntry "test-fixtures/stdlib/UsesUuid.pudu"
  calendars <- runEntry "test-fixtures/stdlib/UsesTimeFormat.pudu"
  measurements <- runEntry "test-fixtures/stdlib/UsesBench.pudu"
  threads <- runEntry "test-fixtures/stdlib/UsesConcurrent.pudu"
  enterpriseSsr <- runEntry "test-fixtures/stdlib/UsesEnterpriseSsr.pudu"
  jwtApp <- runEntry "test-fixtures/stdlib/UsesJwt.pudu"
  callbacks <- runEntry "test-fixtures/stdlib/UsesCallbacks.pudu"
  scoped2 <- runEntry "test-fixtures/stdlib/UsesVariantScope.pudu"
  numbers <- runEntry "test-fixtures/stdlib/UsesNumberText.pudu"
  characters <- runEntry "test-fixtures/stdlib/UsesCharAll.pudu"
  textual <- runEntry "test-fixtures/stdlib/UsesTextAll.pudu"
  optionResult <- runEntry "test-fixtures/stdlib/UsesOptionResultAll.pudu"
  ordered <- runEntry "test-fixtures/stdlib/UsesOrderAll.pudu"
  bitwise <- runEntry "test-fixtures/stdlib/UsesBitsAll.pudu"
  files <- runEntry "test-fixtures/stdlib/UsesIoAll.pudu"
  octets <- runEntry "test-fixtures/stdlib/UsesBytesAll.pudu"
  moments <- runEntry "test-fixtures/stdlib/UsesTimeAll.pudu"
  everyParser <- runEntry "test-fixtures/stdlib/UsesParseAll.pudu"
  altered <- runEntry "test-fixtures/stdlib/UsesRecordUpdate.pudu"
  reached <- runEntry "test-fixtures/stdlib/UsesForeign.pudu"
  scoped <- runEntry "test-fixtures/scoped/Main.pudu"
  aliased <- runEntry "test-fixtures/program29/B.pudu"
  pure $ conjoin
    [ {-| Every export of the character module, each predicate asked once of a
          character that holds it and once of one that does not, since a
          predicate that never refuses is not one. -}
      counterexample
        "every character class answers for what it holds and what it does not"
        (characters === Just "35")
    {-| Every export of the text module against a stated answer, measured in
        characters rather than bytes: the checks that could tell the two apart
        use text carrying a character that is more than one byte. The empty
        case is checked beside the present one, which is where `rest` was
        found to refuse rather than answer nothing. -}
    , counterexample
        "every text operation answers what it says it answers"
        (textual === Just "82")
    {-| Every export of the option and result modules, each asked of a value
        that is there and one that is not. These two exist for the absent
        case, so a check that only covered the present one would be the half
        nobody needed. -}
    , counterexample
        "an option and a result answer for the absent case as well as the present one"
        (optionResult === Just "73")
    {-| Every export of the ordering module, asked in all three directions.
        Two of the three would pass for a comparison that never answers equal,
        which is the one most easily written by mistake. -}
    , counterexample
        "every comparison answers less, equal and greater"
        (ordered === Just "42")
    {-| Every export of the bit module at a stated width. A function reading
        the width from the wrong place would answer for sixty-four bits and be
        wrong here by exactly that difference. -}
    , counterexample
        "every bit operation answers for the width it was given"
        (bitwise === Just "39")
    {-| Every export of the file module, checked by writing and reading back
        under the machine's own temporary directory, with everything made
        taken away again. -}
    , counterexample
        "every file operation writes what can be read back"
        (files === Just "45")
    {-| Every export of the byte module, with the two orders checked against
        each other as well as against their own answers: a pair of functions
        that agreed with each other but not with the wire would pass every
        check that only asked one of them. -}
    , counterexample
        "every byte operation answers the bytes it says it answers"
        (octets === Just "55")
    {-| Every export of the time module against a stated moment rather than a
        reading of the clock, so every answer is fixed. The two that do read
        the clock are asked only what holds of any reading. -}
    , counterexample
        "every time operation answers for a stated moment"
        (moments === Just "40")
    {-| Every export of the parser module, on text it accepts and text it
        refuses. A parser is only worth its name if it also refuses, and
        `run` insists the whole text is consumed, so one that stopped early is
        caught here rather than by whoever fed it. -}
    , counterexample
        "every parser accepts what it names and refuses what it does not"
        (everyParser === Just "75")
    , counterexample "an aliased and a selected import both evaluate"
        (ran === Just "35")
    , counterexample "generic and text modules link together"
        (everything === Just "8")
    {-| One definition serving several containers, which is the whole reason a
        parameter may stand for a constructor. Every check goes through a
        definition that names no container, so a function copied per container
        would pass none of them. -}
    , counterexample
        "a parameter standing for a constructor serves every container"
        (higherKinds === Just "14")
    {-| A file is read a chunk at a time, so what the walk costs does not
        depend on how large the file is, and a line divided by a chunk
        boundary is still one line. -}
    , counterexample
        "a stream reads and writes without holding the whole file"
        (streams === Just "21")
    {-| A path is decided by reading it rather than by asking the file system,
        so it needs nothing to exist and does not follow a link. -}
    , counterexample
        "a path comes apart, normalizes, and says what it is inside"
        (paths === Just "35")
    {-| An identifier is sixteen bytes rather than the text it is quoted in,
        and a seeded generator makes the same one twice, so a failure over a
        particular identifier can be made to happen again. -}
    , counterexample
        "an identifier records its scheme and round trips through its text"
        (identifiers === Just "24")
    {-| The calendar is arithmetic rather than a table, so it answers for a
        moment before the count of milliseconds starts and for both of the
        centuries a naive leap-year rule gets wrong. -}
    , counterexample
        "a moment written as text reads back as the moment it named"
        (calendars === Just "50")
    {-| Readings are built rather than timed: a check against the clock would
        answer differently on a machine that was busy, and a failure for that
        reason says nothing about the code. -}
    , counterexample
        "a measurement reports its spread rather than one stopwatch reading"
        (measurements === Just "31")
    {-| Four threads each adding a thousand times total four thousand. Without
        the lock underneath, reading and writing a cell are two steps, and two
        threads read the same number and write the same number — losing
        additions only under the load that makes the loss hardest to find. -}
    , counterexample
        "threads share a channel, a lock, and a cell without losing a write"
        (threads === Just "32")
    , counterexample
        "enterprise SSR compiles unboxed buffers, streams suspense chunks, and enforces 1-RTT resilience"
        (enterpriseSsr === Just "90")
    , counterexample
        "RFC 7519 JSON Web Tokens encode, decode, and validate signatures and claims"
        (jwtApp === Just "15")
    {-| A declaration carries no captured environment, so it runs in the frame
        of whoever called it. A named function handed to another module ran
        without its own imports and reported them undefined at run time, having
        type-checked; the root's declarations now carry the root's environment
        exactly as a dependency's do. -}
    , counterexample
        "a declared function works wherever it is called from"
        (callbacks === Just "8")
    {-| That a pattern matches the variant the module named. Two modules here
        each declare a `Text`; only one is in scope unqualified, and reading
        the name against a table holding every loaded module's variants made
        the answer depend on which module was loaded last. Wired-in variants
        reached without an import, and generic sums carrying their arguments
        through a pattern, are checked alongside so the narrower resolution
        did not lose them. -}
    , counterexample
        "a pattern matches the variant the module named"
        (scoped2 === Just "11")
    {-| That reading a number from text is two questions: a whole number may be
        below nothing, a count may not. Twelve modules each carried a copy of
        this and they did not agree, silently. -}
    , counterexample
        "a count and a whole number are read differently"
        (numbers === Just "25")
    {-| That a record may be written as another record with some fields
        different. Without it, changing one field of a ten-field record means
        writing the other nine out — nine chances to copy one wrong, with the
        field the expression is actually about invisible among them. The base
        is untouched, the declared field order survives either spelling, and a
        record written whole equals one written as a change. -}
    , counterexample
        "a record may be written as a change to another"
        (altered === Just "22")
    {-| A library written elsewhere, actually called. Text crossing as bytes
        ending in a nought, a narrow integer and a wide one reaching different
        symbols, doubles arriving in their own registers, and a mixture of the
        classes — which is the case a boundary assembled by hand gets wrong
        first, because arguments of different classes are placed by different
        rules and one counted into the wrong place arrives as whatever was
        there. [[ADR-0018]] states what may cross. -}
    , counterexample
        "a library written elsewhere is reached through a declared boundary"
        (reached === Just "12")
    , counterexample "every standard module links into one program"
        (wide === Just "64")
    , counterexample "the effect modules reach the world and report failures"
        (effects === Just "19")
    , counterexample "the time and process modules reach the world"
        (scheduling === Just "84")
    , counterexample "the numeric surface is generic over the integer family"
        (numeric === Just "96")
    , counterexample "SHA-256 written in Pudu matches its published vectors"
        (hashing === Just "10")
    , counterexample "the parser combinators build a grammar and report positions"
        (parsing === Just "22")
    , counterexample "labelled loops break and continue across nesting"
        (labelled === Just "4")
    , counterexample "a named variant is built and matched by its names, and by the name it writes"
        (named === Just "119")
    , counterexample "a type that writes its own Sequence is iterated by it"
        (ownSequence === Just "45")
    , counterexample "an imported variant carries the names its declaration gave it"
        (acrossModules === Just "24")
    , counterexample "a trait implemented for a sum reaches every variant's value"
        (sumTraits === Just "88")
    , counterexample "a running program loops as long as its work takes"
        (longLoops === Just "127")
    , counterexample "matching and equality agree about a number's width"
        (widthPatterns === Just "63")
    , counterexample "a declared width is enforced wherever the value came from"
        (declaredWidths === Just "63")
    , counterexample "decimal arithmetic is exact and rounds only when told"
        (exact === Just "12")
    , counterexample "a generic trait's parameters follow its implementation"
        (generic === Just "5")
    , counterexample "a user type and lazy adapters use the open sequence protocol"
        (sequences === Just "14")
    , counterexample "drawing and parsing keep the caller's integer type"
        (widths === Just "8")
    , counterexample "a module calls the function it declared, not a stranger's"
        (scoped === Just "2")
    , counterexample "a dynamic type holds any implementation of its trait"
        (dynamic === Just "9")
    , counterexample "traits, dynamic values, and bounded generics compose"
        (registry === Just "6")
    , counterexample "a program writes, reads, and removes a file and reports failure"
        (effectSurface === Just "6")
    , counterexample "the protocol, keyed, and url modules serve one program"
        (routing === Just "7")
    , counterexample "a program with no entry point evaluates to unit"
        (aliased === Just "()")
    ]
