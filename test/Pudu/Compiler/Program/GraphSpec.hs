{-| @Test.Compiler.Program.GraphSpec — dependency graph, discovery, and interface tests -}
module Pudu.Compiler.Program.GraphSpec
  ( graphProperties
  , testAliasedReexport
  , testDiscoveryFailures
  , testGraphEdges
  , testImportFailures
  , testImportedMethods
  , testInterfaceEdges
  , testPathDependencies
  ) where

import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  )
import Pudu.Compiler.Program.Common (codes)
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

graphProperties :: [(String, IO Property)]
graphProperties =
  [ ("program compilation resolves imported trait methods", testImportedMethods)
  , ("program compilation preserves module privacy and trait scope", testImportFailures)
  , ("program discovery diagnoses missing and mismatched modules", testDiscoveryFailures)
  , ("program graphs preserve nominal identity and signature cycles", testGraphEdges)
  , ("program interfaces preserve ABI identity defaults and ambiguity", testInterfaceEdges)
  , ("a project reaches the code its manifest declares", testPathDependencies)
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

{-| A dependency named by path is how the second program written in the
    language shares a line with the first. Both spellings are checked because
    both appear: the bare path is what a person writes, and the table is what
    it has to become when a dependency needs to say anything else.

    The third case is the one that matters for a diagnostic: a dependency that
    is not on the machine must be reported at the import that wanted it, not
    passed over so the module goes missing somewhere else. -}
testPathDependencies :: IO Property
testPathDependencies = do
  bare <- codes "test-fixtures/dependency/app/src/Main.pudu"
  table <- codes "test-fixtures/dependency/tableform/src/Main.pudu"
  absent <- codes "test-fixtures/dependency/absent/src/Main.pudu"
  pure $ conjoin
    [ counterexample "a path dependency resolves" (bare === [])
    , counterexample "written as a table it resolves the same way" (table === [])
    , counterexample "a dependency that is not there is reported at the import"
        (absent === ["E2014"])
    ]

{-| A type re-exported under the name it already has.

    An alias is recorded under its bare name as well as its qualified one, and
    that record carried from module to module: a module writing
    `type Stage = Other.Stage` left `Stage` in the alias table, and the module
    declaring the real `Stage` then read its own name through that entry and
    reported its own constructor as a different type than its own signature.

    Checked as a program that compiles rather than as a diagnostic, because
    what broke was a module disagreeing with itself — and the shape that broke
    it is the ordinary one of moving a type into its own module and leaving the
    old name pointing at it. -}
testAliasedReexport :: IO Property
testAliasedReexport = do
  layered <- codes "test-fixtures/typealias/Root.pudu"
  pure $ counterexample
    "a type re-exported under its own name is still the type that declared it"
    (layered === [])

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
