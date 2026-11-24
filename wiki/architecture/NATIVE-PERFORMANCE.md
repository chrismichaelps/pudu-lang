---
type: architecture
tags: [architecture, backend, native, performance]
aliases: [Native Emission Performance]
---

# Native Emission Performance

This ledger tracks reported runtime costs in emitted C11. Each item needs a
reproducible baseline and evidence from the emitted path. The order below puts
potential changes in scaling ahead of smaller per-operation costs. See
[[Native Emission Coverage]] and [[Performance Constitution]].

## Array growth and reads

| Area | Evidence and acceptance |
| --- | --- |
| Self-replacement through `push` and related operations | Measure allocations and elements copied as the workload doubles for `items = items.push(i % 13)`. Verify amortized growth for a unique receiver and that real aliases retain their original values. Preserve receiver-first evaluation, reads of the receiver during argument evaluation, nested writes, transfers, diagnostics and cleanup. |
| Indexed reads | Count retains and releases in repeated array reads. Admit borrowed projections where lifetime and effects allow it. Cover bounds failures, receiver replacement and elements that escape the read. |
| Array header and backing allocation | Count allocations and allocated bytes for small arrays and growing arrays. Evaluate layout changes against capacity growth, alignment and any sharing or lifetime requirements of the backing storage. |

## Numeric operations, calls and control flow

| Area | Evidence and acceptance |
| --- | --- |
| Direct calls | Identify which Float64 signatures and typed aggregate or borrowed arguments miss existing direct entries. Exercise recursion, indirect fallback, ownership transfer, aggregate lifetimes and diagnostic propagation. |
| Call frame allocation | Count allocations for calls that still require frames. Evaluate storage reuse against reentry, recursion, concurrency, escaping state and cleanup on every exit. |
| Fixed-width integers | Measure arithmetic and conversions through the sign-and-magnitude representation. Evaluate a direct fixed-width representation against minimum and maximum values, checked overflow, wrapping, saturation, shifts, remainder, and call and layout boundaries. Emitted operations must have defined behavior at every boundary. |
| Scalar `Option` and `Result` | Measure tag and payload allocation. Start with nonescaping values. Evaluate inline storage across boundaries only after verifying layout, tag selection, equality and comparison where supported, and ownership for payloads that require cleanup. |
| Loop control flow | Inspect which loops still use a frame dispatch cycle. Measure local branches against the existing path and verify transfers, resumability, call limits and cleanup. |
| Arithmetic diagnostic metadata | Inspect generated code and measure the work done on successful arithmetic. Move metadata work off the success path where possible while keeping the original diagnostic, source span, effect order and cleanup. |
| Dynamic dispatch | Inspect emitted selectors and measure dispatch at different numbers of receiver types and targets. Consider indexed dispatch where it preserves method selection, typed call boundaries and the original failure path. |
| Lane operations | Inspect the emitted operations and generated machine code and compare scalar and vector execution. Preserve the scalar path, tails, boundary cases and floating-point behavior, including the existing restrictions on reassociation and contraction. |

## Collections, text and services

| Area | Evidence and acceptance |
| --- | --- |
| Ordered `Map` and `MultiMap` updates | Count node allocations and copied entries for lookups, insertions and repeated updates. Evaluate denser nodes or exclusive updates while preserving key order, duplicate order, comparability and previously shared values. |
| Short text and concatenation | Measure allocation and copied bytes for small strings, repeated concatenation and views. Preserve byte and character behavior, embedded zero bytes, view lifetimes and ownership. |
| Concurrent handle registry and yielding | Measure contention, yields and throughput with one worker and as the worker count increases. Verify lifecycle, cancellation, ordering, scheduler fairness and worker cleanup. |
| JSON validation and value construction | Measure parsing passes, allocation and copying for small, large, nested and malformed values. A combined path must preserve decoded values and ordering, text validation, diagnostic locations, resource limits and cleanup of partial values. |

## Completion evidence

- Measure cold process startup separately from time spent in initialization.
  Pair a minimal entry workload with one that constructs small collections,
  makes short calls, and decodes initial data. Record process elapsed time
  and the initialization allocation counts for each workload.
- Pin the revision, target, build configuration and workload. Record repeated
  before-and-after native runs and verify the result from each run. Establish
  regression budgets from stable baselines.
- Collect metric-specific evidence such as copy volume, allocation counts,
  retains and releases, dispatch cost or contention. Include a size or worker
  count sweep when the report concerns scaling.
- Check that the case executes the intended native path. Compare output,
  diagnostics, effects and lifetimes with interpreter execution, including
  the edge cases in this ledger. Run the coverage and regression gates before
  marking the work complete.

## Implementation awaiting validation

- Local arrays can reuse their receiver for total compound scalar operands
  and read indexed elements without retaining the receiver for a literal or
  local index. Small array buffers share their box allocation.
- The frame runtime reuses one small heap frame within an active execution.
  Eligible floating and narrow signed integer calls use the typed scalar path.
  Typed callees can also borrow record and tuple arguments for scalar and
  nested product projections that need no ownership transfer.
- The JSON reader builds values during document validation. A failed read
  releases initialized members before returning or reporting exhaustion.
- A directly matched scalar constructor can bind its payload slots without
  allocating a sum box when the first applicable arm is statically known.
- Frame branches use local jumps and reserve dispatch for frame entry and
  suspended calls. Ordered trees reuse exclusive nodes during updates and
  rebalancing while shared branches remain persistent.
- MultiMap finds each group and occurrence count once and creates the
  default only for a missing key.
- Small live host registries use inline storage and retire stale token ranges
  without resetting token identity. Host operations skip scheduler clock
  checks after the last worker exits in runs without external callbacks.
- Lane zips select the operation outside the loop and use a fresh output
  buffer, allowing vectorization where the target preserves scalar results.
  Instruction selection still needs target evidence.
- Copies of zero or one byte use immutable shared storage.
- Copies and concatenations of two decimal digits use compact static
  storage. Adjacent text views share a single owner on concatenation, and
  empty views release their source reference.
- Small, non-suspending entry functions use fixed startup frame storage.
- Matches over distinct runtime variants select an arm with one numeric
  switch. Payload tests and guards keep their existing fallback behavior.

## Remaining design and implementation

- Typed calls that return owned aggregate values or project signed integers
  from a borrowed carrier, and wider coverage of unsigned operations.
- Nonlocal scalar sum representation and short text with more than one byte.
- Collection updates that still start from a shared path, in particular
  the repeated ordered updates used by `MultiMap`.
- Target instruction selection for lane operations, arithmetic sites on the
  success path, and registry contention while several workers are active.

## Grill Log

- **Can an allocation be removed by changing evaluation order?** Ownership
  and lifetime proofs must preserve the language's existing effect and
  diagnostic order. Measure the emitted path under those constraints.
- **When does a reported cost become a regression budget?** Establish a
  pinned, repeatable baseline, verify the workload and choose the budget
  from that evidence.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Performance Constitution]] · [[Native Operator Parity Delivery]] · [[CHANGELOG]]
