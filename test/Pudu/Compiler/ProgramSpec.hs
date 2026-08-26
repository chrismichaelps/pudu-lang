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
  , rootCompileResult
  )
import Pudu.Eval (EvalOutcome (..), evaluateProgramEntry)
import Pudu.Eval.Value (renderValue)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticMessage)
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
  formats <- runEntry "test-fixtures/stdlib/UsesFormats.pudu"
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
  widths <- runEntry "test-fixtures/stdlib/UsesNumericWidths.pudu"
  scoped <- runEntry "test-fixtures/scoped/Main.pudu"
  aliased <- runEntry "test-fixtures/program29/B.pudu"
  pure $ conjoin
    [ counterexample "an aliased and a selected import both evaluate"
        (ran === Just "35")
    , counterexample "generic and text modules link together"
        (everything === Just "8")
    , counterexample "the collection module sorts, maps, filters, and joins"
        (collections === Just "41")
    , counterexample "every standard module links into one program"
        (wide === Just "64")
    , counterexample "maps, sets, and bit work link together"
        (keyed === Just "30")
    , counterexample "the format modules parse and render"
        (formats === Just "8885")
    , counterexample "the protocol modules parse and render messages"
        (protocol === Just "247")
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
        (dynamic === Just "6")
    , counterexample "a program with no entry point evaluates to unit"
        (aliased === Just "()")
    ]

runEntry :: FilePath -> IO (Maybe Text)
runEntry path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure Nothing
    Just parsed -> do
      outcome <- evaluateProgramEntry (programDependencies program) "main" parsed
      pure (fmap renderValue (outcomeValue outcome))

moduleNames :: FilePath -> IO [Text]
moduleNames path = do
  result <- compileProgram path
  pure (map moduleNameText (programOrder result))

messages :: FilePath -> IO [Text]
messages path = do
  result <- compileProgram path
  pure (map diagnosticMessage (programDiagnostics result))

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
