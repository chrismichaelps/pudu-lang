{-| @Test.Compiler.Program.Eval.CompiledSpec — compiled bodies agree with the tree walker -}
module Pudu.Compiler.Program.Eval.CompiledSpec
  ( testCompiledAgreement
  ) where

import Control.Exception (finally)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( compileProgram
  , programDependencies
  , programIntegerKinds
  , rootCompileResult
  )
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import System.Directory (listDirectory)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import Test.QuickCheck (Property, counterexample, (===))

{-| Every standard-library fixture, run once by the tree walker and once with
    compiled bodies, answers the same value and the same runtime diagnostics.

    The tree walker is the reference: a difference is a fault in the compiled
    bodies by definition, and each differing fixture is named. -}
testCompiledAgreement :: IO Property
testCompiledAgreement = do
  names <- sort . filter runnable <$> listDirectory "test-fixtures/stdlib"
  differing <- concat <$> mapM compare' names
  pure (counterexample ("fixtures that differ between evaluators: " <> show differing) (differing === []))
 where
  -- A fixture that drives a real device answers what the device's clock
  -- reported, which differs between two runs of the same evaluator.
  runnable name =
    ".pudu" `isSuffixOf` name && not ("Rejects" `isPrefixOf` name) && not ("Launch" `isPrefixOf` name)
  compare' name = do
    let path = "test-fixtures/stdlib/" <> name
    tree <- inMode "tree" (outcomeOfFixture path)
    compiled <- inMode "compiled" (outcomeOfFixture path)
    pure [name | tree /= compiled]

{-| What a fixture answers: its rendered value and its runtime diagnostic codes,
    or nothing when it does not compile. -}
outcomeOfFixture :: FilePath -> IO (Maybe (Maybe Text, [Text]))
outcomeOfFixture path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure Nothing
    Just parsed -> do
      outcome <-
        evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" parsed
      pure (Just (renderValue <$> outcomeValue outcome, map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome)))

{-| Run an action with `PUDU_EVAL` set, restoring what it was. -}
inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
