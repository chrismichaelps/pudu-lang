---
type: module
path: "@root/src/Pudu/Eval/Compile/Layout.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Compile Layout]
---
# Eval Compile Layout
## Purpose
Decide whether a compiled body runs on slots, and where each of its parameters and locals sits.
## Interface
`slotLayout parameters body` answers a position for each parameter, each `let`, and each name a
`match` arm or an `if let` binds, or nothing.
## Governance and algorithm
A body gets slots when it declares a local and every name it binds anywhere — parameters, `let`s,
and every pattern — is distinct. Then nothing in it shadows anything else, so a name in the layout
means its slot wherever it is written, and pattern names, which bind through frames above, never
collide with one. A function literal inside the body is its own body and is not looked into.
Unique spelling alone is insufficient: ordered access events must also prove
each slotted reference occurs after its binder and inside that binder's lexical
scope. Initializers precede their declarations. Branch, arm and block scopes
restore the previous active set on exit. A lambda contributes the existing
conservative reachable-name set at its capture point, without allocating its
own binders in the parent's layout. Record shorthand contributes a name read.
Unsafe layouts keep ordinary name-based execution, preserving outer captures.
Names bound by patterns the tree walker binds through a frame of its own — `for`, `while let`,
`let ... else`, a destructuring `let` — must be distinct too, but take no slot: their value lives
in that frame, and they are read by name.
## Grill Log
- **Q:** Use pairwise duplicate scans for every body? **A:** Compare the binding
  inventory's count to a Set's cardinality. _Rationale:_ admission should cost
  O(n log n) for n bindings, while preserving original slot order. _Rejected:_
  quadratic `nub` on a large local inventory or sorting slot positions.
- **Q:** Does unique spelling prove a slotted name is already bound? **A:** No;
  validate ordered reads against active scoped binders before admitting slots.
  _Rationale:_ `let value = value + 1` inside a closure must read the captured
  value before introducing its local; reading its allocated slot yields unit.
  _Rejected:_ an initializer-only special case, stale values after nested scope
  exit, dynamic slot occupancy affecting only one evaluator, or zero-filled
  slots standing in for lexical bindings.
- **Q:** Track scopes so a shadowing body can still use slots? **A:** No. _Rationale:_ a fixed layout
  maps one name to one position, which is what lets the tree walker read a slot frame by name;
  shadowing already draws a warning, so few bodies are left out. _Rejected:_ a layout that changes
  as blocks open and close.
- **Q:** Give every body slots? **A:** Only one with a local of its own. _Rationale:_ a body reading
  only its parameters, like a small recursive function, paid more to set up slots on each call than
  it saved; measured on `fib(27)` that was 0.36 s against 0.40 s.
- **Q:** Give `match` and `if let` binders slots? **A:** Yes, in a body on slots. _Rationale:_ the
  compiled code matches those patterns itself, so it writes the bound values to their slots instead
  of pushing a frame and reading them back by name. A `for` binder does not get one: the tree
  walker's loop binds it in a frame each turn, and a slot would hold a stale value.
- **Q:** Does a compile-time element take a slot? **A:** No; it is a framed name read by name, like
  a `for` binder. _Rationale:_ the loop binds its element fresh each turn, so a slot would hold a
  stale value; unrolling happens before compilation, so by the time layout runs the loop is ordinary
  code with an ordinary binder. _Rejected:_ a slot for the element, which the tree walker would
  never write.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Compile]] · [[Eval Env]]
