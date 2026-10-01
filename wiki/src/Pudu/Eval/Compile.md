---
type: module
path: "@root/src/Pudu/Eval/Compile.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Compile]
---
# Eval Compile
## Purpose
Turn a function body into closures once, so running it does only the work: every decision the tree
walker makes about syntax on every step is made here, the first time the body is called.
## Interface
`compileBody :: Walker -> FunctionBody -> Evaluator Code`, where `Code` is `Evaluator Value` and
`Walker` carries the tree walker's expression and statement evaluators, its loop needs, and its call
needs. `blockIntroducesBindings` decides whether a block takes a frame of its own, for both
evaluators.
## Governance and algorithm
Compiled: literals (an integer literal's kind read once), names (a module-scope function resolved
once, with a later local of the same first name still winning), unary and binary operators,
assignment to a place that needs no evaluation, `&&` and `||`, blocks, `let`, `return`, `if`,
`while` and `for` (through the tree walker's own loops, given compiled pieces), `if let`, index
reads, field reads, tuples, arrays, record literals, `match` with guards, and calls (the call machinery's needs answer
each callee, receiver, and argument from its compiled code, keyed by span and, where two share a
span, by the syntax itself). Anything else runs through the tree walker for that one expression,
so the language is always runnable while coverage grows. Compiled code depends only on the syntax
and the program's literal kinds, never on one call's values, so one compilation serves every call
and every thread.
## Grill Log
- **Q:** Reimplement loops and calls in the compiler? **A:** No. _Rationale:_ the tree walker's
  loop and call code take their evaluators as parameters, so handing them compiled pieces keeps the
  step limit, control transfers, lending, and async in one place. _Rejected:_ a second loop and
  call implementation that could drift.
- **Q:** Resolve every name at compile time? **A:** Only functions in module scope. _Rationale:_
  they do not change after linking, while a module value could, and a parameter or local is
  different on every call. _Rejected:_ caching any binding found at compile time, which would freeze
  a function argument seen on the first call.
- **Q:** Read a compiled body's locals by name? **A:** Not when it runs on slots. _Rationale:_ a name
  that [[Eval Compile Layout]] placed is read and written by position, and a path or field read
  starting at one skips the module search, since a local is never a module. Its blocks open no
  frame. Everything else still reads the slot frame by name.
- **Q:** Send a call to a known module function through the general call machinery? **A:** Not
  when nothing is lent. _Rationale:_ for such a call the machinery's qualified-callee search,
  lending bookkeeping, and per-argument lookup all reach the same function with the same values; the
  compiled call evaluates the arguments and calls it directly (#428). A local of the callee's name,
  an `&mut` argument, or a callee with `&mut` parameters keeps the general path. The general path's
  per-argument code is found by where the argument starts rather than by comparing whole spans.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Compiled Evaluation]] · [[Eval Compile Cache]] · [[Eval Call]]
