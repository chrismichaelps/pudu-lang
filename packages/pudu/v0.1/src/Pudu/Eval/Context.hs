{-| @Eval.Context — keeps accepted bindings within a scoped resource lifetime. -}
module Pudu.Eval.Context
  ( ContextError (..)
  , EvaluationContext
  , evaluateBlockInContext
  , evaluateInContext
  , evaluateInContextAndCommit
  , withEvaluationContext
  ) where

import Control.Concurrent.MVar (MVar, modifyMVarMasked, modifyMVar_, newMVar)
import Control.Exception (finally, mask)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Eval (EvalOutcome, evaluateBlockInFrame, outcomeOf)
import Pudu.Frontend.Syntax.Located (Located)
import Pudu.Frontend.Syntax.Tree (Block)
import Pudu.Eval.Env (Env (..), Eval (..), Evaluator (..))
import Pudu.Eval.Runtime (withRuntimeEnv)
import Pudu.Eval.Value (Value)

{-| The constructor stays private so only a managed scope can own a context. -}
newtype EvaluationContext = EvaluationContext (MVar (Maybe Env))

data ContextError = ContextClosed
  deriving stock (Eq, Show)

{-| Retained handles stay valid until the callback returns. Consumers must join
    work using the context before returning; the state lock serializes actions. -}
withEvaluationContext :: (EvaluationContext -> IO a) -> IO (a, [Diagnostic])
withEvaluationContext action = withRuntimeEnv $ \initial -> do
  state <- newMVar (Just initial{envEffects = True})
  action (EvaluationContext state) `finally` modifyMVar_ state (const (pure Nothing))

{-| Commit binding state after a completed action, never by replaying it.
    Aborts retain prior frames; external effects and shared-cell writes cannot
    be undone and their resources stay owned until the context exits. -}
evaluateInContext
  :: EvaluationContext -> Evaluator Value -> IO (Either ContextError EvalOutcome)
evaluateInContext context action = evaluateInContextAndCommit context action (const (pure ()))

{-| Publication must be nonblocking and exception-free, such as an IORef write.
    It shares the masked state commit while evaluation remains interruptible. -}
evaluateInContextAndCommit
  :: EvaluationContext -> Evaluator Value -> (EvalOutcome -> IO ())
  -> IO (Either ContextError EvalOutcome)
evaluateInContextAndCommit (EvaluationContext state) (Evaluator action) publish =
  mask $ \restore -> modifyMVarMasked state $ \current -> case current of
    Nothing -> pure (Nothing, Left ContextClosed)
    Just previous -> do
      result <- restore (action previous)
      let retained = case result of
            Done _ next -> next
            Unwound _ next -> next
            Aborted _ -> previous
          outcome = outcomeOf result
      publish outcome
      pure (Just retained, Right outcome)

{-| Execute an admitted top-level block without discarding the bindings it adds. -}
evaluateBlockInContext
  :: EvaluationContext -> Located Block -> IO (Either ContextError EvalOutcome)
evaluateBlockInContext context = evaluateInContext context . evaluateBlockInFrame
