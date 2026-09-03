module Pudu.Compiler.ProgramSpec (programProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Map.Strict as Map
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileContext (..), CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , programDependencies
  , programIntegerKinds
  , rootCompileResult
  )
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticHelp
  , diagnosticMessage)
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Repl.Session
  ( EntryResult (..)
  , Session (..)
  , emptySession
  , loadModule
  , submitEntry
  )
import Test.QuickCheck (Property, conjoin, counterexample, (===))

programProperties :: [(String, IO Property)]
programProperties =
  [ ("program compilation resolves imported trait methods", testImportedMethods)
  , ("program compilation preserves module privacy and trait scope", testImportFailures)
  , ("program discovery diagnoses missing and mismatched modules", testDiscoveryFailures)
  , ("program graphs preserve nominal identity and signature cycles", testGraphEdges)
  , ("program interfaces preserve ABI identity defaults and ambiguity", testInterfaceEdges)
  , ("REPL loads retain the program interface context", testReplLoadContext)
  , ("the standard library resolves from the distribution", testStandardLibrary)
  , ("an imported module is linked into evaluation", testProgramEvaluation)
  , ("a module cannot lend its name to a type it does not declare", testQualifiedTypeNames)
  ]

{-| A qualified type name is judged only against a module the compiler read.

    An unfound one used to become a nominal type of its own, named after what
    was written, so `Mp.Map[Str, Int]` was a different type from `Map[Str, Int]`
    and the reader was told "expected Mp.Map[Str, Int], found Map[a, b]" — two
    names that read alike, about a type that never existed, at a line that was
    not the mistake.

    The cases that must stay silent are the point of the test. A type a module
    really declares looks exactly like one it does not when the module's
    interface was never available, and an earlier attempt that could not tell
    those apart reported correct code in the standard library. That is also why
    this lives here rather than beside the other type-checking properties: those
    compile a module on its own, with no interfaces at all, and this rule
    deliberately says nothing then. -}
testQualifiedTypeNames :: IO Property
testQualifiedTypeNames = do
  builtinThroughModule <- codes "test-fixtures/qualified/RejectsBuiltinThroughModule.pudu"
  neverDeclared <- codes "test-fixtures/qualified/RejectsUndeclaredType.pudu"
  wrongModule <- codes "test-fixtures/qualified/RejectsWrongModuleType.pudu"
  advice <- helps "test-fixtures/qualified/RejectsBuiltinThroughModule.pudu"
  declared <- runEntry "test-fixtures/qualified/UsesQualifiedTypes.pudu"
  pure $ conjoin
    [ counterexample "a built-in reached through a module is reported"
        (builtinThroughModule === ["E3035"])
    , counterexample "a name the module never declares is reported"
        (neverDeclared === ["E3035"])
    , counterexample "a type asked of the wrong module is reported"
        (wrongModule === ["E3035"])
    , counterexample "the advice names the spelling that works"
        (advice === ["Map stands on its own; write it without Mp."])
    , counterexample "types the modules do declare are left alone"
        (declared === Just "3")
    ]

testImportedMethods :: IO Property
testImportedMethods = do
  found <- codes "test-fixtures/program29/B.pudu"
  pure (found === [])

testImportFailures :: IO Property
testImportFailures = do
  hiddenTrait <- codes "test-fixtures/program29/C.pudu"
  privateName <- codes "test-fixtures/program29/D.pudu"
  pure $ conjoin
    [ counterexample "a method requires its trait import" (hiddenTrait === ["E3005"])
    , counterexample "private selections are rejected at the import" (privateName === ["E2013"])
    ]

testDiscoveryFailures :: IO Property
testDiscoveryFailures = do
  missing <- codes "test-fixtures/program29/E.pudu"
  mismatch <- codes "test-fixtures/program29/Wrong.pudu"
  pure $ conjoin
    [ missing === ["E2014"]
    , mismatch === ["E2015"]
    ]

