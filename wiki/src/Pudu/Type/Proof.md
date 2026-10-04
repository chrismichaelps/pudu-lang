---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Proof.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, trait]
aliases: [Type Trait Proof]
---

# Type Trait Proof

## Purpose and interface

`proveBound` returns Proven, Unproved or ProofLimit for a complete trait application.
`implementsTrait` retains identity-only dynamic widening. Both consume canonical
[[Type Implementation Rules]] without checking method bodies.
`inferBound` additionally returns proposals for ordinary call inference and may
return ProofAmbiguous. No function writes caller substitutions. The call boundary
commits unique successful proposals through ordinary unification.

## Algorithm and invariants

Normalize the input and explicit demand once under shared depth/work limits.
Index rules by canonical target and trait owners, then match complete applications.
Fully selected heads use the pure fast matcher. Parameters determined through
recursive premises use [[Trait Evidence Matching]]. Successful premises pass local
bindings to the remaining proof; later failure revisits earlier alternatives.
Delay an unsettled local subject until another premise determines its type.

Rigid subjects use complete scoped applications. Markers use their structural
rules. Every candidate consumes work, including unrelated scoped identity bounds.
Exact active goals refuse rather than prove themselves. The trail narrows by
canonical owners and target size, with full equality under current evidence in
matching buckets. Descending nested types avoid scanning every larger ancestor.

Call inference copies holes in the target and demand into private evidence,
keeping their correlations and fixed nominal constructor. Demand holes must be
fully determined. Unbound target-only holes may remain when a rule proves the
capability uniformly. Incomplete private type solutions never escape. A second
search shares the remaining work and refuses any different successful proposal.
Failed alternatives roll back bindings without refunding fuel or reusing identities.

## Negative logic and edge cases

No owner-only application acceptance, caller mutation, runtime values, graph IO,
body checking or coinductive acceptance of arbitrary cycles. Error recovery does
not supply evidence. An unknown target owner is never guessed. Ambiguous applications
require the caller to state the missing argument; no overlapping candidate is
chosen as an inference default.

## Performance evidence

The first repeated-normalization/path-scan prototype refused a valid 500-level
proof and took 0.057s at 250 levels. Normalization once and indexed exact-cycle
checks accept 1,000 nested conditional types in approximately 0.010s CPU on the
local optimized build. This measures capability proof, not generated JSON execution.

## Grill Log

- **Q:** Can a conditional implementation prove itself? **A:** Refuse an active
  identical goal. _Rationale:_ a circular premise is not evidence. _Rejected:_
  broad acceptance by owner or unbounded recursion.
- **Q:** Can target-only matching determine iterator state? **A:** Infer it through
  nested Sequence evidence. _Rationale:_ wrapper state and item parameters can
  occur only in premises. _Rejected:_ erasing conditions or rejecting valid iterators.
- **Q:** May a failed candidate alter caller inference? **A:** No; search is isolated.
  _Rationale:_ proposals commit only after complete unique success. _Rejected:_
  unifying while trying candidates, implicit owner guessing or fuel reset on rollback.
- **Q:** Duplicate a derive solver? **A:** Share proof with ordinary call admission
  and dynamic widening. _Rationale:_ field proof must enforce the same capabilities.
  _Rejected:_ a derive-only owner shortcut.

## Referenced by

[[Type Implementation Rules]] · [[Trait Evidence Matching]] · [[Type Check Method]] ·
[[Type Unify]] · [[src/Pudu/Type/_MOC]] · [[Derive Design]]
