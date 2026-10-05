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
syntax rendered by [[Syntax Printer]] and laid out by the formatter. A sum's
payload read prints as the destructuring `let` generated code uses; authored
code would need `let … else` for it, so the output is for reading and is not
promised to compile as a separate module.

## Grill Log

- **Q:** Print the executable product? **A:** No; the printer omits checker
  selections and splices blocks that bind nothing, so the text reads as a
  person would write it while meaning the same.
- **Q:** Promise re-parseable output? **A:** No. Payload reads intentionally
  keep their ordinary E7013 mismatch, which has no authored spelling.

## References

Requires [[Syntax Printer]] and [[Compiler Program]]. Referenced by [[Pudu CLI]]
· [[Derive Design]] · [[src/_MOC]].
