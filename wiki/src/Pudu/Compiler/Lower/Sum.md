---
type: module
path: "@root/src/Pudu/Compiler/Lower/Sum.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Sum]
---
# Compiler Lower Sum

## Purpose and interface

Export `lowerVariant` and `variantAt`.

- A name or call is a variant only when the checker typed its span as a sum
  with a variant of that name taking that many positional members, so a local
  or function of the same name is never mistaken for one. Record variants go
  through [[Compiler Lower Record]].
- Payload members run left to right into `CoreConstruct`, named "0", "1", ...
  A Never member stops the variant after the members before it ran.

## Grill Log

- **Q:** Decide a variant from its spelling? **A:** No; the checker's type at
  the span decides, which keeps shadowing and qualification (`Shape.Circle`)
  exactly as checking resolved them (#536).
- **Q:** Why stop at a Never payload? **A:** The evaluator stops there too; the
  later payloads never run and no value is built.

## Referenced by

[[Compiler Lower Body]] · [[Native Emission Coverage]] · [[src/_MOC]]