testGraphEdges :: IO Property
testGraphEdges = do
  collision <- codes "test-fixtures/program29/Collision.pudu"
  signatureCycle <- codes "test-fixtures/program29/CycleA.pudu"
  importedValue <- codes "test-fixtures/program29/Values.pudu"
  importedDefault <- codes "test-fixtures/program29/Default.pudu"
  transitive <- compileProgram "test-fixtures/program29/TransitiveRoot.pudu"
  ordered <- compileProgram "test-fixtures/program29/B.pudu"
  let transitiveCount = length (foldr (:) [] (programModules transitive))
      orderNames = map moduleNameText (programOrder ordered)
  pure $ conjoin
    [ counterexample "same basenames retain distinct nominal identities" (collision === [])
    , counterexample "signature cycles terminate and type-check" (signatureCycle === [])
    , counterexample "body-free function signatures cross modules" (importedValue === [])
    , counterexample "body-free interfaces retain default availability" (importedDefault === [])
    , counterexample "transitive discovery loads every dependency once" (transitiveCount === 3)
    , counterexample "dependencies precede consumers" (orderNames === ["A", "B"])
    ]

testInterfaceEdges :: IO Property
testInterfaceEdges = do
  privateCollision <- codes "test-fixtures/program29/HiddenCollision.pudu"
  ambiguity <- codes "test-fixtures/program29/AmbiguousRoot.pudu"
  mixedAmbiguity <- codes "test-fixtures/program29/MixedAmbiguity.pudu"
  foreignDefault <- codes "test-fixtures/program29/ForeignDefault.pudu"
  incomplete <- codes "test-fixtures/program29/Incomplete.pudu"
  incompleteConsumer <- codes "test-fixtures/program29/IncompleteRoot.pudu"
  unreadableRoot <- codes "test-fixtures/program29"
  pure $ conjoin
    [ counterexample "private identities behind public aliases stay distinct"
        (privateCollision === ["E3001"])
    , counterexample "two visible traits cannot overwrite concrete dispatch"
        (ambiguity === ["E3013"])
    , counterexample "a local provider cannot overwrite an imported provider"
        (mixedAmbiguity === ["E3013"])
    , counterexample "defaults cross a foreign-trait implementation boundary"
        (foreignDefault === [])
    , counterexample "body-free implementation methods require a complete ABI"
        (incomplete === ["E3010", "E3010"])
    , counterexample "an incomplete method is omitted from consumer inference"
        (incompleteConsumer === ["E3010", "E3010", "E3005"])
    , counterexample "an unreadable root is a structured loader failure"
        (unreadableRoot === ["E2014"])
    ]

{-| The `Std` namespace resolves without the program declaring anything, and
    the program's own tree still wins when it declares a standard module
    itself — deliberately and visibly, since the file is in its own source
    root. -}
testStandardLibrary :: IO Property
testStandardLibrary = do
  uses <- codes "test-fixtures/stdlib/UsesStd.pudu"
  shadows <- codes "test-fixtures/stdshadow/ShadowsStd.pudu"
  missing <- codes "test-fixtures/stdlib/MissingStd.pudu"
  missingHelp <- messages "test-fixtures/stdlib/MissingStd.pudu"
  ordinary <- codes "test-fixtures/stdlib/MissingOwn.pudu"
  floatRangeDiagnostics <- codes "test-fixtures/stdlib/RejectsFloatRange.pudu"
  missingMember <- codes "test-fixtures/stdlib/RejectsMissingMember.pudu"
  missingMemberHelp <- helps "test-fixtures/stdlib/RejectsMissingMember.pudu"
  unqualifiedHelp <- helps "test-fixtures/stdlib/RejectsUnqualifiedMember.pudu"
  unknownHelp <- helps "test-fixtures/stdlib/RejectsUnknownMember.pudu"
  resolved <- moduleNames "test-fixtures/stdlib/UsesStd.pudu"
  pure $ conjoin
    [ counterexample "a standard import compiles with no program-local module" (uses === [])
    , counterexample "a program may shadow a standard module" (shadows === [])
    , counterexample "an unknown standard module is a missing module" (missing === ["E2014"])
    , counterexample "the diagnostic names the module that could not be read"
        (any (Text.isInfixOf "Std.NotAThing") missingHelp === True)
    , counterexample "an unknown ordinary module is still a missing module" (ordinary === ["E2014"])
    , counterexample "a numeric range still requires a whole-number type"
        (floatRangeDiagnostics === ["E3012"])
    , counterexample "a member the module does not export is reported once"
        (missingMember === ["E3033"])
    , counterexample "a built-in method written as a module function says so"
        (any (Text.isInfixOf "built-in method") missingMemberHelp === True)
    , counterexample "a prelude binding reached through a module says so instead"
        (any (Text.isInfixOf "available unqualified") unqualifiedHelp === True)
    , counterexample "and a name that is neither only says to check the exports"
        (any (Text.isInfixOf "check the spelling against what") unknownHelp === True)
    , counterexample "the standard module joins the program graph"
        (elem "Std.Math" resolved === True)
    ]

