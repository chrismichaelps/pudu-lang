---
type: module
path: "@root/test/Pudu/Backend/LedgerAuditPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Ledger Audit Programs]
---
# Backend Ledger Audit Programs

Exports `ledgerAuditPrograms` and `ledgerAuditRefusals`, for [[Native Maps and Sets]] and the module properties in `test/Pudu/Backend/NativeSpec.hs`.

## Success programs

`ledgerAuditPrograms` holds one dense program per coverage-ledger claim that is Partial. Each is run by the several-modules conformance property and compared with the interpreter in both engines.

| Claim | Covered forms |
| --- | --- |
| pattern forms | guards, or-patterns, record and sequence patterns, let-else, `while let`, and every iterated shape |
| trait defaults and callables | trait default methods, generic bounds, composed lambdas, bound methods, callable arrays |
| generic and recursive data | generic records, recursive sums, sorted tuples, map, set and range queries |
| qualified calls | qualified, selective and value calls into a module's functions and constants, callable constants included |
| cells and tasks | cells, counters across started tasks, a closed channel drained |
| text conversions | text to Int, Float and Decimal across signs, bases and overflow |
| text methods as values | text methods taken as values and called later |

- an empty array literal compares with a sequence's array held as a runtime choice, on either side (#1024)

## Refusal programs

`ledgerAuditRefusals` holds one program per refusal claim. Each is run by the imported-module refusal property, and each stops after its earlier output:

- integer division by a zero held in a binding;
- Int addition past the maximum;
- an array index past the end;
- negating the minimum Int;
- a shift by more than the width;
- `panic`;
- unbounded recursion, stopped at the call-depth limit after shallower calls finish.

## Resolved Grill Log

Why dense programs: each program combines the forms one claim covers, so a single compile tests the whole claim, and a failing program's label names the claim it breaks.

Why both engines: a Partial claim is one the native backend covers only in part. Running the same program in the interpreter and the native build shows that the covered forms produce exactly the interpreter's output.

Why the module properties: the qualified-call claim needs a second module, and the module properties already supply module lists. Each success program carries its own modules, so no new property is added.

## Referenced by

[[Backend Keyed Programs]] · [[Native Maps and Sets]]
