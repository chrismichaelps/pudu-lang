---
type: architecture
aliases: [Native Wide Source Admission]
tags: [native, numeric, conformance]
---
# Native Wide Source Admission

## Contract

After the wide frame bridge is validated, admit canonical Int128 and UInt128
through nativeIntegerKind's fixed-width predicate. Preserve the existing formed
NominalId Nothing/no-type-arguments guard, exact checker facts and all lowerer
consumers. Do not infer a type from spelling or change either interpreter.
Keep BigInt, floating families and other unrepresented types explicitly refused.
This projects existing language behavior; no syntax or numeric meaning changes.

## Ownership and evidence

Backend Engineer owns Compiler.Lower.Types and its mirror. Test Engineer owns
SignedPrograms, UnsignedPrograms, LowerTypesSpec, EmitSpec and NativeSpec, with
matching mirrors. Extend existing independent Integer matrices to width 128,
including deferred positive 2^127, extrema, all arithmetic/bitwise/shift policies,
zero divisors, negation, overflow and invalid counts. Preserve narrow matrices.
Add mixed signed/unsigned/narrow calls, mutation during argument evaluation,
recursive wide returns, unit-result branches and loop/return transfers.

Canonical projections must distinguish user-owned Int128/UInt128 and generic
primitive shapes. Replace obsolete 128-bit lowering-refusal cases with reachable,
well-typed BigInt and floating parameter refusals, retaining exact marker spans.
Wide entry cases cover negative minimum, positive/unsigned maxima, 0/1/255/256,
high unsigned values and an accepted deferred positive boundary, compared with
the existing CLI result policy. Keep test modules below 500 lines.

Run actual source programs through tree and compiled evaluators and native C,
comparing exact stdout/stderr/status, diagnostic source rendering and effect
ordering. Independent Integer stdout expectations constrain the success matrix.
Include strict Clang/GCC compilation, ASan/UBSan, clean full repository gates,
real CLI execution/status and static boundary refusals. Check narrow regressions
and heap-frame cleanup remain valid; existing controlled allocation/cleanup
corpora remain required. No fallback may turn an E6001 into apparent support.

Numeric-family coverage remains Partial: this completes neither BigInt/floats
nor the remaining language/runtime areas. Independent implementation,
architecture/wiki review and additional supported platforms remain promotion
requirements, without spawning subagents or treating self-audit as approval.

## Resolved Grill Log

- **Q:** Admit by the text Int128? **A:** No; only the canonical formed identity with no arguments selects a primitive carrier.
- **Q:** Convert the deferred positive boundary to signed bits early? **A:** No; preserve both words and actual sign through every transfer until the selected operation settles it.
- **Q:** Compare only against an interpreter sharing a bug? **A:** Also pin independent mathematical outputs and actual CLI observations.
- **Q:** Delete negative tests that now admit 128-bit values? **A:** Replace them with still-unrepresented, well-typed reachable constructs and keep span assertions.
- **Q:** Claim source support from Core-only tests? **A:** No; compile real checked source and run both evaluators plus emitted executables.

## Dependencies and consumers

[[Native Wide Integers]] · [[Native Wide Frame Bridge]] · [[Compiler Lower Types]] · [[Native Signed Programs]] · [[Native Unsigned Programs]] · [[Backend Native Tests]] · [[Native Solved Types Tests]] · [[Backend Emit Tests]]

## Referenced by

[[architecture/_MOC]] · [[Native Wide Source Delivery]]
