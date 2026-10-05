---
type: module
path: "@root/src/Pudu/Eval/MultiMap.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval MultiMap]
---

# Eval MultiMap

## Purpose and interface

Fuse the append and occurrence increment beneath [[Std MultiMap]] without changing
its persistent record representation. `callMultiMapAdd` and `callMultiMapContains`
take a source span and evaluated arguments and return `Evaluator Value`. The wired
`multiMapAdd[K, V](&Std.MultiMap.MultiMap[K, V], K, V)` returns the same nominal
MultiMap type; `multiMapContains` takes the same arguments and returns Bool.

## Algorithm and invariants

Read the two map fields of the MultiMap record. Add checks key orderability, then
appends to the selected array with `Map.insertLookupWithKey`. It checks pair
orderability and increments the selected Int count with a second single-pass
insert-and-lookup. Incoming equal-key representatives replace prior ones exactly
as the existing Map insertion does; a before/after Decimal output oracle proves
this detail. [[Eval Operator]]'s checked addition reports occurrence overflow. Each map is
traversed once. Membership performs one index lookup of the pair.
The result uses the canonical `MultiMap` constructor tag and field order, exactly
as the library constructor did.
Group order, duplicate counts, and original maps remain unchanged. No full-map validation or mutable storage is introduced.

## Failures and negative logic

Unorderable inserted keys or values retain E7008; checked occurrence overflow
retains E7005. Malformed record/maps/payloads yield E7001 and wrong arity E7003.
Membership never inserts or validates key orderability, matching Map.containsKey.
Do not recognize Std functions by name, change key ordering, skip counts,
rewrite the benchmark, or convert persistent storage to mutation.

## Dependencies and consumers

Requires [[Eval Value]], [[Eval Env]], [[Eval Order]], [[Eval Operator]], and
[[Eval Builtin Collection]], [[Syntax Tree]], [[Syntax Located]], plus host Map and Sequence. [[Eval Builtin]] dispatches
the two primitives; [[Std MultiMap]] provides the public wrappers.

## Grill Log

- **Q:** Replace the occurrence index with an array scan? **A:** No; repeated
  membership must keep indexed lookup and duplicate counts.
- **Q:** Add a generic record-shaped identity primitive? **A:** No; both schemes
  name the canonical Std.MultiMap nominal type, as existing JSON primitives do.
- **Q:** Validate every group/count on each update? **A:** No; inspect the two
  record fields and touched entries only to avoid making construction quadratic.
- **Q:** Skip checked addition? **A:** No; use the shared checked result path.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Std MultiMap]] · [[Eval Builtin]] ·
[[Pudu Cabal Manifest]] · [[2026-10-01-multimap-performance]]

## Transparent primitive wrappers

The immutable capture proof refuses both SlotFrame and CellFrame. Ordinary
captures snapshot these into MapFrame; a live mutable frame is never evidence
that a primitive binding remains fixed. Resolved Grill Log: expand the existing
mutable-frame refusal when adding lexical block cells.

`multiMapWrapper` recognizes only a synchronous, receiver-free, default-free
three-parameter closure whose complete body is one call forwarding those parameters
in order to a captured MultiMap builtin value. The captured binding must resolve
to one of the two primitive tags; function or module names alone prove nothing.
[[Eval Compile]] can invoke that primitive directly after evaluating arguments and
checking caller shadowing. The wrapper's inner call span, closure-call tally, and
call-depth refusal boundary is retained. [[Eval Call]] applies the same proof after ordinary tree-mode callee resolution.
Exclusive parameters and calls with other than three supplied arguments fall
back to ordinary argument binding, preserving diagnostics and lending.
Closures with extra statements, defaults, async, or a shadowed callee retain
ordinary function evaluation.

Resolved Grill Log: eliminate redundant frame construction only after proving
transparent argument forwarding and immutable captured builtin identity. A user's
Std module or function with the same name is never sufficient to select a kernel.

## Pure insert-and-lookup

Map.insertLookupWithKey returns the old touched payload and the updated persistent
map together. Its pure callbacks append/increment without threading Evaluator
environments through tree nodes. The old touched payload is then validated; a
malformed payload or overflowing count aborts before a result map is exposed.
Kind meeting and integerKindFits match checkedResult; overflow reaches the shared
checkedResult diagnostic path.

Resolved Grill Log: Map.alterF retains equal keys, whereas the prior library path's
Map.insertWith replaces their spelling. Use insertLookupWithKey to preserve the
prior observable representative without a second traversal. Exact before/after
Decimal output is required; semantic equality alone cannot detect this regression.

## Integer-pair dependency cut

For a host-Int-sized IntValue key and value, an empty occurrence Map promotes to
a persistent outer IntMap and inner SeriesMap. Later integer updates descend the numeric key and
value indexes directly and retain original key/value kind tags plus count.
Nonempty generic maps stay generic. Contains reads the numeric index directly;
noninteger or out-of-host-range arguments use its cached ordinary Map view.
Groups remain ordinary persistent Map/Sequence storage. All updates are immutable.
The numeric index keys supply the integer payloads for the lazy ordered view;
entries retain only both kind tags and the original count. This removes duplicate
boxed numeric storage without interning, normalizing kinds or mutating snapshots.
Construct strict IntPairEntry fields before publishing the persistent index;
unevaluated tuple selectors must not retain the temporary conversion payloads.
Platform signed pairs use the compact constructor whose identity supplies both
kind tags; mixed kinds use the explicit-tag entry. Count validation is shared.

Resolved Grill Log: a specialized index requires no benchmark recognition, no
public field/type change, no altered evaluator mode and no mutation. Retain a
lazy ordered view for remove/setAll/show and all public Map access. Test signed
ordering, duplicate increments, snapshots and transition back to generic maps.
Resolved Grill Log: preserve the incoming kinds on every equal-pair overwrite;
reconstruct only host-sized integers from exact index keys. Compare the ordered
view against ordinary insertion, including mixed kinds, both host boundaries,
out-of-host-width and noninteger transitions, malformed counts and overflow.

[[Eval Loop Kernel]] fuses pure loop regions containing these proven
primitives; original library implementations retain ordinary evaluation and form
the independent before/after output oracle.

## Closed primitive call depth

Proven forwarding wrappers still check the same caller depth limit and increment
the closure tally. Their primitives cannot call user code or another closure, so
successful invocation need not copy Env to enter and leave an unobservable extra
depth. Failure at the boundary still delegates to descend with the original span.
Resolved Grill Log: eliminate depth record copies only for these two closed pure
kernels; preserve the original recursion refusal and all general closure behavior.

## Persistent series payloads

The inner numeric index uses [[Runtime Series Map]]. Supply an exact compression
predicate only for PlatformIntPairEntry with platform-signed count one. Every
duplicate still combines the original count, takes incoming kinds, and creates a
sparse override. Mixed kinds/counts never collapse by semantic equality. Contains
uses series lookup; groups remain persistent Map/Sequence storage.

Resolved Grill Log: replace only the inner persistent storage behind the existing
lazy Map view. Reuse touched-count validation and shared overflow diagnostics.
Arbitrary members and old snapshots retain ordinary behavior; no input rewrite.
