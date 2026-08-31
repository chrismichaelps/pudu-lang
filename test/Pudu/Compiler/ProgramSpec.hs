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
