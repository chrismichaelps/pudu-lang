---
type: module
path: "@root/test/Pudu/Backend/DeferredPrograms.hs"
fidelity: Active
aliases: [Backend Deferred Integer Programs]
---
# Backend Deferred Integer Programs

## Purpose and interface

Export deferredSuccessPrograms :: [(String, Text, Text)] and
 deferredRefusalPrograms :: [(String, Text)]. Existing native integer groups
execute ordinary checked Pudu files; success triples include exact expected
stdout and exit zero through the mathematical harness.

## Coverage and invariants

Admit positive 2^63 via a block/local whose later negation settles Int. Test
actual printing, locals/mutation, parameter/return/call carriers, comparisons,
all arithmetic policies, bits/shifts, branch/loop result slots and operand order.
Use accepted source with an explicit Int-typed first negation to settle the
literal constraint before subsequent consumers. Later negation uses an explicitly
typed helper parameter: repeating unary negation on the unresolved literal
binding can flip its checker constraint again and makes the source E3018.
That existing checker behavior is preserved; invalid source is not native
conformance evidence. Test checked result overflows,
division/shift refusals and exact source geometry through the existing native
failure harness. Keep the oracle unchanged; invalid source is a test failure.

## Resolved Grill Log

- **Q:** Remove refusals and count admission alone as success? **A:** No; actual native output/status must equal tree execution and independent expected results.
- **Q:** Reuse production formulas for expected output? **A:** No; explicit mathematical values are the oracle alongside interpreted execution.
- **Q:** Skip ordinary integer and Never regressions? **A:** No; they run through the same modified ABI and existing full suite.

## Dependencies and consumers

[[Backend Integer Programs]] · [[Backend Native Tests]] · [[Exact Native Integer Carriers]]

## Referenced by

[[src/_MOC]] · [[Native C11 Backend Delivery]]
