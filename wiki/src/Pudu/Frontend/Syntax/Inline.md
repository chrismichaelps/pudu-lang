---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Frontend/Syntax/Inline.hs"
fidelity: Active
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, syntax]
aliases: [Statement Inlining]
---

# Statement Inlining

## Purpose and interface

`inlineStatements` splices each statement that is a block binding no name into
the enclosing statement list, its result becoming one more statement.

## Invariant

A block in statement position has its value discarded, so splicing one that
introduces no binding cannot change scope or meaning. Blocks with `let`,
`var`, local functions or destructuring stay intact.

## Grill Log

- **Q:** Splice in the evaluator instead? **A:** No; the shape is generated
  syntax, so the residualizer and the printer apply the same rule once.

## References

Referenced by [[Derive Record Residualizer]] · [[Syntax Printer]] ·
[[src/Pudu/Frontend/Syntax/_MOC]].
