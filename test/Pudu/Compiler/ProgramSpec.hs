module Pudu.Compiler.ProgramSpec (programProperties) where

import Data.Text (Text)
import qualified Data.Map.Strict as Map
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileContext (..))
import Pudu.Compiler.Program (ProgramResult (..), compileProgram)
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
