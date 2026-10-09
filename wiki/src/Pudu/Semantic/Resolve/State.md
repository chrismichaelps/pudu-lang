---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Semantic/Resolve/State.hs"
fidelity: Active
subsystem: "[[Semantics]]"
aliases: [Resolve State]
tags: [module, resolution]
---
# Resolve State

## Purpose and interface

Own the invocation-local ResolveState record, Resolver action constructor, pure action instances and initialState. [[Resolve Context]] retains abstract public operations and freezes products. Context is the sole consumer of mutable-in-description state mechanics; the implementation is pure explicit state threading.

## Algorithm and invariants

Preserve existing accumulator order, monotonic symbol IDs, initial root frame, loop stack, scoped canonical/derive flags and reflection imports. A Set of SymbolId records module qualifiers. It starts empty each invocation; IDs remain distinct across nested scopes so discarded declarations cannot mark a later shadow.

## Negative logic and edge cases

No source loading, global state, typing, import projection or diagnostics policy. Scope cleanup and diagnostic ordering remain owned by Context. Existing initial state is preserved field-for-field apart from the empty qualifier set.

## Resolved Grill Log

- **Q:** Grow the context beyond its size boundary? **A:** Extract this cohesive pure state/action responsibility while retaining the abstract facade. No new effect or state ownership is introduced.
- **Q:** Store qualifier spellings? **A:** No; use resolved identities so ordinary shadows and selected exports remain values.

## Referenced by

[[Resolve Context]] · [[src/pudu-cabal|Pudu Package Manifest]] · [[src/Pudu/Semantic/_MOC]]
