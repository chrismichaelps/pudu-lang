---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Expand.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, tooling]
aliases: [Derive Expansion Output]
---

# Derive Expansion Output

## Purpose and interface

`expansionText` answers every implementation generated for a request the root
module wrote, in program order, each under a comment naming the trait, the
target and the module the derive definition placed it in. `pudu expand <file>`
prints it.

## Invariants

Selection uses the generated span's request anchor, never names, so an impl
requested elsewhere in the program is not printed. The text is the checked
syntax rendered by [[Syntax Printer]] with the defining module as home, and
laid out by the formatter: the text is the impl as that module's own code would
write it. A sum's payload read is the `let … else` the generated code runs.
When the derive is defined in the requesting module, the printed text, written
in place of the derive definitions and `derives` entries, checks and runs the
same in both evaluators. A library derive's text reads as code inside the
library module, whose private helpers it may call.

## Grill Log

- **Q:** Print the executable product? **A:** No; the printer omits checker
  selections and splices blocks that bind nothing, so the text reads as a
  person would write it while meaning the same.
- **Q:** Promise re-parseable output? **A:** Yes, in the defining module.
  _Rationale:_ payload reads are generated as authored `let … else` code and
  names print relative to the module the impl stands in, so nothing printed is
  unwritable there. _Rejected:_ promising a standalone module for library
  derives, whose bodies call that library's private helpers; exporting those
  helpers only so printed text could compile elsewhere.

## References

Requires [[Syntax Printer]] and [[Compiler Program]]. Referenced by [[Pudu CLI]]
· [[Derive Design]] · [[src/_MOC]].
