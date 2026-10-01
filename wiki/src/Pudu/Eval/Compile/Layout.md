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
Names bound by patterns the tree walker binds through a frame of its own — `for`, `while let`,
`let ... else`, a destructuring `let` — must be distinct too, but take no slot: their value lives
in that frame, and they are read by name.
## Grill Log
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
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Compile]] · [[Eval Env]]
