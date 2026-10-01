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
`slotLayout parameters body` answers each parameter's and each `let`'s position, or nothing.
## Governance and algorithm
A body gets slots when it declares a local and every name it binds anywhere — parameters, `let`s,
and every pattern — is distinct. Then nothing in it shadows anything else, so a name in the layout
means its slot wherever it is written, and pattern names, which bind through frames above, never
collide with one. A function literal inside the body is its own body and is not looked into.
## Grill Log
- **Q:** Track scopes so a shadowing body can still use slots? **A:** No. _Rationale:_ a fixed layout
  maps one name to one position, which is what lets the tree walker read a slot frame by name;
  shadowing already draws a warning, so few bodies are left out. _Rejected:_ a layout that changes
  as blocks open and close.
- **Q:** Give every body slots? **A:** Only one with a local of its own. _Rationale:_ a body reading
  only its parameters, like a small recursive function, paid more to set up slots on each call than
  it saved; measured on `fib(27)` that was 0.36 s against 0.40 s.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Compile]] · [[Eval Env]]
