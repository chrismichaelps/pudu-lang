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

`printImpl :: ModuleName -> Impl -> Text` renders an implementation declaration
as Pudu source written inside the given home module. It covers every
declaration member, statement, expression, pattern and type form an
implementation can hold.

## Invariants

Every compound operand is parenthesized, because the tree records structure
rather than the precedence its text was read with. String literals escape
quotes, backslashes, control characters and interpolation braces. A type
application sharing its callee's span is a selection checking applied, not
written syntax, and prints as the callee alone. Statement blocks that bind
nothing are spliced through [[Statement Inlining]]. Layout is the formatter's.
A type, pattern, record or name path the home module declares prints bare, the
way that module's own code spells it; every other path keeps its canonical
qualification.

## Grill Log

- **Q:** Track precedence to omit parentheses? **A:** No; redundant
  parentheses never change meaning and the printer stays total.
- **Q:** Print checker selections? **A:** No; nobody wrote them.
- **Q:** Print every path canonically? **A:** No. _Rationale:_ a module cannot
  name itself as a qualifier, so `Local.Point` inside `Local` does not resolve;
  the home module's own names print bare and the text checks where it stands.
  _Rejected:_ canonical-only paths; relativizing against the requesting
  module, whose imports the printer does not know.

## References

Referenced by [[Derive Expansion Output]] · [[src/Pudu/Frontend/Syntax/_MOC]].

## Derive index contract (#458)

`printType :: ModuleName -> Located TypeSyntax -> Text` exposes the existing total type renderer to [[Doc Index]], preserving trait arguments and qualified paths in strategy headers.

Resolved Grill Log: reuse one type renderer rather than reconstructing declaration types in consumers.
