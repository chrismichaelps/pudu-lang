{-| Runs real Pudu challenge admission and proof exchanges in both evaluators. -}
module Pudu.Compiler.Program.AuthenticationSpec (authenticationProperties) where

import Control.Exception (finally)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (compileProgram, programDependencies, programIntegerKinds, rootCompileResult)
import Pudu.Diagnostic (hasErrors)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

authenticationProperties :: [(String, IO Property)]
authenticationProperties = [("database authentication admits bounded challenge work", challengeAdmission)]

challengeAdmission :: IO Property
challengeAdmission = do
  program <- compileProgram "test-fixtures/dbauth/Main.pudu"
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (counterexample "the challenge fixture did not compile" False)
    Just parsed -> conjoin <$> mapM (run program parsed) ["tree", "compiled"]
 where
  run program parsed mode = do
    previous <- lookupEnv "PUDU_EVAL"
    setEnv "PUDU_EVAL" mode
    outcome <- evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" parsed
      `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
    pure $ counterexample (mode <> ": " <> show (outcomeDiagnostics outcome)) $ conjoin
      [ (renderValue <$> outcomeValue outcome) === Just "0"
      , hasErrors (outcomeDiagnostics outcome) === False
      ]
