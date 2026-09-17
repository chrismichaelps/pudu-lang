{-| @Test.Compiler.Program.EvalSpec — standard library program evaluation orchestrator -}
module Pudu.Compiler.Program.EvalSpec
  ( evalProperties
  , testLinkedNames
  , testProgramEvaluation
  ) where

import Pudu.Compiler.Program.Eval.DataSpec (testDataEvaluation)
import Pudu.Compiler.Program.Eval.ProtocolSpec (testProtocolEvaluation)
import Pudu.Compiler.Program.Eval.RuntimeSpec (testRuntimeEvaluation)
import Pudu.Compiler.Program.Eval.ServiceSpec (testServiceEvaluation)
import qualified Data.Text as Text
import Pudu.Compiler.Program (compileProgram, programDependencies)
import Pudu.Compiler.Program.Common (runEntry)
import Pudu.Eval.Program (linkedNames)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

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

{-| A module is published under its path with its own declarations only.

    `Chain.Middle` imports `Chain.Base` as `Base`. Were the alias published with
    it, `Chain.Middle.Base.seed` would be linked, `Chain.Top` would republish
    that as `Middle.Base.seed`, and every level of imports would copy every level
    below it. -}
testLinkedNames :: IO Property
testLinkedNames = do
  program <- compileProgram "test-fixtures/importchain/Main.pudu"
  names <- linkedNames (programDependencies program)
  ran <- runEntry "test-fixtures/importchain/Main.pudu"
  let nested = filter (\name -> any (`Text.isPrefixOf` name) ["Chain.Middle.Base.", "Chain.Top.Middle.", "Middle.Base."]) names
  pure $ conjoin
    [ counterexample "the chain still runs through its imports" (ran === Just "42")
    , counterexample "a module's own declaration is published" (property ("Chain.Middle.grown" `elem` names))
    , counterexample ("an imported alias was published again: " <> show (take 5 nested)) (nested === [])
    ]
