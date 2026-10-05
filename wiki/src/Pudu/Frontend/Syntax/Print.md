---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Frontend/Syntax/Print.hs"
fidelity: Active
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, syntax, tooling]
aliases: [Syntax Printer]
---

# Syntax Printer

## Purpose and interface

`printImpl` renders an implementation declaration as Pudu source. It covers
every declaration member, statement, expression, pattern and type form an
implementation can hold.

## Invariants

Every compound operand is parenthesized, because the tree records structure
rather than the precedence its text was read with. String literals escape
quotes, backslashes, control characters and interpolation braces. A type
application sharing its callee's span is a selection checking applied, not
written syntax, and prints as the callee alone. Statement blocks that bind
nothing are spliced through [[Statement Inlining]]. Layout is the formatter's.

## Grill Log

- **Q:** Track precedence to omit parentheses? **A:** No; redundant
  parentheses never change meaning and the printer stays total.
- **Q:** Print checker selections? **A:** No; nobody wrote them.

## References

Referenced by [[Derive Expansion Output]] · [[src/Pudu/Frontend/Syntax/_MOC]].
