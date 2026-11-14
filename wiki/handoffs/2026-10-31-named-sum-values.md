---
type: handoff
status: ACTIVE
aliases: [Named Sum Value Delivery]
tags: [handoff, runtime, nominal]
---
# Named Sum Value Delivery

Issue #761; feature/761-named-value-foundation begins from fetched dev eac68eb7,
explicitly integrating tested named-field prerequisite d15a53d5. Publish after
that partition merges. Architect resolves the representation; Runtime Engineer
owns Eval.Value/Match/Order/Render/Frozen/Operator.Access/Place/Loop, the focused
NamedSumSpec, test coordinator and test manifest. Forensic Guardian owns their
mirrors, MOCs, domain note and changelog. Independent review is waived for this
owner-authorized loop. No delegated agents.

## Resolved Grill Log

Named sum payloads currently use RecordValue shortTag fields. Distinct declaring
owners dispatch through one another (#761 comment 6550660473); admitted named sum
iteration fails E7001 (6551087972). Carry canonical owner, short variant label and
named fields in a separate NamedSumValue shape. An ordinary record declared in a
nested module may have the same complete text as sumOwner.variant, so do not
encode named sums as ordinary record keys.

All value consumers preserve identity: both equalities, keyed ordering, pattern
matching, fields and lent writes, method and iteration owner lookup, rendering
and frozen data. Kind 17 stores owner/tag/fields. Match the unspellable internal
pattern descriptor ::sum::/owner/tag without a runtime span table or registry.
Anonymous and raw host patterns keep compatibility. This foundation deliberately
has no source producer; the next publication partition records checked variant
owner facts and selects the value constructor in each evaluator.

Stored field order is supplied by construction. Source publication must reconcile
canonical declaration-order storage with issue #519 while preserving authored
field effects; it cannot infer field order from a shared basename. Host tests
supply explicit field order and do not claim that publication is already fixed.

Required evidence: owner/tag/shape inequality, keyed storage, recursive numeric
semantics, stable display, frozen roundtrip/truncation/nonportable refusal,
canonical/raw/anonymous patterns, field reads/writes, owner registry independence
and real evaluator sum iteration, followed by focused and full optimized gates.

## Validation and delivery

Four focused runtime property groups pass under optimized warning-free builds.
The clean full repository gate passes, including the complete suite, owner/cache
checks, all Ark subsystems, package/CLI/LSP checks and derive boundaries.
Introduced wiki links resolve, tracked private inputs are absent, and Value stays
at 498 lines. The representation has no source producer yet.

Exact next action: after named-field PR #770 merges, publish this bounded runtime
foundation PR to dev; then publish checked named constructors and patterns before
new engine features.

## Referenced by

[[handoffs/_MOC]] · [[Eval Value]] · [[Eval Match]] · [[Eval Order]] · [[Eval Render]] · [[Eval Frozen]] · [[Eval Operator Access]] · [[Eval Place]] · [[Eval Loop]] · [[Named Sum Value Properties]]
