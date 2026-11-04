---
type: module
path: "@root/test/Pudu/Backend/TryPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Try Programs]
---
# Backend Try Programs

Exports trySuccessPrograms (label, source, expected stdout) and
tryRefusalPrograms (label, source).

Resolved Grill Log: chained `?` across functions with different success
types, `?` on Option with effects before and after it, `?` inside a loop and
inside operator and call arguments (showing what runs before the return), and
entries returning Result and Option that render the failure `?` returned. The
refusal is an overflow after a `?` passed, which reports at its own source.

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]]
