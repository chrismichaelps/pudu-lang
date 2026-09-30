---
type: module
path: "@root/src/Pudu/Type/Formation/Order.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module]
aliases: [Type Formation Order]
---

# Type Formation Order

## Purpose

Order transparent aliases before the declarations whose stored types depend on them.

## Interface

`formationOrder :: ModuleName -> [Located Declaration] -> [Located Declaration]`

## Algorithm

Build a dependency graph containing local alias declarations. Traverse named, reference, tuple,
function, and unsafe type syntax to find aliases named by their bodies, excluding the alias's own
generic parameter names. Accept bare names and the declaring module's full qualifier. Flatten
strongly connected components in dependency order, then append non-alias declarations in source
order. Dependencies through nominal data declarations stop at their previously installed shells.

## Negative Logic

No formation, inference, diagnostics, module discovery, or foreign alias lookup. Cyclic aliases
retain the formation phase's existing treatment; ordering does not invent a recursive expansion.

## Grill Log

- **Q:** Why order aliases rather than collect the whole module twice? **A:** Shapes need completed
  alias expansions, but implementations must contribute once. _Rejected:_ repeated collection and
  source-order expansion, both of which preserve the reported defect or duplicate unrelated facts.
- **Q:** Does a generic parameter named after an alias depend on that alias? **A:** No; its binder
  owns that bare name. Qualified names continue to identify declarations.

## Linkage

- **Requires:** [[Syntax Tree]], [[Syntax Name]].
- **Consumed by:** [[Type Formation]].

## Referenced by

[[Type Formation]] · [[src/Pudu/Type/_MOC]]
