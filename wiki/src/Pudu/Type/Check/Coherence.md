---
type: module
path: "@root/src/Pudu/Type/Check/Coherence.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.72
depth_status: DEEP
coupling: 3.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Type Check Coherence]
---

# Type Check Coherence

## Purpose

Reject orphan implementations and duplicate implementation heads before method dispatch can observe an incoherent module.

## Interface

### Signatures

```haskell
checkCoherence :: [Located Declaration] -> Checker ()
```

### Governance

- [[grammar/pudu]] prohibits overlapping implementations. This issue enforces the exact duplicate case: two implementation heads whose trait and target syntax are structurally identical after generic-parameter normalization.
- [[grammar/pudu]] also requires the current module to declare either the implemented trait or the target's nominal type. A foreign trait implemented for a foreign target reports `E3014` at the target span.
- Ownership follows declaration identity after transparent alias expansion. Declaring an alias for a foreign type or trait does not make that declaration local; generic alias parameters are substituted before the owner is classified.
- An implementation's generic parameters are lexical binders and take precedence over same-named module aliases, nominal types, and traits. A binder occurrence never contributes ownership, including after alias expansion.
- Record and sum declarations are nominal owners. Aliases, built-ins, implementation parameters, references, tuples, functions, unit, and recovered invalid syntax do not introduce a nominal owner.
- Qualified paths are part of identity. `A.Show` and `B.Show` are different traits even when their final segments match, consistent with [[architecture/SEMANTICS]]'s nominal identity rule.
- Generic parameter spellings do not create distinct heads. `impl[T] Show for Box[T]` and `impl[U] Show for Box[U]` normalize their declared parameters by position and conflict.
- Every duplicate after the first reports one `E3015` at its target span. The check does not claim to choose a canonical method body; compilation is error-gated, so no rejected module reaches execution.
- The check runs after signatures are collected and once per module, allowing body checking to continue without reporting the duplicate more than once.

### Linkage

- **Requires:** [[Type Env]], [[Syntax Tree]], [[grammar/pudu]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check]].

## Algorithm

Catalog local trait declarations, local nominal record/sum declarations, and transparent aliases. For each implementation, expand only locally declared aliases with their supplied arguments while guarding alias cycles. The implementation is owned when the expanded trait root names a local trait or the expanded target root names a local nominal declaration; otherwise report `E3014`. Independently convert each trait and target syntax tree into a comparable key that preserves qualified paths, reference/function/tuple structure, and generic arguments while replacing the implementation's own generic parameter names with positional identities. Fold those keys left to right, reporting `E3015` for every key after its first occurrence.

## Negative Logic (Prohibited Paths)

- No general unification overlap: heads that could overlap only after type inference are deferred until implementations are represented by resolved typed identities. This slice rejects exact duplicate heads and alpha-equivalent generic duplicates without collapsing distinct syntax.
- No last-segment comparison: dropping module qualifiers creates false overlap between distinct imported declarations.
- No alias-as-owner shortcut: an alias is transparent and therefore cannot launder a foreign declaration into local ownership.
- No cross-module lookup or filesystem loading. Qualified and otherwise non-local roots are foreign unless transparent expansion reaches a declaration in the current module.
- No method-table suppression or dispatch from an invalid module. Diagnostics gate compilation before evaluation, so the checker may continue analyzing bodies without promising which rejected declaration would dispatch.

## Edge Cases

- Three identical heads produce two `E3015` diagnostics, one for each occurrence after the first.
- `A.Mark for Local` and `B.Mark for Local` do not conflict.
- `impl[T] Mark for Box[T]` conflicts with `impl[U] Mark for Box[U]`.
- A foreign trait for a local record or sum is owned; a local trait for a foreign, built-in, generic, or non-nominal target is also owned by the trait declaration.
- A foreign trait for a local alias of a foreign target is orphaned, including generic aliases such as `type Wrapped[T] = T` applied to a foreign type.
- `impl[T]` shadows a module declaration named `T`; using that `T` as the trait or target remains non-owning rather than falling through to the shadowed alias, nominal type, or trait.
- Reference, tuple, function, unit, and recovered type syntax receive structural duplicate keys, but none can satisfy target ownership. Whether a non-nominal implementation target is otherwise legal remains a separate formation rule.
- Alias cycles and arity-invalid alias applications never manufacture local ownership; any independent formation diagnostic remains responsible for explaining the malformed type.

## Depth

DEPTH 0.72 (DEEP). One entry point hides local declaration cataloging, cycle-safe generic alias substitution, nominal ownership classification, structural key construction, generic alpha-normalization, qualified identity, and exactly-once diagnostics.

## Grill Log

- **Q:** Should duplicate implementations be an error or warning? **A:** Error. _Rationale:_ two definitions for the same head leave dispatch ambiguous, and [[grammar/pudu]] prohibits overlap. _Rejected:_ warning with first-wins or last-wins dispatch.
- **Q:** Should paths be reduced to their final segment? **A:** No. _Rationale:_ nominal identity includes the declaration path, so `A.Show` and `B.Show` cannot share a coherence key. _Rejected:_ basename keys, which invent false overlap across modules.
- **Q:** Should generic parameter spelling distinguish heads? **A:** No. _Rationale:_ parameter names are local binders, so alpha-renaming cannot change implementation identity. _Rejected:_ raw syntax equality, which would admit duplicates by renaming `T` to `U`.
- **Q:** Does declaring a transparent alias grant implementation ownership? **A:** No; expand the alias and classify the underlying declaration. _Rationale:_ aliases do not create nominal identity, so treating one as local would let any module bypass the orphan rule with one line. _Rejected:_ spelling-based ownership; treating every local `type` declaration as nominal.
- **Q:** Can a non-nominal target satisfy ownership? **A:** No, but a locally declared trait can still own the implementation. _Rationale:_ the orphan rule is an either/or rule and target formation is a separate concern. _Rejected:_ treating references, tuples, functions, unit, built-ins, or type parameters as locally declared nominal types; rejecting them here even when the trait is local.
- **Q:** Should orphan checking wait for cross-module resolution? **A:** No. _Rationale:_ local ownership can be decided exactly from this module's declarations plus transparent local-alias expansion; every other root is non-local for this judgement. _Rejected:_ basename heuristics over imports; filesystem module loading inside the type checker.
- **Q:** Should this slice claim general overlap detection? **A:** No. _Rationale:_ detecting unification overlap requires resolved typed implementation heads, which the current checker does not expose. _Rejected:_ basename heuristics or transparent-alias guesses that accept and reject the wrong programs.

## Variants

- Resolved implementation identities extend the key from exact normalized heads to unification overlap and transparent-alias equality.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Type Check Method]] · [[Parser Trait]]
