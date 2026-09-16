{-| @Test.Repl.SessionSpec — coordinator for REPL interactive session properties -}
module Pudu.Repl.SessionSpec
  ( replProperties
  , module Pudu.Repl.Session.CommandSpec
  , module Pudu.Repl.Session.ContextSpec
  , module Pudu.Repl.Session.EvaluationSpec
  ) where

import Test.QuickCheck (Property)

import Pudu.Repl.Session.CommandSpec
  ( commandProperties
  , testClassification
  , testCommandParsing
  , testCompletion
  , testMemberCompletion
  )
import Pudu.Repl.Session.ContextSpec
  ( contextProperties
  , testDescribe
  , testHigherKindedInspection
  , testHotRedefinition
  , testInspection
  , testInteractiveImports
  , testKinds
  , testPersistence
  , testRejection
  )
import Pudu.Repl.Session.EvaluationSpec
  ( evaluationProperties
  , testControlTransfer
  , testInteractiveLocation
  , testIteration
  , testIterationEdges
  , testLoadedOffsets
  , testMatch
  , testOperators
  , testRecursionAndReturn
  , testRuntimeErrors
  , testStaticTypeInspection
  , testTraits
  )

replProperties :: [(String, IO Property)]
replProperties =
  [ ("commands parse with unambiguous abbreviations", testCommandParsing)
  , ("submissions are classified by their leading token", testClassification)
  , ("bindings and declarations persist across entries", testPersistence)
  , ("a rejected entry leaves the session unchanged", testRejection)
  , ("redefined bindings and declarations replace in place without collision", testHotRedefinition)
  , ("diagnostics are reported against the typed line", testInteractiveLocation)
  , ("inspection reports the session context without changing it", testInspection)
  , ("describing a name reports how the session declared it", testDescribe)
  , ("kinds report declared arity", testKinds)
  , ("inspection preserves higher-kinded parameter arity", testHigherKindedInspection)
  , ("completion offers commands paths and session names", testCompletion)
  , ("completion offers what the value before the dot carries", testMemberCompletion)
  , ("type inspection stops before evaluation", testStaticTypeInspection)
  , ("a loaded file does not shift where the entry sits", testLoadedOffsets)
  , ("loops and iteration evaluate in the interactive session", testIteration)
  , ("trait methods dispatch and inherit in the session", testTraits)
  , ("runtime errors surface and leave the session unchanged", testRuntimeErrors)
  , ("recursion and return interact with loops", testRecursionAndReturn)
  , ("control transfers are confined to their owning construct", testControlTransfer)
  , ("iteration edge cases are handled correctly", testIterationEdges)
  , ("operators short-circuit and index correctly", testOperators)
  , ("match expressions bind and guard correctly", testMatch)
  , ("an imported module is reachable at the prompt", testInteractiveImports)
  ]
