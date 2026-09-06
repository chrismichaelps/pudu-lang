{-| @Test.Type.CheckSpec — coordinator for type checking properties -}
module Pudu.Type.CheckSpec (typeProperties) where

import Test.QuickCheck (Property)

import Pudu.Type.Check.DataSpec
  ( testDiscardedResult
  , testKeyedTypes
  , testNamedVariants
  , testPreludeData
  , testRecords
  , testTupleIndex
  , testVariants
  )
import Pudu.Type.Check.FunctionGenericSpec
  ( testCalls
  , testDynamicTypes
  , testGenericAliases
  , testGenericTypes
  , testGenerics
  , testGlobalImpls
  , testLambdaTypes
  )
import Pudu.Type.Check.ControlFlowSpec
  ( testControlFlow
  , testExportedSignatures
  , testIterationTypes
  , testNoCascade
  , testPhaseOrder
  , testTry
  )
import Pudu.Type.Check.PatternSpec
  ( testExhaustiveness
  , testMatchThroughBorrow
  )
import Pudu.Type.Check.PrimitiveSpec
  ( testAnnotations
  , testDecimalType
  , testFloatAlias
  , testFloatLiterals
  , testIntegerLiterals
  , testOperators
  , testTextMethods
  )
import Pudu.Type.Check.SystemSpec
  ( testAsync
  , testComptime
  , testDereference
  , testMarkers
  , testRecordedTypes
  , testScopes
  , testUnsafe
  )
import Pudu.Type.Check.TraitSpec
  ( testAmbiguousMethod
  , testBounds
  , testCoherence
  , testGenericTraits
  , testQualifiedMethods
  , testTraitDefaultCalls
  , testTraits
  )

typeProperties :: [(String, IO Property)]
typeProperties =
  [ ("a generic alias stands for what it names", testGenericAliases)
  , ("a trait bound is satisfied by any implementation in the program", testGlobalImpls)
  , ("maps and sets are typed by what they hold", testKeyedTypes)
  , ("a tuple is indexed by a literal position", testTupleIndex)
  , ("function literals are typed and inferred", testLambdaTypes)
  , ("a match reads through a borrow", testMatchThroughBorrow)
  , ("built-in text methods are typed exactly", testTextMethods)
  , ("a discarded collection result is reported", testDiscardedResult)
  , ("literals and operators take their declared types", testOperators)
  , ("integer literals select every width and enforce exact bounds", testIntegerLiterals)
  , ("floating suffixes select honest precision and reject overflow", testFloatLiterals)
  , ("annotations are checked against their value", testAnnotations)
  , ("calls check argument types and count", testCalls)
  , ("generic functions instantiate per use", testGenerics)
  , ("records check fields on construction and access", testRecords)
  , ("sum constructors and patterns type their payloads", testVariants)
  , ("control flow unifies its branches", testControlFlow)
  , ("exported signatures must be annotated", testExportedSignatures)
  , ("a type error reports once and does not cascade", testNoCascade)
  , ("an earlier phase's error suppresses type checking", testPhaseOrder)
  , ("wired-in Option and Result carry their constructors", testPreludeData)
  , ("? unwraps a Result inside a Result-returning function", testTry)
  , ("async calls normalize task channels and await them", testAsync)
  , ("trait methods dispatch on the receiver type", testTraits)
  , ("trait default bodies call other trait methods on Self", testTraitDefaultCalls)
  , ("matches are checked for coverage and reachability", testExhaustiveness)
  , ("a variant may name its payload", testNamedVariants)
  , ("trait bounds are proved at the call site", testBounds)
  , ("ambiguous trait method dispatch reports E3013", testAmbiguousMethod)
  , ("duplicate trait implementation heads are rejected", testCoherence)
  , ("Float aliases to Float64 at the type level", testFloatAlias)
  , ("references are dereferenced explicitly in both directions", testDereference)
  , ("compiler-controlled markers are decided structurally", testMarkers)
  , ("same-named trait methods are selected by a qualified call", testQualifiedMethods)
  , ("a generic trait's parameters are solved from its implementation", testGenericTraits)
  , ("a type declaration's parameters are instantiated at every use", testGenericTypes)
  , ("a for loop binds at the element type of what it iterates", testIterationTypes)
  , ("a dynamic type accepts any implementation and nothing else", testDynamicTypes)
  , ("Decimal is an ordinary type with exact literals", testDecimalType)
  , ("unsafe regions grant named capabilities and contain their calls", testUnsafe)
  , ("compile-time functions keep their evaluator pure", testComptime)
  , ("a structured scope requires an async function", testScopes)
  , ("expression types are recorded for tooling", testRecordedTypes)
  ]
