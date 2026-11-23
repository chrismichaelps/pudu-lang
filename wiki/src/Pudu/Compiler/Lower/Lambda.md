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

A callee runs before supplied arguments. The frame retains each value in
evaluation order, including a callable selected from a field. Supplied
arguments use the checked closure input types for dynamic widening before
the call is emitted, including calls with a hidden default argument count.

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

Resolved Grill Log (#828): value calls lower the target first, including
function-valued members. The frame retains that target before reading any
argument. A Never target emits no argument effects.

## Referenced by

[[Compiler Lower Body]] · [[Native Closures]]

## Named callable dispatch (#568)

Resolved Grill Log: Replace named forwarders with closures naming their actual admitted target. Enqueue the target and register empty captures/name/site with closureHasEnvironment false. Lambdas keep the lifted function and set the flag true.

## First-class output builtins (#569)

Resolved Grill Log: Set closureIsBuiltin false for named source targets and lifted lambdas; hidden-environment behavior remains explicit.

## Defaults through values (#638)

A value call whose checked callee type requires fewer parameters than it has
passes suppliedArguments. Resolved Grill Log: the formed type already ends
with the count, so the closure and frame arity agree.

Closure info passes closureMethod = Nothing. (#644)

## Mutable loans (#794)

A call through a value whose checked function type has `&mut` inputs goes
to [[Compiler Lower Loan]] with the callee as `Through`. A lambda with
`&mut` parameters lowers its body with those parameters loaned, returns
typed at its declared result, and closes its trailing result over the
finals.

## Tasks and async lambdas (#846)

An async body lifts as a task: a function of nothing over the names it
mentions, registered beside the body it was written in and shown under the
task's name. An async lambda's body is the task it answers. Making a task
inside an `async with scope` offers it to the innermost scope and the scope's
joiner, which runs it and stashes a failure for the scope's function. Resolved
Grill Log: one lifted function serves a written lambda and its async form; a
task lends no `&mut` parameters and runs only when awaited or joined.

## Calls through runtime callable alternatives (#956)

Resolved Grill Log: match the saved callable before making its ordinary
typed call. Each reachable arm uses the declared input carriers and the
actual closure result carrier. Join heterogeneous results after the call.
A noncallable value retains the normal runtime call diagnostic.

## Array callback signatures (#956)

Resolved Grill Log: a written callback uses the array's native input
carriers when they differ from checking's. Each lifted body receives the
carriers used by its call site, and its key includes those inputs.
Named callbacks use the same exact copies as direct calls. Both explicit
returns and the tail contribute native result carriers before frame emission.

## Stored callable dispatch (#956)

Resolved Grill Log: Select a stored callable by native body identity and build a typed copy using the held capture values. Hold the callee and arguments once and keep their evaluation order.

## Runtime layouts in stored methods and builtins (#956)

Resolved Grill Log: A selected method copy reads the original receiver capture. A selected intrinsic copy has no environment and keeps the intrinsic call-depth rule.

## Native task result layouts (#956)

Resolved Grill Log: A task retains its captures and settles its actual result. Its joiner stashes a selected failure in the exact carrier used by the scope.

## Native mutable loan layouts (#956)

Resolved Grill Log: A named or lifted loaned callable advertises the actual result tuple. An indirect call selects its body while retaining the original closure environment.

## Stored mutable parameter layouts (#956)

Resolved Grill Log: Keep the requested input vector in the lifted body template. Rebuilding the original callable must reproduce its body key when its mutable parameters have widened.