{-| A program's imports are linked before its entry point runs, so a call into
    an imported module finds the function it named — including one in the
    standard library, and including a helper that module keeps private. -}
testProgramEvaluation :: IO Property
testProgramEvaluation = do
  ran <- runEntry "test-fixtures/stdlib/RunsStd.pudu"
  everything <- runEntry "test-fixtures/stdlib/UsesAll.pudu"
  collections <- runEntry "test-fixtures/stdlib/UsesList.pudu"
  wide <- runEntry "test-fixtures/stdlib/UsesWide.pudu"
  keyed <- runEntry "test-fixtures/stdlib/UsesKeyed.pudu"
  keyedInvariants <- runEntry "test-fixtures/stdlib/KeyedInvariants.pudu"
  formats <- runEntry "test-fixtures/stdlib/UsesFormats.pudu"
  jsonStrings <- runEntry "test-fixtures/stdlib/UsesJsonStrings.pudu"
  protocol <- runEntry "test-fixtures/stdlib/UsesHttp.pudu"
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
  realFormats <- runEntry "test-fixtures/stdlib/UsesFormats2.pudu"
  widthPatterns <- runEntry "test-fixtures/stdlib/UsesWidthPatterns.pudu"
  declaredWidths <- runEntry "test-fixtures/stdlib/UsesWidths.pudu"
  widths <- runEntry "test-fixtures/stdlib/UsesNumericWidths.pudu"
  structures <- runEntry "test-fixtures/stdlib/UsesStructures.pudu"
  orderedMaps <- runEntry "test-fixtures/stdlib/UsesOrderedMaps.pudu"
  relationalMaps <- runEntry "test-fixtures/stdlib/UsesRelationalMaps.pudu"
  cacheAndTrie <- runEntry "test-fixtures/stdlib/UsesCacheAndTrie.pudu"
  graphEdges <- runEntry "test-fixtures/stdlib/UsesGraphEdges.pudu"
  lookupTables <- runEntry "test-fixtures/stdlib/UsesLookupTables.pudu"
  printers <- runEntry "test-fixtures/stdlib/UsesOut.pudu"
  shaping <- runEntry "test-fixtures/stdlib/UsesFmt.pudu"
  checking <- runEntry "test-fixtures/stdlib/UsesTest.pudu"
  logging <- runEntry "test-fixtures/stdlib/UsesLog.pudu"
  hierarchies <- runEntry "test-fixtures/stdlib/UsesTree.pudu"
  higherKinds <- runEntry "test-fixtures/stdlib/UsesHigherKinds.pudu"
  byteSequences <- runEntry "test-fixtures/stdlib/UsesBytes.pudu"
  streams <- runEntry "test-fixtures/stdlib/UsesStreams.pudu"
  paths <- runEntry "test-fixtures/stdlib/UsesPath.pudu"
  identifiers <- runEntry "test-fixtures/stdlib/UsesUuid.pudu"
  separated <- runEntry "test-fixtures/stdlib/UsesCsv.pudu"
  calendars <- runEntry "test-fixtures/stdlib/UsesTimeFormat.pudu"
  measurements <- runEntry "test-fixtures/stdlib/UsesBench.pudu"
  threads <- runEntry "test-fixtures/stdlib/UsesConcurrent.pudu"
  endpoints <- runEntry "test-fixtures/stdlib/UsesNet.pudu"
  callbacks <- runEntry "test-fixtures/stdlib/UsesCallbacks.pudu"
  hashed <- runEntry "test-fixtures/stdlib/UsesHashMap.pudu"
  configured <- runEntry "test-fixtures/stdlib/UsesToml.pudu"
  secured <- runEntry "test-fixtures/stdlib/UsesTls.pudu"
  serving <- runEntry "test-fixtures/stdlib/UsesHttpServer.pudu"
  database <- runEntry "test-fixtures/stdlib/UsesDb.pudu"
  wired <- runEntry "test-fixtures/stdlib/UsesApp.pudu"
  markup <- runEntry "test-fixtures/stdlib/UsesHtml.pudu"
  screens <- runEntry "test-fixtures/stdlib/UsesUi.pudu"
  refused <- runEntry "test-fixtures/stdlib/UsesGuard.pudu"
  schemas <- runEntry "test-fixtures/stdlib/UsesMigrate.pudu"
  probes <- runEntry "test-fixtures/stdlib/UsesHealth.pudu"
  measured <- runEntry "test-fixtures/stdlib/UsesMetrics.pudu"
  permitted <- runEntry "test-fixtures/stdlib/UsesAccess.pudu"
  fetched <- runEntry "test-fixtures/stdlib/UsesHttpClient.pudu"
  checked <- runEntry "test-fixtures/stdlib/UsesValidate.pudu"
  lasting <- runEntry "test-fixtures/stdlib/UsesSocket.pudu"
  driven <- runEntry "test-fixtures/stdlib/UsesLive.pudu"
  scoped2 <- runEntry "test-fixtures/stdlib/UsesVariantScope.pudu"
  statements <- runEntry "test-fixtures/stdlib/UsesQuery.pudu"
  numbers <- runEntry "test-fixtures/stdlib/UsesNumberText.pudu"
  mapped <- runEntry "test-fixtures/stdlib/UsesRepository.pudu"
  submitted <- runEntry "test-fixtures/stdlib/UsesBind.pudu"
  columns <- runEntry "test-fixtures/stdlib/UsesSchema.pudu"
  kept <- runEntry "test-fixtures/stdlib/UsesStore.pudu"
  shaped <- runEntry "test-fixtures/stdlib/UsesQueryShape.pudu"
  altered <- runEntry "test-fixtures/stdlib/UsesRecordUpdate.pudu"
  proved <- runEntry "test-fixtures/stdlib/UsesPassword.pudu"
  scoped <- runEntry "test-fixtures/scoped/Main.pudu"
  aliased <- runEntry "test-fixtures/program29/B.pudu"
  pure $ conjoin
    [ counterexample "an aliased and a selected import both evaluate"
        (ran === Just "35")
    , counterexample "generic and text modules link together"
        (everything === Just "8")
    , counterexample
        "a sequence that cannot be empty, a queue with two ends, a heap, and a graph"
        (structures === Just "0")
    {-| The three ordered maps, including the cases easiest to get wrong: a
        boundary landing exactly on an entry, a key that is absent, an empty
        structure, and a re-insertion that must not move anything. Each check
        answers 1, so a shortfall names how many failed. -}
    , counterexample
        "a map with neighbours, a map that remembers its order, and a total map"
        (orderedMaps === Just "38")
    {-| The relational maps, weighted toward the invariants that break quietly:
        a two-way map staying a bijection when a value collides, a multi-map
        never reporting a key whose values ran out, and a partial index staying
        in step with the entries it indexes. Each check answers 1. -}
    , counterexample
        "a map read from both sides, a map of many values, and a map keyed by parts"
        (relationalMaps === Just "42")
    {-| The bounded cache and the prefix trie, weighted toward what is easy to
        get wrong: that a read counts as use and a peek does not, that the
        capacity holds on every write, and that removing a key gives back the
        path it did not share. Each check answers 1. -}
    , counterexample
        "a cache that discards what is unused, and keys reachable by their prefix"
        (cacheAndTrie === Just "42")
    {-| The graph's edge behaviour, checked directly rather than inferred from
        the walks, because a multi-valued map is a reasonable place to
        deduplicate and this one deliberately does not. These held before the
        adjacency became a MultiMap and must hold after. -}
    , counterexample
        "graph edges keep their duplicates, their order, and their lone nodes"
        (graphEdges === Just "15")
    {-| The five lookup tables at both ends and past the end, where a
        mistranscribed table would show. These held as nested if ladders and
        must hold as flat matches. -}
    , counterexample
        "status reasons, methods, versions, hop-by-hop names, and scheme ports"
        (lookupTables === Just "23")
    {-| A printer's configuration, checked through its pure rendering rather
        than by capturing output: nothing to print, a piece that already spans
        lines, an indent on top of an indent, and an ending left empty so the
        line stays open. Each check answers 1. -}
    , counterexample
        "a printer carries its separator, ending, prefix, and stream"
        (printers === Just "35")
    {-| A spec's shaping, checked by comparing values rather than by looking at
        output. Weighted toward what a padding helper gets wrong: content wider
        than its width, a sign that must stay in front of zero padding, grouping
        that must not count the sign, and columns measured from the rows. -}
    , counterexample
        "a spec carries its width, fill, alignment, sign, and grouping"
        (shaping === Just "46")
    {-| A suite's own promises, checked by comparing reports, which is possible
        because running one is a pure function from a value to a value. Weighted
        toward what a test framework gets wrong: a failure that does not say
        what it expected, a count that loses nested groups, a pending check
        counted as a pass, and a property reporting the value it generated
        rather than the smallest one that fails. -}
    , counterexample
        "a suite reports what held, what did not, and what is still to write"
        (checking === Just "74")
    {-| A logger's thresholds, the fields it carries, and its three formats,
        checked by comparing rendered lines, which is possible because making a
        line is separate from writing it. Weighted toward what a logger gets
        wrong: a threshold off by one level, a field added for one line that
        stays on the logger, a value carrying a space or a control character
        that ends its own pair early, and an object that stops being an object
        because a key held a quote. -}
    , counterexample
        "a logger keeps what it was told to, carries its fields, and reads three ways"
        (logging === Just "77")
    {-| A hierarchy's counting rules, its three orders, its transformations, and
        what search answers when there is nothing to find. Weighted toward what
        a hand-written hierarchy gets wrong: a leaf counted as height zero, a
        traversal that loses child order, a prune that promotes the children of
        a node it removed. Each check answers 1. -}
    , counterexample
        "a tree counts, walks, transforms, and reports where it looked"
        (hierarchies === Just "67")
    {-| One definition serving several containers, which is the whole reason a
        parameter may stand for a constructor. Every check goes through a
        definition that names no container, so a function copied per container
        would pass none of them. -}
    , counterexample
        "a parameter standing for a constructor serves every container"
        (higherKinds === Just "14")
    {-| A byte sequence answers for what it holds, and the two formats that
        travel as text answer against their own published vectors rather than
        against each other: a round trip through an encoder and its own decoder
        agrees with itself however wrong both halves are. -}
    , counterexample
        "bytes slice, search, and carry the published base64 and hex vectors"
        (byteSequences === Just "49")
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
    {-| The three things that make a separated file harder than splitting on
        the separator: a quoted field, a quote inside one, and a separator or
        newline that a quoted field swallows. -}
    , counterexample
        "a separated file survives quotes, newlines, and its own separator"
        (separated === Just "25")
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
        (threads === Just "22")
    {-| A listener on the loopback address, a client, and a round trip, all in
        one program: the listener binds port zero and asks which port it was
        given, so nothing is assumed about what else the machine holds. -}
    , counterexample
        "a connection carries a message and the reply comes back"
        (endpoints === Just "14")
    {-| A declaration carries no captured environment, so it runs in the frame
        of whoever called it. A named function handed to another module ran
        without its own imports and reported them undefined at run time, having
        type-checked; the root's declarations now carry the root's environment
        exactly as a dependency's do. -}
    , counterexample
        "a declared function works wherever it is called from"
        (callbacks === Just "8")
    {-| Routing, the chain of steps, and the method that carries its terms in
        its own body are checked by calling the handler directly; a request
        arriving and a reply going back are checked over a real socket. -}
    , counterexample
        "a server routes, wraps, and answers over a connection"
        (serving === Just "35")
    {-| Checked against a server written in the fixture that speaks the wire
        protocol, so what the client sends is observable: that a value is sent
        apart from the statement rather than pasted into it, that the challenge
        is answered without the password crossing, that a server which cannot
        prove it knows the password is refused, and that a failed transaction
        is undone rather than left open. -}
    , counterexample
        "a database client binds, authenticates, and rolls back"
        (database === Just "33")
    {-| The obligations [[ADR-0016]] places on an application: that a declared
        default is held like any other setting and can say where it came from,
        that a later layer wins over an earlier one, that a profile states its
        differences rather than replacing what it did not mention, that a read
        says what it expected when the text cannot be that, and — the property
        that only holds because an application is a value — that stages start
        in the order written, stop in the reverse of it, and unwind what came
        up when one of them refuses to. -}
    , counterexample
        "an application is a value that starts and stops in a written order"
        (wired === Just "46")
    {-| That placing text in a page cannot place markup in one: a script
        written into text renders as that text, a quote inside an attribute
        does not end the value and start another, and the ampersand is written
        before the rest so an entity arrives once rather than twice. -}
    , counterexample
        "text placed in a page stays text"
        (markup === Just "36")
    {-| That a screen is a function from state to view, so the difference
        between two renders is exactly the difference the state made: an
        element that became a different element is replaced whole rather than
        reconciled, a list whose length changed replaces the node holding it,
        and applying the changes to the earlier screen gives the later one. -}
    , counterexample
        "two screens differ in what their state differs in"
        (screens === Just "37")
    {-| The refusals [[ADR-0017]] requires, each supplied with the attack it
        exists for and each paired with the legitimate version of the same
        thing: a message framed both by a length and by a chunked encoding, two
        lengths that disagree, a header value carrying a line break, a
        state-changing request from another site or from one that will not say,
        a redirect aimed off-site, a path climbing out of its root by an
        encoded ascent, and an address only the server can reach. -}
    , counterexample
        "the web layer refuses what it is supposed to refuse"
        (refused === Just "76")
    {-| That what a schema change should do is decided without a database: a
        migration edited after it was applied stops everything, because both
        databases report the same version from then on and nothing later can
        detect that their schemas differ; a version arriving below one already
        applied is refused rather than run out of order; and a rename is not an
        edit, because the digest is over what runs. -}
    , counterexample
        "a schema change is planned before a database is reached"
        (schemas === Just "21")
    {-| That the two questions asked from outside a process stay two
        questions: a liveness judgement is handed a reading rather than a
        connection and is declared comptime, so reaching a clock or a socket
        from one is refused by the compiler; a readiness judgement may consult
        what it needs; and an aggregate is as healthy as its unhealthiest
        part, because every other rule arranges for a failure not to count. -}
    , counterexample
        "restarting and receiving traffic are different questions"
        (probes === Just "29")
    {-| That a set of measurements is a value, so the one before a count is
        still there to compare against; that a metric states its unit where it
        is declared; and that how many label combinations one metric may have
        is bounded, with the combination that would exceed it refused and
        counted rather than evicting a series — an evicted counter restarts at
        zero, and a counter that falls is read as a restart. -}
    , counterexample
        "a metric cannot grow a series for every identifier it is handed"
        (measured === Just "41")
    {-| That a route which decided nothing cannot be written: the requirement
        is given in the same call as the handler, so a route needing nothing
        and a route somebody forgot stop being the same line; that not knowing
        who is asking and not being permitted are different answers with
        different statuses; and that a denial does not name what was missing,
        because doing that one route at a time maps the model. -}
    , counterexample
        "a route states what it requires or it is not a route"
        (permitted === Just "48")
    {-| That a client bounds what a request may cost and where it may go: an
        address the network trusts is refused unless the caller named it, and
        refused again at every redirect rather than only at the first, since a
        redirect to an internal address is how the first check is bypassed; a
        chain longer than the bound and an answer larger than the caller will
        read are refused rather than followed or truncated. -}
    , counterexample
        "a client is bounded in what it will fetch and where"
        (fetched === Just "47")
    {-| That everything wrong is reported at once rather than the first thing,
        since a person correcting a form wants the whole list; that a failure
        says what was expected and never repeats what was submitted, so a
        message cannot become somewhere a script is rendered; and that nothing
        repairs its input, because a validator that trims is deciding what the
        sender meant. -}
    , counterexample
        "everything wrong is reported at once"
        (checked === Just "54")
    {-| That a lasting connection is not offered to whoever asks: it is not
        subject to the rule stopping one site reading another's answers, so a
        page on any site could otherwise open one carrying the viewer's
        cookies. The origin is a parameter of the upgrade rather than a step
        that can be omitted. A message from the far end is refused unless
        masked, and how large one may be is checked against the length it
        states rather than against what arrived. The handshake is checked
        against the example the protocol itself publishes. -}
    , counterexample
        "a lasting connection is not offered to whoever asks"
        (lasting === Just "38")
    {-| That there is one renderer and it is the server's: the difference sent
        to a viewer is the difference the state made, applying it to what the
        viewer had gives what the server holds, an event the session never
        declared changes nothing and is counted, and rejoining after a drop
        sends a whole page rather than a difference against a screen nobody
        knows. -}
    , counterexample
        "a live screen sends the difference its state made"
        (driven === Just "35")
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
    {-| That a value cannot become part of a statement: a value spelling a
        whole statement stays one parameter, and the one place a parameter
        cannot help — a table or column name — is refused rather than quoted,
        since quoting correctly depends on the dialect and a quoted name that
        was wrong is an injection that looks handled. -}
    , counterexample
        "a value cannot become part of a statement"
        (statements === Just "53")
    {-| That reading a number from text is two questions: a whole number may be
        below nothing, a count may not. Twelve modules each carried a copy of
        this and they did not agree, silently. -}
    , counterexample
        "a count and a whole number are read differently"
        (numbers === Just "25")
    {-| That a column which is not there and a column which held nothing are
        different answers, since the layer beneath cannot tell them apart and
        inheriting that turns a mistyped name into a data condition found
        later; and that a lookup expecting one row refuses both none and
        several, because answering the first of several is how a program acts
        on the wrong record with nothing appearing to go wrong. -}
    , counterexample
        "a missing column and an empty one are different answers"
        (mapped === Just "46")
    {-| That where a value came from is stated rather than searched for, since
        a binding that took the first hit across path, query, and body would
        let a caller move a value to reach a different path; that every field
        that was wrong is reported at once; and that a refusal names the fields
        and never the values, because a response is a place a submitted value
        would be rendered. -}
    , counterexample
        "a request binds from where it said, and refuses without echoing"
        (submitted === Just "38")
    {-| That a column is a value carrying its table and the type of what it
        holds, so naming one that does not exist is refused where it is
        written rather than when the statement runs, and comparing a column of
        text against a number does not compile. The established framework
        derives the query from a method name and finds a wrong property when
        the method is called. -}
    , counterexample
        "a column is a name the compiler knows"
        (columns === Just "29")
    {-| That a loaded value holds what was loaded and nothing else — no proxy,
        no attached session, nothing left to fetch — and that what belongs to
        many parents is read in one statement, because the interface takes a
        list of parents and answers a map. Reading for one parent is reading
        for a list of one, so the batched shape is the ordinary one. -}
    , counterexample
        "a loaded value is a value, and children load for many parents at once"
        (kept === Just "32")
    {-| That a statement of real shape holds together: every join, grouping, an
        aggregate, a condition on the group, ordering that says where nothing
        sorts, set operations, a named result, and row locking — composed into
        the shape a report takes, with the clauses in the order the language
        reads them and every value still a parameter however large it grew. -}
    , counterexample
        "a query written as one value keeps its values out of its text"
        (shaped === Just "60")
    {-| That a record may be written as another record with some fields
        different. Without it, changing one field of a ten-field record means
        writing the other nine out — nine chances to copy one wrong, with the
        field the expression is actually about invisible among them. The base
        is untouched, the declared field order survives either spelling, and a
        record written whole equals one written as a change. -}
    , counterexample
        "a record may be written as a change to another"
        (altered === Just "22")
    {-| That a password is kept in a form which proves it later without
        holding it, and that the form carries the settings it was made with —
        so raising the work factor does not invalidate what is already stored,
        which is why a work factor kept elsewhere never gets raised. Every
        password gets its own salt, a form that cannot be read is a failure
        rather than one that matches nothing, and no refusal repeats the
        password it was given. -}
    , counterexample
        "a stored password proves itself without being held"
        (proved === Just "40")
    {-| The obligations [[ADR-0015]] places on a hash map: a key type whose
        hash tells nothing apart is still kept distinct by its equality, a
        replaced value keeps its position while a re-inserted key takes a new
        one, the two zeros name one key, and four hundred keys with removals
        answer exactly what the ordered map answers. -}
    , counterexample
        "a hash map settles identity by equality and order by insertion"
        (hashed === Just "43")
    {-| A configuration file, in the shapes the format actually holds: every
        base a whole number is written in, a fractional one kept as its text
        rather than rounded into a binary float, sections and repeated
        sections, dotted keys, and a document written and read back. -}
    , counterexample
        "a configuration reads back what it was written as"
        (configured === Just "44")
    {-| Every case here is a handshake that must fail. A handshake that
        wrongly succeeds carries traffic and looks exactly like one that did
        not, so failing closed is the only property worth checking offline. -}
    , counterexample
        "a secured connection refuses what it cannot prove"
        (secured === Just "7")
    , counterexample "the collection module sorts, maps, filters, and joins"
        (collections === Just "41")
    , counterexample "every standard module links into one program"
        (wide === Just "64")
    , counterexample "maps, sets, and bit work link together"
        (keyed === Just "30")
    {-| Every promise the keyed runtime makes about order, duplication, and
        absence, so a change to how entries are stored cannot quietly change
        what a map is. Each check answers 1, so a shortfall names how many
        failed. -}
    , counterexample "keyed collections keep their order, uniqueness, and overrides"
        (keyedInvariants === Just "18")
    , counterexample "the format modules parse and render"
        (formats === Just "8885")
    , counterexample "JSON strings decode, encode, and reject malformed escapes"
        (jsonStrings === Just "0")
    , counterexample "the protocol modules parse and render messages"
        (protocol === Just "266")
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
    , counterexample "dates, FASTA, FASTQ, quoted CSV, and delimited rows all parse"
        (realFormats === Just "16383")
    , counterexample "matching and equality agree about a number's width"
        (widthPatterns === Just "63")
    , counterexample "a declared width is enforced wherever the value came from"
        (declaredWidths === Just "63")
    , counterexample "matching and equality agree about a number's width"
        (widthPatterns === Just "63")
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

runEntry :: FilePath -> IO (Maybe Text)
runEntry path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure Nothing
    Just parsed -> do
      outcome <- evaluateProgramEntry
          (programIntegerKinds program)
          (programDependencies program)
          "main"
          parsed
      pure (fmap renderValue (outcomeValue outcome))

moduleNames :: FilePath -> IO [Text]
moduleNames path = do
  result <- compileProgram path
  pure (map moduleNameText (programOrder result))

messages :: FilePath -> IO [Text]
messages path = do
  result <- compileProgram path
  pure (map diagnosticMessage (programDiagnostics result))

{-| The help lines a compile produced. A diagnostic's help is where it tells the
    reader what to do, so a test about advice has to read that rather than the
    message. -}
helps :: FilePath -> IO [Text]
helps path = do
  result <- compileProgram path
  pure [help | Just help <- map diagnosticHelp (programDiagnostics result)]

codes :: FilePath -> IO [Text]
codes path = do
  result <- compileProgram path
  pure (map (diagnosticCodeText . diagnosticCode) (programDiagnostics result))

testReplLoadContext :: IO Property
testReplLoadContext = do
  let path = "test-fixtures/program29/B.pudu"
  contents <- TextIO.readFile path
  (apply, loadedDiagnostics, _) <- loadModule path contents
  let loaded = apply emptySession
  entry <- submitEntry loaded
    "fn again(user: User) -> Str { user.show() }"
  pure $ conjoin
    [ map (diagnosticCodeText . diagnosticCode) loadedDiagnostics === []
    , counterexample "the loaded context retains both graph interfaces"
        (Map.size (contextTypes (sessionContext loaded)) === 2)
    , counterexample
        ("post-load diagnostics: " <> show
          [(diagnosticCodeText (diagnosticCode value), diagnosticMessage value) | value <- resultDiagnostics entry])
        (resultAccepted entry === True)
    ]
