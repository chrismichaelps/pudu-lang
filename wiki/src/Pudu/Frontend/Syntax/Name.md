---
type: module
path: "@root/src/Pudu/Frontend/Syntax/Name.hs"
fidelity: Active
domain: "[[Pudu Module]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.48
depth_status: MEDIUM
coupling: 1.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Syntax Name]
---

# Syntax Name

## Purpose

Represent non-empty dotted Pudu module/name paths without resolving declaration identity.

## Interface

### Signatures

```haskell
newtype ModuleName = ModuleName { moduleNameSegments :: NonEmpty Text }
  deriving stock (Eq, Ord, Show)

moduleNameText :: ModuleName -> Text
moduleQualifier :: ModuleName -> Text
```

### Governance

- Empty paths are unrepresentable; parser validates segment casing separately.
- `moduleQualifier` is the last segment: the name an unaliased `import M` is
  reached through. It is the single definition every side asks, so a qualifier
  the checker resolves against is the one the evaluator binds.

### Linkage

- **Requires:** [[Pudu Module]].
- **Consumed by:** [[Syntax Tree]], [[Semantic Interface]], [[Type Interface]], and
  [[Eval Program]], which all settle import qualifiers through `moduleQualifier`.

## Algorithm

Join segments with `.` only for display; identity remains segmented.

## Negative Logic (Prohibited Paths)

- No symbol IDs, import resolution, normalization, or empty constructor.

## Edge Cases

- One segment is ordinary.

## Depth

DEPTH 0.48 (MEDIUM). A narrow nominal contract prevents stringly module paths.

## Grill Log

- **Q:** Store one dotted `Text`? **A:** No; store non-empty segments. _Rationale:_ resolution and diagnostics need boundaries. _Rejected:_ repeated splitting.
- **Q:** Let each side derive an import's qualifier for itself? **A:** No. Two copies in the checker
  and none in the evaluator is what let `import Std.Map` check clean and then fail at run time with
  an undefined `Map`. A rule two sides must agree on belongs in one place, and the segments are
  already here, so the last one needs no splitting to find.

## Variants

- Resolved names later use stable symbol IDs in [[Semantics]].

## Referenced by

[[src/Pudu/Frontend/Syntax/_MOC]] · [[Syntax]] · [[Syntax Tree]]
