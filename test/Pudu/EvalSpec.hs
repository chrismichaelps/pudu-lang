{-| @Test.EvalSpec — coordinator for Pudu program evaluation properties -}
module Pudu.EvalSpec (evalProperties) where

import Test.QuickCheck (Property)

import Pudu.Eval.ArithmeticSpec
  ( testArithmetic
  , testIntegerWidths
  )
import Pudu.Eval.BindingFlowSpec
  ( testBindings
  , testBranching
  , testLoops
  , testUnwindFrameCleanup
  )
import Pudu.Eval.DataSpec
  ( testArrayConcat
  , testData
  , testInterpolation
  , testKeyed
  , testTextMethods
  )
import Pudu.Eval.FunctionClosureSpec
  ( testBuiltinImpls
  , testClosures
  , testFunctions
  )
import Pudu.Eval.SystemSpec
  ( testAsync
  , testBorrowing
  , testClock
  , testEffects
  , testFailures
  , testResourceIsolation
  , testScopes
  , testUnsafeRegions
  )

evalProperties :: [(String, IO Property)]
evalProperties =
  [ ("arithmetic and comparison follow declared operators", testArithmetic)
  , ("bindings assignment and blocks evaluate in order", testBindings)
  , ("functions defaults and recursion evaluate", testFunctions)
  , ("conditionals and pattern matching select branches", testBranching)
  , ("loops iterate and jumps leave them", testLoops)
  , ("control unwinds restore lexical frames", testUnwindFrameCleanup)
  , ("sum and record values construct and destructure", testData)
  , ("runtime failures report exact diagnostics", testFailures)
  , ("async calls stay cold until an async entry awaits them", testAsync)
  , ("borrowing and dereferencing read the same value", testBorrowing)
  , ("unsafe regions evaluate their block", testUnsafeRegions)
  , ("structured scopes join every task they start", testScopes)
  , ("built-in text methods answer with new values", testTextMethods)
  , ("function literals capture the environment they were written in", testClosures)
  , ("array concatenation joins two arrays", testArrayConcat)
  , ("maps and sets keep their contents in key order", testKeyed)
  , ("effects answer with a result and are refused at compile time", testEffects)
  , ("interpolated strings render their holes", testInterpolation)
  , ("calendar time and subprocesses answer with results", testClock)
  , ("fixed-width integers keep their width at run time", testIntegerWidths)
  , ("implementations reach built-in types", testBuiltinImpls)
  , ("runtime resource stores isolate concurrent evaluations", testResourceIsolation)
  ]
