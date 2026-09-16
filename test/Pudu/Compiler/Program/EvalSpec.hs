{-| @Test.Compiler.Program.EvalSpec — standard library program evaluation orchestrator -}
module Pudu.Compiler.Program.EvalSpec
  ( evalProperties
  , testProgramEvaluation
  ) where

import Pudu.Compiler.Program.Eval.DataSpec (testDataEvaluation)
import Pudu.Compiler.Program.Eval.ProtocolSpec (testProtocolEvaluation)
import Pudu.Compiler.Program.Eval.RuntimeSpec (testRuntimeEvaluation)
import Pudu.Compiler.Program.Eval.ServiceSpec (testServiceEvaluation)
import Test.QuickCheck (Property, conjoin)

evalProperties :: [(String, IO Property)]
evalProperties =
  [ ("an imported module is linked into evaluation", testProgramEvaluation)
  ]

{-| A program's imports are linked before its entry point runs, so a call into
    an imported module finds the function it named — including one in the
    standard library, and including a helper that module keeps private. -}
testProgramEvaluation :: IO Property
testProgramEvaluation = do
  dataProp <- testDataEvaluation
  protocolProp <- testProtocolEvaluation
  serviceProp <- testServiceEvaluation
  runtimeProp <- testRuntimeEvaluation
  pure (conjoin [dataProp, protocolProp, serviceProp, runtimeProp])
