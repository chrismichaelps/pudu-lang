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


## Unit literals and parameters (#492)

Differential corpus covers unit literals in entry/local/return/break, aliased unit parameters, unit calls before later scalar arguments with printed order, mixed unit/scalar arguments, mutation, wrapper recursion and unit-argument arithmetic failure preventing later effects.

Resolved Grill Log: preserve the single unit inhabitant and every effect without allocating a new representation. Reject void-valued C initializers, Result erasure and omitted argument evaluation. Nonempty tuples remain pending; #493 implements unit display/equality.


## Unit display and equality (#493)

Add differential unit display, unit helper/branch display and discarded display effects, equality/inequality with ordered printed effects and mutation, transfers, and arithmetic failures preventing later display/equality effects. Use actual interpreter expectations and warning-free C.

Resolved Grill Log: unit has one value but its operands still execute. Reject skipped/repeated effects, void C initializers, wrong runtime printer selection and accidental ordered/arithmetic unit admission. Owned text representation and E7001 invalid-operation lowering remain separate obligations.

#493 carrier regression: displaying a true no-else conditional that discards a print Result remains accepted and prints unit. This protects the distinction between effect-only Result carriers and actual normal unit results.


## Explicit scalar runtime refusals (#494)

Extend actual differential programs with Bool ordering, unit/Bool operator failures, exact generic-versus-comparisonOnly messages, unary failures, shifted nonintegers, mutation/printed operand order, guarded failures, and abrupt return/break/continue operands. Operands fail before later operands/traps; inspect byte-identical output/diagnostics/status.

Resolved Grill Log: reproduce actual interpreter dispatch, canonical settled kinds, operand order and diagnostic spans; never classify print Result as unit or implement invalid operations as integer arithmetic. No syntax/inference change.

#494 source provenance: differential operator-failure cases include expanded macros and Unicode/tabbed authored source, preserving whole-operation excerpts and scalar source columns through ordinary compiler products. Resolved Grill Log: validate actual emitted diagnostics rather than assuming shared site geometry proves generated input parity.

## Recursive frame-pressure regression (#499)

Add a refusal program with 96 integer parameters live across a recursive call.
Each recursive argument changes, and the returned answer chooses between two
uses of all original parameters. This prevents trivial tail-loop replacement.
The initial depth is callDepthLimit + 104. Both evaluators report E7002 at the
recursive call; native execution must match its stderr and status, never signal.

Resolved Grill Log: the fixture stays below C11's guaranteed minimum supported
parameter-count translation limit, even with the wrapper's site pointer. It
uses ordinary checked Pudu source and the existing differential failure harness.
Do not reduce the language bound, skip the case, or accept a host stack crash.
This is an explicitly failing regression until #499 repairs frame storage.

## Shadowed builtins (#513)

A module `fn print(value: Int) -> Int` and a module `fn display(value: Bool) -> Int`
are called as declared, natively and in the interpreter, with the results
observable through the exit status.

## Open inferred results (#633)

A function whose result checking leaves open returns unit, bound, compared
and discarded. Resolved Grill Log: moved here from the EmitSpec refusal table
once open variables formed as unit.
