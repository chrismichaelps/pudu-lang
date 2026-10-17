---
type: module
path: "@root/test/Pudu/Backend/FunctionPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, conformance]
aliases: [Backend Function Programs]
---

# Backend Function Programs

## Purpose and interface

`functionSuccessPrograms` and `functionRefusalPrograms` provide named source
programs for [[Backend Native Tests]]. This data-only corpus keeps the native
execution harness separate from milestone #488 function semantics.

## Behavior and dependencies

Every program is a complete `Main` module. Success programs exercise typed
`Int` and `Bool` parameters, `Int`/`Bool`/unit results, nested calls with printed
effects in source order, early returns, Unicode helper names, direct and mutual
recursion, mutable local snapshots before right operands and later arguments,
short-circuit effects, C11 trigraph-bearing text and unused locals, grouped comparisons, and a helper used by a resultless
function. Depth cases derive their input from [[Compile Time Limits]]: the
last accepted depth, repeated calls that restore depth, and one excessive depth
that must render `E7002` identically to the interpreter.

## Algorithm and negative logic

Sources are assembled with `Text.unlines`, never generated C or handmade Core.
The existing differential harness owns compiling, executing, and comparing
stdout, stderr, status, and C warnings. The corpus exports only named programs
and introduces no independent runner or skip path.

## Resolved Grill Log

- **Q:** Why split the corpus? **A:** The execution harness already approaches the 500-line ceiling. Data belongs in one bounded module, while compiler/toolchain control stays in its existing owner.
- **Q:** Are depth constants duplicated? **A:** No; source recursion arguments derive from `callDepthLimit`, so a limit change still tests the boundary and its successor.
- **Q:** Can ordering be tested by final values alone? **A:** No; printed helper effects and mutable operand snapshots make sequencing visible to byte-for-byte comparison.

## Referenced by

[[Backend Native Tests]] · [[src/_MOC]] · [[src/Pudu/Backend/_MOC]]


## Solved native type inputs (#491)

Extend the actual differential corpus with inferred Int/Bool parameters/results, inferred unit helper, scalar aliases and annotated mutable locals, and inferred recursive helpers. Preserve printed effect ordering and do not special-case native expected outputs.

Resolved Grill Log: consume canonical settled checker facts; preserve structural Never, print carrier refusals and existing runtime representations. Rejected: re-inference, display-name ABI selection, offset-only identity or silent fallback.
