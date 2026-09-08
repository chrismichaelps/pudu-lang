---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/Context.hs"
fidelity: Active
tags: [module, runtime, lifecycle]
aliases: [Eval Context]
---
# Eval Context

## Purpose and interface

Provide a scoped, serialized evaluation context that retains accepted Env values between actions.

### Signatures

```haskell
data ContextError = ContextClosed
newtype EvaluationContext
withEvaluationContext :: (EvaluationContext -> IO a) -> IO (a, [Diagnostic])
evaluateInContext :: EvaluationContext -> Evaluator Value -> IO (Either ContextError EvalOutcome)
evaluateInContextAndCommit :: EvaluationContext -> Evaluator Value -> (EvalOutcome -> IO ()) -> IO (Either ContextError EvalOutcome)
evaluateBlockInContext :: EvaluationContext -> Located Block -> IO (Either ContextError EvalOutcome)
```

`withEvaluationContext` owns the lifetime of an `EvaluationContext`.
`evaluateInContext` executes only the supplied action, with effects available, and retains `Env` after normal completion or return.
`evaluateInContextAndCommit` accepts a nonblocking publication callback executed synchronously during state replacement.
`evaluateBlockInContext` accepts an already admitted `Located Block` and executes it in the retained frame without creating a disposable enclosing frame.
A runtime abort preserves the previous binding frames. `ContextClosed` is explicit after scope exit. No replay occurs inside this API.

## Dependencies and consumers

[[Eval Env]] supplies evaluation state; [[Evaluator]] supplies action/outcome semantics.
Runtime owns resource stores; Context uses Runtime and Evaluator without reverse dependency.

## Grill Log

Resolved: separate resource ownership from the duration of one command, without process-global state.
No builds, tests, reviews or measurements run. No release-readiness claim.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Repl Session]]



## Atomic publication

`evaluateInContextAndCommit` accepts a nonblocking publication callback. Evaluation
is interruptible; outcome publication and retained environment replacement occur
under masking in the same serialized action. The shell publishes its accepted
source snapshot there, so interruption cannot restore stale source after runtime
acceptance. Resolved Grill Log: the callback only writes an IORef and must not
throw or perform interruptible IO. External effects remain nontransactional.
