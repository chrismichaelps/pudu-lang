---
type: module
path: "@root/src/Pudu/Type/Check/Coherence.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Coherence]
---

# Type Check Coherence

## Purpose

Reject duplicate implementation heads that name the same qualified trait and qualified target type in one module.

## Interface

### Signatures

```haskell
checkCoherence :: [Located Declaration] -> Checker ()
```

### Governance

- [[grammar/pudu]] prohibits overlapping implementations. This issue enforces the exact duplicate case: two implementation heads whose trait and target syntax are structurally identical after generic-parameter normalization.
- Qualified paths are part of identity. `A.Show` and `B.Show` are different traits even when their final segments match, consistent with [[architecture/SEMANTICS]]'s nominal identity rule.
- Generic parameter spellings do not create distinct heads. `impl[T] Show for Box[T]` and `impl[U] Show for Box[U]` normalize their declared parameters by position and conflict.
- Every duplicate after the first reports one `E3015` at its target span. The check does not claim to choose a canonical method body; compilation is error-gated, so no rejected module reaches execution.
- The check runs after signatures are collected and once per module, allowing body checking to continue without reporting the duplicate more than once.

### Linkage

- **Requires:** [[Type Env]], [[Syntax Tree]], [[grammar/pudu]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check]].

## Algorithm

Fold over implementations from left to right. Convert each trait and target syntax tree into a comparable key that preserves qualified paths, reference/function/tuple structure, and generic arguments while replacing the implementation's own generic parameter names with positional identities. Insert the first key into a set. If a key already exists, report `E3015` on the later target and retain the set unchanged.

## Negative Logic (Prohibited Paths)

- No orphan checking: ownership by the current module is issue #28 and is intentionally excluded from issue #27.
- No general unification overlap: heads that could overlap only after type inference are deferred until implementations are represented by resolved typed identities. This slice rejects exact duplicate heads and alpha-equivalent generic duplicates without collapsing distinct syntax.
- No last-segment comparison: dropping module qualifiers creates false overlap between distinct imported declarations.
- No method-table suppression or dispatch from an invalid module. Diagnostics gate compilation before evaluation, so the checker may continue analyzing bodies without promising which rejected declaration would dispatch.

## Edge Cases

- Three identical heads produce two `E3015` diagnostics, one for each occurrence after the first.
- `A.Mark for Local` and `B.Mark for Local` do not conflict.
- `impl[T] Mark for Box[T]` conflicts with `impl[U] Mark for Box[U]`.
- Reference, tuple, function, unit, and recovered type syntax receive structural keys rather than bypassing the check. Whether a non-nominal implementation target is legal is a separate formation rule.

## Depth

DEPTH 0.55 (MEDIUM). One entry point hides structural key construction, generic alpha-normalization, qualified identity, and exactly-once duplicate reporting.

## Grill Log

- **Q:** Should duplicate implementations be an error or warning? **A:** Error. _Rationale:_ two definitions for the same head leave dispatch ambiguous, and [[grammar/pudu]] prohibits overlap. _Rejected:_ warning with first-wins or last-wins dispatch.
- **Q:** Should paths be reduced to their final segment? **A:** No. _Rationale:_ nominal identity includes the declaration path, so `A.Show` and `B.Show` cannot share a coherence key. _Rejected:_ basename keys, which invent false overlap across modules.
- **Q:** Should generic parameter spelling distinguish heads? **A:** No. _Rationale:_ parameter names are local binders, so alpha-renaming cannot change implementation identity. _Rejected:_ raw syntax equality, which would admit duplicates by renaming `T` to `U`.
- **Q:** Should this slice claim general overlap detection? **A:** No. _Rationale:_ detecting unification overlap requires resolved typed implementation heads, which the current checker does not expose. _Rejected:_ basename heuristics or transparent-alias guesses that accept and reject the wrong programs.

## Variants

- Issue #28 adds the independently specified orphan-ownership rule.
- Resolved implementation identities extend the key from exact normalized heads to unification overlap and transparent-alias equality.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Type Check Method]]
