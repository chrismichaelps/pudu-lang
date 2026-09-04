---
type: handoff
status: IMPLEMENTED_UNVALIDATED
date: 2026-09-04
issue: 217
tags: [handoff, ffi, ownership]
---

# Foreign Boundary Failure Hardening

## Role transitions and ownership

Language Architect → Runtime Implementer: this pass owns `src/Pudu/Foreign/Ownership.hs`,
`src/Pudu/Foreign/Call.hs`, `src/Pudu/Eval/Foreign.hs`, and their existing mirrors. Existing local
ADR-0021 proposal edits belong to the prior work and remain preserved separately.

The user explicitly requested direct delivery to `dev` and no tests, heavy verification, or reviews.
Independent review was stopped when that instruction arrived. No approval or validation is claimed.

## Implemented changes

- Batch claims reject duplicate addresses instead of silently coalescing them.
- A failed batch identifies existing protected claims separately from fresh products.
- Cleanup never invokes the destructor of a protected address, and invokes a fresh address's
  destructor once only if all its canonical type and release obligations agree.
- Text-conversion failures retain raw produced handles before decoding direct results or slots.
  The evaluator cleans unambiguous products before reporting the conversion failure.
- Semantics and standard-library documentation acknowledge output-slot code already present in
  the baseline rather than calling that entire slice unimplemented.

## Remaining assurance gaps

This is not a zero-leak guarantee. Conflicting native destruction obligations cannot safely be
resolved by guessing. Cleanup symbol-resolution and invocation failures are still suppressed by the
existing release helper. Asynchronous interruption can still cross ownership acquisition, native
return, and explicit release intervals; a complete cancellation protocol is outstanding. The store
uses addresses rather than generation-bearing resource identities, so address reuse needs separate
liveness analysis. Teardown leaves busy resources after its deadline. Native declarations still
assert pointer validity, ABI layout, and complete initialization that Pudu cannot verify.

No test suite, build, benchmark, or heavy verification ran in this pass. No performance improvement
or full ADR-0019 conformance is asserted. See [[architecture/FFI-SELF-HOSTING]] for the remaining scope.

## Exact next action

Implement cancellation-safe ownership transitions spanning native dispatch, raw-output capture,
claim settlement, and explicit release, preserving typed cleanup failures as related diagnostics.

## Referenced by

[[handoffs/_MOC]] · [[Foreign Ownership]] · [[Foreign Call]] · [[Eval Foreign]] · [[CHANGELOG]]
