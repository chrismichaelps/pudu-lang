---
type: module
path: "@root/src/Pudu/Eval.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.86
depth_status: DEEP
coupling: 5.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Evaluator]
---

# Evaluator

## Purpose

Execute a parsed and resolved module by walking its tree, so a program can be run and an interactive session can print values before a backend exists.

## Interface

### Signatures

```haskell
data EvalOutcome = EvalOutcome
  { outcomeValue :: !(Maybe Value)
  , outcomeDiagnostics :: ![Diagnostic]
  }
evaluateEntryPoint :: Text -> Module -> EvalOutcome
evaluateModule :: Module -> EvalOutcome
```

### Governance

- A structured scope adopts every task started inside it. Awaiting a task joins it there; a child never awaited is joined when the scope exits, in the order the children started, so no task outlives the region that began it and a failure among them is selected by position rather than by a race. A control transfer out of a scope joins its children before continuing.

- Evaluation runs only on a module the earlier phases admitted. It re-checks nothing they proved, and it invents no value for syntax they rejected.
- Functions and variant constructors are installed before any constant is evaluated, so mutual recursion and forward references behave exactly as resolution promised. Constants then evaluate in declaration order, and one that reads a later constant is a runtime diagnostic rather than a silent default.
- `return`, `break`, and `continue` travel as an unwind that the owning construct catches: a call catches a return, a loop catches a break or a continue. This is what makes a `return` inside a nested block leave its function instead of becoming that block's value.
- Integers remain arbitrary precision until fixed-width runtime lowering arrives. Floats retain their admitted `Float32`/`Float64` precision and normalize narrow results through binary32, because a literal suffix provides the width without requiring typed-tree annotations. Integer `&+`, `+|`, and their siblings still compute exactly until fixed-width lowering. Division and remainder by zero are diagnosed where the rule is width-independent.
- Arguments bind left to right; a parameter with no argument evaluates its default in the environment the earlier parameters already extended, matching the declared evaluation order.
- Assignment writes the binding where it was declared rather than creating a new one in the innermost frame.
- Recursion and iteration are bounded. Exceeding either reports `E7002` rather than exhausting the host, which keeps an interactive session usable after a runaway program.
- Runtime failures are ordinary diagnostics: `E7001` shape and definedness, `E7002` limits, `E7003` arity, `E7004` domain errors such as division by zero and index range, `E7005` no matching arm – a defensive path once exhaustiveness checking runs, but still reported rather than crashing – `E7006` a jump outside a loop, `E7007` a panic from the prelude's `panic` builtin, which represents a violated invariant rather than a recoverable domain failure.
- Calling an async closure evaluates supplied arguments and omitted defaults left to right, then returns a cold `TaskValue` without running the body. `.await` starts that prepared body; `Ok` yields its payload, `Err` propagates like `?`, and awaiting a non-task is defensive runtime `E7008`.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Eval Match]], [[Eval Operator]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Pudu REPL]] and future tooling; the eventual backend replaces it for compiled execution.

## Algorithm

Install declarations, evaluate module constants, then evaluate the named entry point: statements run in order inside block frames, expressions evaluate left to right, and control transfers unwind to the construct that owns them.

## Negative Logic (Prohibited Paths)

- No type checking, coercion, or inference; no trait or method dispatch; no ownership, borrow, or drop behaviour; no IO, filesystem, clock, or randomness; no scheduler or parallel execution; no compile-time evaluation semantics; and no silent recovery from a runtime failure.

## Edge Cases

- A control transfer that reaches the top has left every construct that could own it: a return yields its value, a stray break or continue yields unit rather than losing the run.
- Iteration is defined over the values the evaluator can enumerate without traits — tuples, strings, and variant payloads — and anything else says so instead of silently doing nothing.
- `?` yields the success value or returns the failure from the enclosing function unchanged, which is the elaboration [[architecture/SEMANTICS]] gives it.
- A member access finds a field first and a method of the value's type second; in callee position the method wins, matching how the same call is typed. A method call binds the receiver as the function's first parameter.
- The interpreter's task is cold and deterministic but not concurrently scheduled. Awaiting the same immutable task value again replays its pure body until the scheduler slice introduces task identity and at-most-once state; current Pudu has no task-observable IO, clock, or randomness.
- `evaluateEntryPoint` drives a task only when the named entry function itself is async. An ordinary entry that returns a task receives the opaque task unchanged, preserving cold calls at the host boundary.

## Depth

DEPTH 0.86 (DEEP). One entry point hides declaration installation, environment frames, control unwinding, operator semantics, pattern matching, and bounded execution.

## Grill Log

- **Q:** Should the evaluator wait for the type checker? **A:** No. _Rationale:_ an interactive session that cannot produce a value teaches nothing about the language, and every rule the evaluator applies here is one typing will later refine rather than contradict. _Rejected:_ a checking-only session; a stub evaluator returning placeholders.
- **Q:** How do `return`, `break`, and `continue` leave nested blocks? **A:** As unwinds through the evaluator's own result type. _Rationale:_ the first attempt made a block yield a control value, and a `return` inside an `if` became the `if`'s value — the tests caught it immediately. _Rejected:_ threading a flow value through every expression; host exceptions.
- **Q:** What width do fixed-width operators use? **A:** None yet; they compute exactly and are documented as awaiting typing. _Rationale:_ guessing 64 bits would produce wrapping the declared type never asked for, which is worse than exact arithmetic. _Rejected:_ assuming a default width; refusing to evaluate arithmetic at all.
- **Q:** Should a runaway loop hang the session? **A:** No; iteration and recursion are bounded and report `E7002`. _Rationale:_ an interactive tool must survive its user's mistakes. _Rejected:_ unbounded execution; a wall-clock timeout, which would make results irreproducible.
- **Q:** Execute an async body when it is called? **A:** No; prepare its argument bindings and return a cold task, then run the body at `.await`. _Rationale:_ this preserves the language's first observable async boundary before scheduling exists. _Rejected:_ eager calls with pass-through await; fake concurrent scheduling in the tree walker.

## Variants

- A compiled backend replaces this walker for release builds; the diagnostic codes and value shapes stay the contract tools depend on.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Pudu REPL]] · [[Syntax Tree]] · [[Diagnostic Model]] · [[Semantics]]
