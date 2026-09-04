---
type: handoff
status: REVIEW
date: 2026-09-04
issue: 212
tags: [handoff, ffi, foreign, ownership, lsp]
aliases: [2026-09-04-foreign-out-slots]
---

# Foreign Output Slots Handoff

## Role transition

- **Language Architect:** owns [[ADR-0019-getting-a-value-back-out-of-a-library]] and the distinction
  between total value slots, nullable pointer slots, and buffers.
- **Independent Language Architect:** reads the decision without editing and resolves the three
  questions issue #212 left open before implementation begins.
- **Semantic Implementer:** after acceptance, owns the bounded parser, syntax-tree, resolver,
  checker, interface, evaluator, ownership-store, LSP, formatter, and fixture slice named by the
  implementation issue.
- **Forensic Guardian:** verifies that the implementation and every mirrored page say the same thing
  and that no unbuilt promise appears as current behavior.

## Invariants

- A foreign slot is a native argument and never a value the Pudu caller must manufacture.
- The Pudu result is one tuple containing the native result first and slots in declaration order.
- Scalar and record slots are total unsafe assertions; zero is never interpreted as evidence of an
  absent write.
- Null text and handle pointers become `None`; non-null owned handles are claimed before exposure.
- Status never determines ownership generically: a failed SQLite open may still return a handle that
  must be closed.
- A fallible native close is not an ownership destructor; SQLite uses a small C binding surface with
  a unit, completion-guaranteed release rather than lying about `sqlite3_close`'s ABI.
- Direct owned results and owned slots are one atomic claim set; every unambiguous fresh resource is
  released on a post-call conversion or claim failure.
- Buffers retain a separate capacity, initialization, mutation, and lifetime decision.
- Existing direct-result, owned-result, Raylib, and C++ C-ABI behavior remains unchanged.

## Exact next action

Obtain Forensic Guardian wiki-parity approval, merge the design PR into `dev`, then create one
implementation issue whose acceptance criteria reproduce the validation section without broadening
the pointer model.

## Validation plan

- Inspect the ADR against SQLite's documented open/close behavior and libffi's pointer-to-argument-
  storage calling model.
- Require one explicit decision for tuple shape, unwritten scalar detection, and buffers.
- During implementation, prove every admitted scalar/record slot, nullable text, nullable owned
  handles, atomic multiple claims, tooling inference, and a real SQLite open/destroy binding.
- Run the focused fixture, full unoptimized suite, and all seven release gates before merge.

## Validation evidence

- SQLite documents `sqlite3 **ppDb` as an output and requires a non-null returned database object to
  be closed even when open reports an error; only allocation failure guarantees null.
- SQLite's ordinary close is fallible and may leave a busy database open, so it cannot satisfy the
  existing exact-handle-to-unit owned-release contract. The integration binding must provide an
  honest non-failing destructor surface, for example over deferred close.
- libffi accepts an array of pointers to argument storage, so a pointer-to-output cell is represented
  by caller-owned storage and does not require exposing a raw pointer to Pudu.
- The current parser, syntax tree, checker, runtime installer, evaluator boundary, and ownership store
  have been traced; each currently models every foreign parameter as caller-supplied and one direct
  result, so this is a cross-phase language slice rather than a runtime-only adapter.
- The independent Language Architect requested corrections for SQLite's fallible close contract,
  post-call ownership cleanup, direct-result transaction membership, and the nondeterministic real
  null test. The revised ADR resolves all four and received approval with no blocking findings.

## Grill Log

- **Q:** Use a tuple or generate a record? **A:** Tuple. _Rationale:_ it is an existing source-visible
  product type and preserves native result plus source order. _Rejected:_ a nominal type with no
  declaration or one extra declaration per symbol.
- **Q:** Detect an unwritten scalar by zeroing it? **A:** No. _Rationale:_ a legitimate zero write is
  observationally identical. _Rejected:_ fabricated optionality for non-pointer slots.
- **Q:** Build buffers in the same slice? **A:** No. _Rationale:_ buffers have capacity, partial
  initialization, pre-call ownership, and mutation that output slots do not. _Rejected:_ calling
  every pointer an output slot.

## Referenced by

[[handoffs/_MOC]] · [[ADR-0019-getting-a-value-back-out-of-a-library]]
