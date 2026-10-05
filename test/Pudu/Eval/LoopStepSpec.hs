{-| @Test.Eval.LoopStepSpec — ordered region results, refusals and cleanup. -}
module Pudu.Eval.LoopStepSpec (testLoopSteps) where

import Data.IORef (newIORef, modifyIORef', readIORef, writeIORef)
import Pudu.Eval (EvalOutcome (..), runWithEffects)
import Pudu.Eval.Env (Eval (..), Evaluator (..), Unwind (..), abortAt)
import Pudu.Eval.Loop.Step (finallyStep, liftStep, runStep, stopStep)
import Pudu.Eval.Value (intOf)
import Pudu.Source (SourceName (..), emptySpan, newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

testLoopSteps :: IO Property
testLoopSteps = do
  source <- newSource (SourceName "loop-step") ""
  events <- newIORef ([] :: [String])
  scratch <- newIORef (9 :: Integer)
  let note label = modifyIORef' events (<> [label])
      cleanup = note "cleanup" >> writeIORef scratch 0
      refusal = abortAt (Just (emptySpan source)) "E7004" "index out of range" Nothing
  success <- runWithEffects True $ Evaluator $ \env -> do
    result <- runStep $ finallyStep
      (do
        liftStep (note "first")
        value <- (+ 1) <$> liftStep (readIORef scratch)
        liftStep (note "second")
        intOf <$> (pure (+ 2) <*> pure value)) cleanup
    pure (either id (\value -> Done value env) result)
  successTrace <- readIORef events
  cleared <- readIORef scratch
  writeIORef events []
  ordinary <- runWithEffects True refusal
  refused <- runWithEffects True $ Evaluator $ \env -> do
    let Evaluator runRefusal = refusal
    stopped <- runRefusal env
    result <- runStep $ finallyStep
      (liftStep (note "before") >> stopStep stopped >> liftStep (note "after") >> pure (intOf 99))
      cleanup
    pure (either id (\value -> Done value env) result)
  refusalTrace <- readIORef events
  writeIORef events []
  transferred <- runWithEffects True $ Evaluator $ \env -> do
    result <- runStep $ finallyStep
      (liftStep (note "before") >> stopStep (Unwound (ReturnUnwind (intOf 7)) env)
        >> liftStep (note "after") >> pure (intOf 99)) cleanup
    pure (either id (\value -> Done value env) result)
  transferTrace <- readIORef events
  pure $ conjoin
    [ outcomeValue success === Just (intOf 12)
    , outcomeDiagnostics success === []
    , counterexample "returned value survives scratch cleanup" (cleared === 0)
    , successTrace === ["first", "second", "cleanup"]
    , counterexample "ordinary structured refusal is preserved" (refused === ordinary)
    , refusalTrace === ["before", "cleanup"]
    , outcomeValue transferred === Just (intOf 7)
    , outcomeDiagnostics transferred === []
    , transferTrace === ["before", "cleanup"]
    ]
