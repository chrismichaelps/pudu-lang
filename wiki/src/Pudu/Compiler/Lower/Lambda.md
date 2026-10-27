---
type: module
path: "@root/src/Pudu/Compiler/Lower/Lambda.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Lambda]
---
# Compiler Lower Lambda

## Purpose and interface

Function values under [[Native Closures]].

- `lowerLambda` lifts a lambda into a function of its own whose first
  parameter is its closure, and answers a `CoreClosure` over it.
- `lowerFunctionValue` answers a closure naming the actual module function
  without a forwarding frame; its ABI has no environment parameter (#568).
- `lowerValueCall` calls through any value of function type.

## Lambdas

A lambda captures the enclosing locals among the names it mentions
(`reachableNames`, the evaluator's own over-approximation), copied when the
lambda is evaluated. The lifted body declares each capture as a local read from
its closure, so the body reads the copy and never the enclosing variable. Its
key is the key of the body it was written in plus its offset, so a lambda
inside a specialized body is lowered once per copy. A key seen before keeps its
first lowering. The parameters and result come from the lambda's checked
function type. A lambda returning print's Result refuses, and so does an async
lambda.

## Calls through values

The arguments run first, then the callee, as `evaluateCall` does. So each
argument goes into a temporary and the call reads them back after the callee.

## Resolved Grill Log

- **Q:** Copy or reference captures? **A:** Copy, as the evaluator's snapshot
  does; reassigning a captured `var` later changes nothing the lambda sees.
  Assigning a captured name inside the lambda is rejected by checking (E3076).
- **Q:** How does a named function become a value? **A:** A box names its
  actual target and owns no captures. It renders as `<fn name>` and retains
  its source identity; dispatch does not add a forwarding call (#568).
- Function values compare equal when written in the same place (the lambda's
  span, or the named function), as `Eq Closure` leaves captures out.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Generic]] ·
[[Compiler Lower Control]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Native Closures]]

## Named callable dispatch (#568)

Resolved Grill Log: Replace named forwarders with closures naming their actual admitted target. Enqueue the target and register empty captures/name/site with closureHasEnvironment false. Lambdas keep the lifted function and set the flag true.

## First-class output builtins (#569)

Resolved Grill Log: Set closureIsBuiltin false for named source targets and lifted lambdas; hidden-environment behavior remains explicit.
