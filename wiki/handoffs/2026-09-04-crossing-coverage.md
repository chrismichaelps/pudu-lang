---
type: handoff
status: REVIEW
date: 2026-09-04
issue: 204
tags: [handoff, ffi, crossing, abi]
aliases: [2026-09-04-crossing-coverage]
---

# Foreign Crossing Coverage Handoff

## Role transition

- **Language Architect:** fixes exact signedness, UTF-8 text, result-only void, and bridge capacities in [[ADR-0018 Calling a Library Written Elsewhere]].
- **Runtime/Semantic Implementer:** owns the four affected modules, native bridge, C++ fixture, focused programs, and their mirrors.
- **Independent Language Architect and Forensic Guardian:** review without editing; no unresolved P0/P1 finding may merge.

## Invariants

- Every shape the checker admits can be assembled by the native bridge.
- A 64-bit carrier preserves bits; the declaration restores signedness for values and record fields.
- `Str` is UTF-8 regardless of locale; storage spans the call, results are copied, and malformed bytes are refused.
- `()` is a result only. It is never a parameter or stored record field.
- Calls carry at most 32 arguments and flat records 32 fields; both are checked statically and guarded natively.
- Ownership is unchanged; pointers, nullable values, callbacks, nested records, and owned text remain out of scope.

## Exact next action

Commit, push, open the PR to `dev`, obtain both required reviews, resolve P0/P1 findings, and merge on green CI.

## Validation evidence

- Clean `bash test/gates.sh`: all seven stages pass.
- Diagnostic uniqueness: 127 codes across 129 sources, with 18 deliberately shared codes.
- Focused C++ fixture: sixteen assertions pass; invalid text is `E7025`, null text `E7024`, and invalid shapes use `E3070`, `E3063`, and `E3069`.
- Installed Raylib 6.0 headless integration: scalar call, allocation, and checked release exit zero.

## Grill Log

- **Q:** Add surface syntax? **A:** No. _Rationale:_ these shapes are already admitted. _Rejected:_ a second binding syntax.
- **Q:** Hide bridge capacities? **A:** No. _Rationale:_ a fixed bound is observable language behavior. _Rejected:_ runtime-only failures.
- **Q:** Decode lossy text? **A:** No. _Rationale:_ replacement changes native data. _Rejected:_ locale decoding and replacement characters.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
