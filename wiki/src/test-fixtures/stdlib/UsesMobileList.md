---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileList.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native]
aliases: [Uses Mobile List]
---

# Uses Mobile List

## Purpose and interface

Stdlib fixture for the recycling list additions of [[Std Mobile View]] and their instructions in [[Std Mobile Stream]]. Its entry drives `mount`, `update`, `windowStart`, `event` and `carriesDetail` of [[Std Mobile Decode]] through the checks below and answers the number of checks that held: 8. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count.

Checks:
1. A list mounts CREATE kind 8, TAG, COLUMNS 1, RANGE with total and first 0, then its rows appended.
2. Shifting the window from first 0 to first 1 removes the leaving row, inserts the entering one, and writes RANGE with first 1.
3. An unchanged list writes nothing.
4. A changed total alone is one 16-byte RANGE.
5. A changed column count alone is one 12-byte COLUMNS.
6. A changed tag replaces the list: a new CREATE, ROOT, then REMOVE of the old id.
7. `windowStart` places and clamps windows, with the four examples of [[Std Mobile View]].
8. Event kind 8 with tag 1 and detail 42 decodes to `Reached(1, 42)`, and `carriesDetail` holds only for detailed kinds.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator. Cell reuse and scroll reports are checked by the simulator run of [[Native Catalog Example]], not here.
- Checks do not depend on the order of the platform's own default colors.

## Dependencies and consumers

Depends on [[Std Mobile View]], [[Std Mobile Decode]] and [[Std Mobile Stream]]. Its checks mirror the window contract that [[Native Catalog Example]] uses.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile View]]. A summary such as "contains a RANGE" would pass a wrong first index or a wrong node id.
- **Q:** Why check the one-field changes separately? **A:** A change to only the total, or only the columns, must write exactly its own instruction; a combined check would hide a commit that rewrote both.

## Referenced by

[[Std Mobile View]] · [[Std Mobile Stream]] · [[Native iOS Recycling Delivery]]
