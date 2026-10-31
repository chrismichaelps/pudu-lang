---
type: handoff
status: ACTIVE
aliases: [Positional Sum Owner Delivery]
tags: [handoff, runtime, nominal]
---
# Positional Sum Owner Delivery

Issue #761 starts from fetched dev 769dbc71, integrates #765 at e0866dd3, then
fast-forwards to its merged dev head 5f6c8bb58 on feature/761-sum-constructor-owners.
The prerequisite code trees match. Preserve separate record and qualification deliveries.
Architect resolves positional ownership; Runtime Engineer owns Value, Install, Call, Call.Path,
Loop, Operator.Access, Frozen, Match, Json/Binary/Xml native factories, BinarySpec and the CLI
gate plus mirrors. The owner waived independent review for this engine loop. No delegated agents.

First.Item and Second.Item each declaring Empty | Chosen(Int) still dispatch the second
implementation for both values in both evaluators. Native JSON and binary also share Text labels.
Canonical type identity must travel in positional values rather than the global short-tag map.

## Resolved Grill Log

Store canonical owner plus short label and payload. Keep VariantValue as a bundled pattern so
native payload readers remain direct; wired constructor builders name Option/Result explicitly,
and native JSON/binary/XML factories name their declared owners. Source constructors receive
module-qualified owners at installation and retain them through application and freezing.
Canonical type namespaces make generated constructor references reachable without guessing.
Equality/order include owner. Await distinguishes wired Result from custom Ok/Err-labelled sums.
Wire/display labels and existing evaluation/effect/diagnostic behavior remain stable.

This is the positional value partition. Canonical pattern matching and usefulness keys are
separate required checker/matcher work: a dynamic match on B.Item.Chosen currently takes the
A.Item.Chosen arm and emits a false W5001 for the second arm. The reproducer is recorded in #761.
Named-payload ownership requires its own resolved constructor
representation and remains in #761, along with full owner/evidence reconciliation for #734/#735.
Do not present a partial repair as completion of that issue or the engine. Keep below 600 lines.

Required validation: failing same-name reproducer; direct/generic/retained calls and
cross-module labels, defining captures, built-in/custom label overlap, task results, equality,
freezing/cache reuse and native node parity in both evaluators. Preserve codec goldens and every
existing derive/diagnostic oracle. Run focused then clean full optimized gates.
The original cross-module gate fails before repair. The owner/task/native/dynamic-equality
regression passes after repair in both evaluators, including stored product reuse. Native codec
properties pin owner metadata as well as independent wire bytes; record, qualified-method,
provider and derive regressions pass. Same-module duplicate-label rejection is separately #766.
Clean full optimized repository gates passed, including the complete suite, both owner gates,
all Ark gates, package, residency, lint, language-server, watch and documentation checks.
Forensic Guardian self-audit reconciled owner contracts, mirrors and stale dispatch comments;
independent review remains waived by the owner for this loop.
Exact next action: publish this representation partition, then implement canonical pattern
ownership and usefulness before further engine work.

## Referenced by

[[handoffs/_MOC]] · [[Eval Value]] · [[Eval Install]] · [[Eval Binary]] · [[Eval Json]] · [[Eval Xml]]
