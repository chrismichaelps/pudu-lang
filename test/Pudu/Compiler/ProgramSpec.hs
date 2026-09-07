{-| @Test.Compiler.ProgramSpec — layered program compiler and evaluation test suite -}
module Pudu.Compiler.ProgramSpec
  ( programProperties
  ) where

import Pudu.Compiler.Program.EvalSpec (testProgramEvaluation)
import Pudu.Compiler.Program.ForeignSpec
  ( testForeignHandles
  , testForeignOwnershipStore
  , testForeignTeardownEnds
  )
import Pudu.Compiler.Program.GraphSpec
  ( testDiscoveryFailures
  , testGraphEdges
  , testImportFailures
  , testImportedMethods
  , testInterfaceEdges
  , testPathDependencies
  )
import Pudu.Compiler.Program.StdlibSpec (testStandardLibrary)
import Pudu.Compiler.Program.TypeBoundarySpec
  ( testQualifiedTypeNames
  , testReplLoadContext
  , testTypeNamesAreNotValues
  )
import Test.QuickCheck (Property)

{-| Aggregated properties covering dependency graph discovery, interfaces,
    type boundaries, foreign crossings, and standard library evaluation. -}
programProperties :: [(String, IO Property)]
programProperties =
  [ ("program compilation resolves imported trait methods", testImportedMethods)
  , ("program compilation preserves module privacy and trait scope", testImportFailures)
  , ("program discovery diagnoses missing and mismatched modules", testDiscoveryFailures)
  , ("program graphs preserve nominal identity and signature cycles", testGraphEdges)
  , ("program interfaces preserve ABI identity defaults and ambiguity", testInterfaceEdges)
  , ("a project reaches the code its manifest declares", testPathDependencies)
  , ("REPL loads retain the program interface context", testReplLoadContext)
  , ("the standard library resolves from the distribution", testStandardLibrary)
  , ("an imported module is linked into evaluation", testProgramEvaluation)
  , ("a module cannot lend its name to a type it does not declare", testQualifiedTypeNames)
  , ("a type-only name cannot masquerade as a runtime value", testTypeNamesAreNotValues)
  , ("opaque handles cross a real C++ boundary with one release", testForeignHandles)
  , ("foreign ownership serializes release and call use", testForeignOwnershipStore)
  , ("foreign teardown ends even while a native call is inside", testForeignTeardownEnds)
  ]
