---
type: module
path: "@root/src/Pudu/Eval/Foreign/Resource.hs"
fidelity: Active
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, ffi, ownership]
aliases: [Eval Foreign Resource]
---

# Eval Foreign Resource

## Purpose

Resolve destructor availability before native resource production, discharge failed output batches,
and record cleanup failures without replacing the original runtime failure.

## Interface

`prepareReleases` resolves every distinct declared producer destructor and returns a lookup failure
before native dispatch. `releaseHandle` invokes a declared destructor and records `W7027` on lookup,
assembly, or host IO failure. `cleanupUnclaimed` protects existing addresses and cleans one fresh
address only when its canonical identity and destructor agree. `cleanupFailedOutputs` reconstructs
release obligations for raw handles retained through text-conversion failure.

## Covered by

`RejectsForeignInvalidUtf8WithSlot` declares `pudu_ffi_cpp_invalid_utf8_with_box`, which writes a box
through a slot and returns text that cannot be decoded. The call is refused as `E7025`, the native
destructor runs once, and no live box remains. The assertion counts real destructor calls in the C++
fixture, so disabling `cleanupFailedOutputs` fails it with the box still allocated rather than merely
changing a diagnostic.

## Dependencies and consumers

Requires [[Foreign Call]], [[Foreign Ownership]], [[Eval Value]], and [[Diagnostic Model]].
Consumed by [[Eval Foreign]]. Contains no Pudu value conversion or source parsing.

## Algorithm and failures

Group outputs by address, reject ambiguous destructor groups, and claim or dispose atomically through
the ownership store. A cleanup failure is recorded with the foreign call's span in the per-run
journal. Multiple cleanup attempts continue after an individual typed or IO failure. No destructor
is retried after invocation, because failure cannot establish that it did not free its object.

## Prohibited paths

No cleanup inferred from naming, freeing protected addresses, arbitrary destructor selection,
exception substitution for expected foreign failures, or global diagnostic state.

## Grill Log

- **Q:** Resolve destructors only after a producer returns? **A:** No; resolve beforehand so missing
  symbols cannot create resources with no callable release.
- **Q:** Drop failures during best-effort cleanup? **A:** No; record them as diagnostics. When a
  boundary already failed, attach them as related messages; teardown warnings preserve a success value.
- **Q:** Catch every host exception? **A:** No; only IO failures become cleanup warnings. Runtime
  cancellation and fatal host conditions must not be silently consumed by this helper.

## Native output provenance

Retained handles include their native parameter index (`Nothing` for the direct result). Cleanup
uses that exact declaration's destructor, so two outputs of the same type may name different release
functions without being conflated. A missing or mismatched obligation is reported without guessing.

### Resolved Grill

- **Q:** Recover a release using only the handle's type name? **A:** No; source position identifies
  the producer obligation, while the type only identifies the nominal value.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Foreign]] · [[Foreign Ownership]]
