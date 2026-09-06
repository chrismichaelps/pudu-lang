---
type: architecture
status: IMPLEMENTING_UNMEASURED
tags: [architecture, performance, runtime, low-level]
aliases: [Backend Representation Specialization]
---
# Backend Representation Specialization

## Objective
Make representation choice a compiler decision supported by explicit evidence: key domain,
ownership, iteration order, density, lifetime and required operations. Preserve high-level pure
values while lowering proven local workloads to compact storage and fused kernels. This combines
established techniques; novelty is the integration and proof-carrying selection in Pudu, not a claim
that unboxing, arenas or SIMD were newly invented here. C/C++ parity or superiority is a target,
not an achieved result.

## Representation plan IR
Introduce a phase-owned `StoragePlan` alongside typed lowering, with alternatives for generic
persistent trees, word-key tries, dense bitsets, packed scalar vectors and scoped mutable builders.
Every plan carries key-order/equality evidence, scalar width, bounds, alias status, escape lifetime,
layout alignment and fallback. A missing proof selects the existing representation. No speculative
narrowing of arbitrary-precision integers is allowed. Mixed numeric values retain the runtime's
cross-kind comparison and representative rules.

A `KernelPlan` records lookup, bulk-build, filter, join, membership and reduction operations over
those layouts. Fuse only pure operations with identical evaluation and failure order. Lower through
the existing C11 backend target rather than assuming this bootstrap emits optimized Haskell for
user programs. The Haskell evaluator remains a semantic execution path with its own specialized
runtime operations; compiler speed and emitted-program speed are separate deliverables.

## Internal API direction

- `buildOrdered`: consume a verified monotone run with stable duplicate policy.
- `buildScoped`: allocate unpublished mutable storage in ST, populate it, freeze exactly once.
- `probeWord`, `intersectBits`, `filterMask`: scalar-width-specific kernels with checked boundaries.
- `regionAlloc`, `regionSlice`, `regionFreeze`: future region-token APIs; no address escapes its owner.
- `decodeColumnBatch`: checked byte slices to packed typed columns, preserving NULL validity masks.

STD wrappers retain ordinary immutable types. Representation changes stay below them. Explicit
hardware operations, volatile access and DMA require separate capability and lifetime contracts;
a fast collection must not implicitly grant raw memory access.

## Implementation order

1. Implement adaptive ordered Map/Set construction in the Haskell runtime. A single monotonic scan
   establishes the ascending-builder precondition; fallback uses strict insertion. This slice is
   implemented in [[Eval Keyed]].
2. Introduce StoragePlan in lowering with complete source/type evidence, then consume it in an
   integer-only collection path. Avoid changing the shared Value algebra while unrelated work owns it.
3. Add ST-local bulk builders and unboxed scalar storage; retain persistent snapshots by freezing
   or copying whenever uniqueness is unproven. Account for retained parents and conversion costs.
4. Add dense-set bit operations and fused DB column decoding. Select layouts from explicit type and
   density evidence; do not scan entire collections before every lookup.
5. Emit specialized C11 kernels, permit compiler vectorization with proven alignment/bounds, and
   add target feature dispatch before any explicit SIMD instruction set specialization.
6. Integrate region lifetime lowering and allocation accounting. Bound temporary residency and
   avoid pinning movable data merely to expose addresses. Hardware regions remain distinct from GC heaps.

## Expected costs and measurement contract
Ordered Map/Set bulk construction changes from repeated O(n log n) insertion to O(n) comparison
and construction, with O(n) temporary spine storage. Random-order construction remains O(n log n).
Unboxed vectors target lower allocation and better cache utilization; bitset intersection targets
word-wide membership work; fused column decoding targets fewer intermediate values. These benefits
are workload-dependent, with conversion, sparse domains and persistent branching as countercases.

When measurements are authorized, compare equivalent semantics against optimized C++ ordered
containers and flat/hash alternatives, not just an intentionally weak baseline. Include ordered,
random, duplicate-heavy and adversarial builds, mixed lookup/update, retained snapshots, set algebra,
and NULL-heavy database batches. Record elapsed distributions, allocated bytes, residency, GC time,
cache misses and target/compiler flags. Measure cold and warm paths and conversion-inclusive costs.
No benchmarks, builds, tests or reviews were run for this delivery at the user's direction.

## Trade-offs
Packed storage sacrifices cheap heterogeneous updates; scoped mutation demands escape evidence;
SIMD can change exception or floating-point behavior unless tightly constrained; arenas can retain
unused memory until region exit. None justifies weakening equality, purity or bounds checks.
Predictable latency requires allocation/GC budgets and workload limits; it cannot be inferred from
an asymptotic improvement. No universal claim of outperforming C/C++ is supportable without data.

## Referenced by
[[architecture/_MOC]] · [[Performance Constitution]] · [[Eval Keyed]]
