---
type: module
path: "@root/src/Pudu/Eval/Context.hs"
fidelity: Active
tags: [module, runtime, lifecycle]
aliases: [Eval Context]
---
# Eval Context

## Purpose and interface

Provide a scoped, serialized evaluation context that retains accepted Env values between actions.
withEvaluationContext :: (EvaluationContext -> IO a) -> IO (a, [Diagnostic]) owns the lifetime.
evaluateInContext :: EvaluationContext -> Evaluator Value -> IO (Either ContextError EvalOutcome)
executes only the supplied action, with effects available, and retains Env after normal completion
or return. A runtime abort preserves the previous binding frames. ContextClosed is explicit after
scope exit. No replay occurs inside this API.

Resolved Grill Log: MVar serializes state transitions; asynchronous exceptions restore the prior
state lock and propagate. Previous binding frames can be retained, but external IO and mutations
to synchronized resources are not rolled back on failure. Allocated resources remain owned by the
context until it closes. Context invalidation happens before resource teardown. A callback must
join work using its context before returning; scope exit waits for an active action.

This is the evaluator foundation; interactive source retention and type-safe redefinition still
need to be integrated before the REPL can stop replaying earlier submissions.

## Dependencies and consumers

[[Eval Env]] supplies evaluation state; [[Evaluator]] supplies action/outcome semantics.
Runtime owns resource stores; Context uses Runtime and Evaluator without reverse dependency.

## Grill Log

Resolved: separate resource ownership from the duration of one command, without process-global state.
No builds, tests, reviews or measurements run. No release-readiness claim.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Repl Session]]


`evaluateBlockInContext` accepts an already admitted Located Block and executes it in the retained frame. It uses the same statement evaluator as ordinary blocks, without creating a disposable enclosing frame. The caller must install declarations and checked integer kinds before execution. This API does not parse or type-check source itself.
