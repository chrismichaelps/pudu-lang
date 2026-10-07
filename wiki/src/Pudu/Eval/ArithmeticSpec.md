---
type: module
path: "@root/test/Pudu/Eval/ArithmeticSpec.hs"
fidelity: Active
tags: [test, evaluation, operators]
aliases: [Eval Arithmetic Tests]
---
# Eval Arithmetic Tests

## Purpose and interface

Export focused arithmetic, retained-width and tuple-ordering properties for [[Eval Test Coordinator]].
Existing cases cover precedence, numeric operators, text concatenation, escaping, floating precision,
checked overflow, shifts, wrapping, saturation and integer conversions.

## Tuple ordering algorithm

Compile and evaluate exact tuple comparisons across all four relations, tied prefixes, nested
aggregates, finite numeric widths, Decimal scales and equality. Check constant folding, generic
callbacks and stable sorting through [[Uses Tuple Ordering]]. Refuse unorderable payloads and
unsupported arithmetic with E7001, retaining its comparison span and wording; mismatched tuple
arity or field types remain E3001. Operand effects stay left to right.

## Resolved Grill Log

- **Q:** Infer sorting correctness from its length? **A:** No; assert the complete output order.
- **Q:** Let an early differing field hide an unorderable payload? **A:** No; guard both whole tuples.
- **Q:** Add only an uncalled property list? **A:** No; register with the executable coordinator.

## Referenced by

[[Eval Test Coordinator]] · [[Eval Operator]] · [[Uses Tuple Ordering]] · [[src/Pudu/Eval/_MOC]] · [[src/_MOC]]
