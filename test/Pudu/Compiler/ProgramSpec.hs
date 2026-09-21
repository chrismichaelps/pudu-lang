{-| @Test.Compiler.ProgramSpec — layered program compiler and evaluation test suite -}
module Pudu.Compiler.ProgramSpec
  ( programProperties
  ) where

import Pudu.Compiler.Program.EvalSpec (testLinkedNames, testProgramEvaluation)
import Pudu.Compiler.Program.ForeignSpec
  ( testForeignHandles
  , testForeignOwnershipStore
  , testForeignTeardownEnds
  )
import Pudu.Compiler.Program.CacheSpec
  ( testCacheCorruption
  , testCacheEquivalence
  , testCacheInvalidation
  , testFoldedConstants
  )
import Pudu.Compiler.Program.GraphSpec
  ( testDiscoveryFailures
  , testGraphEdges
  , testImportFailures
  , testImportedMethods
  , testInterfaceEdges
  , testAliasedReexport
  , testPathDependencies
  , testResolutionContext
  , testInterfaceGraph
  )
import Pudu.Compiler.Program.LanguageSpec
  ( testCapturedScope
  , testDestructuringBindings
  , testFunctionLiterals
  , testLanguageRefusals
  , testRangesAndSlices
  )
import Pudu.Compiler.Program.StdlibSpec (testResolutionFreshness, testStandardLibrary)
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
  , ("resolution setup is once per fresh invocation", testResolutionContext)
  , ("interface facts are prepared once per module graph", testInterfaceGraph)
  , ("stored products compile and run exactly as source does", testCacheEquivalence)
  , ("stored products are never reused for changed input", testCacheInvalidation)
  , ("damaged stored products fall back and are replaced", testCacheCorruption)
  , ("folded constants are bound at link instead of evaluated again", testFoldedConstants)
  , ("a type re-exported under its own name stays one type", testAliasedReexport)
  , ("REPL loads retain the program interface context", testReplLoadContext)
  , ("the standard library resolves from the distribution", testStandardLibrary)
  , ("standard-library roots refresh between invocations", testResolutionFreshness)
  , ("a function literal is a value wherever a value goes", testFunctionLiterals)
  , ("a range counts rather than building what it counts", testRangesAndSlices)
  , ("a binding takes a record, a tuple, and a sequence apart", testDestructuringBindings)
  , ("a function literal keeps reaching what it mentions", testCapturedScope)
  , ("ranges, slices, and destructuring refuse what they cannot mean", testLanguageRefusals)
  , ("an imported module is linked into evaluation", testProgramEvaluation)
  , ("linking publishes what a module declared, not what it imported", testLinkedNames)
  , ("a module cannot lend its name to a type it does not declare", testQualifiedTypeNames)
  , ("a type-only name cannot masquerade as a runtime value", testTypeNamesAreNotValues)
  , ("opaque handles cross a real C++ boundary with one release", testForeignHandles)
  , ("foreign ownership serializes release and call use", testForeignOwnershipStore)
  , ("foreign teardown ends even while a native call is inside", testForeignTeardownEnds)
  ]
