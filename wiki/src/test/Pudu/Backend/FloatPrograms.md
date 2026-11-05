---
type: module
path: "@root/test/Pudu/Backend/FloatPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Float Programs]
---
# Backend Float Programs

## Purpose and interface

Export floatSuccessPrograms :: [(String, Text, Text)] (label, source, expected
stdout) and floatRefusalPrograms :: [(String, Text)]. [[Backend Native Tests]]
runs each checked source through the evaluator and a strict warning-free
native build, comparing stdout, stderr and status; success programs must also
equal their independent answer.

## Coverage

Literals: 0.1, -0.0, the 1.0e7 fixed/exponent boundary, subnormal and maximal
binary64, maximal and minimal binary32, digit separators and the `Float`
alias. Binary64 arithmetic: per-operation rounding, infinities, NaN and its
negation, overflow, signed-zero results and a cancellation chain. Binary32:
narrowing after every operation, including overflow to infinity and underflow
to zero. Comparisons: NaN predicates, signed-zero equality and ordering.
Transport: loop accumulation, calls, a call whose later argument assigns the
earlier one (snapshot order), if values, negation and loop break values.
Entries: Float64, Float32 and Bool results print and exit zero.

Refusals: %, &, |, ^, &+, *| on floats (`unsupported operator`), `<<` with an
Int count and `~` (`cannot apply`), a Float32 remainder, and a case whose
operands print before the trap.

Independent answers come from Haskell `Double` and `Float` arithmetic, with
binary32 results rendered widened to `Double` because the evaluator shows the
widened value.

## Grill Log

- **Q:** Is matching the interpreter enough? **A:** No; both sides could share
  a formatter or rounding mistake, so success programs also carry answers
  computed from host IEEE arithmetic. _Rejected:_ interpreter-only oracles for
  successful float output.
- **Q:** Can the expected answers be written as Haskell float expressions?
  **A:** Only behind NOINLINE helpers. At -O2 GHC folds `float2Double` of a
  literal Float into the Double literal and rewrites `-0.0 + 0.0` to `-0.0`;
  both made the "independent" answer wrong while native and the interpreter
  agreed. _Rejected:_ Rational conversion, which fails to overflow to
  Infinity when narrowing.
- **Q:** Why do most programs end with `return 0`? **A:** A `main` whose last
  expression is `print` returns `Result[(), Str]`, which native still refuses.

## Referenced by

[[Backend Native Tests]] · [[Native Floating Point]] · [[src/_MOC]]
