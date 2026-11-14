---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Scope.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Scope]
---
# Compiler Lower Scope

Export released, lowerScope, leaving and leavingLoop. `lowerScope` lowers
`async with scope { ... }`: the scope opens, its block runs, and the children
left are joined in the order they were made. `released` lets a task go from
the innermost open scope when it is awaited and runs it. `leaving` answers
the joins a `return` owes for every scope open in the function; `leavingLoop`
answers the joins a `break` or `continue` owes for the scopes opened inside
the loop it leaves.

## Resolved Grill Log

A scope is recorded by how many loops were open around it, so a loop transfer
joins exactly the scopes it crosses. A value a way out carries is in hand
before the joins run. A failure that leaves the function joins the same way,
through [[Compiler Lower Try]].

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Try]] · [[Native Host Scopes]] · [[Native Host Services]]
