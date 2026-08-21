---
type: module
path: "@root/src/Pudu/Frontend/Syntax/Located.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.52
depth_status: MEDIUM
coupling: 1.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Syntax Located]
---

# Syntax Located

## Purpose

Attach one valid [[Source Text]] span uniformly to syntax values and compose same-source child spans safely.

## Interface

### Signatures

```haskell
data Located a = Located { locatedSpan :: !Span, locatedValue :: !a }
  deriving stock (Eq, Show, Functor)

mapLocated :: (a -> b) -> Located a -> Located b
mergeLocatedSpan :: Located a -> Located b -> Maybe Span
```

### Governance

- Mapping preserves span exactly; merging rejects cross-source values.

### Linkage

- **Requires:** [[Source]].
- **Consumed by:** [[Syntax Name]], [[Syntax Tree]], and future parser modules.

## Algorithm

Store strict span/value; delegate span composition to [[Source]].

## Negative Logic (Prohibited Paths)

- No optional locations, source lookup, or semantic annotations.

## Edge Cases

- Zero-width recovery nodes are valid located values.

## Depth

DEPTH 0.52 (MEDIUM). Small interface centralizes a pervasive invariant.

## Grill Log

- **Q:** Put spans on every constructor field? **A:** Wrap externally meaningful nodes uniformly. _Rationale:_ less constructor noise and consistent tooling traversal. _Rejected:_ optional ad hoc span fields.

## Variants

- None for the initial syntax model.

## Referenced by

[[src/Pudu/Frontend/Syntax/_MOC]] · [[Syntax]] · [[Syntax Name]] · [[Syntax Tree]]
