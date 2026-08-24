---
type: moc
tags: [moc, module]
---

# Type Module Map

- [[Type Boundary]] — the phase entry point and the published type map.
- [[Type Value]] — formed types, schemes, and how a type is rendered.
- [[Type Env]] — checker state, name frames, declared shapes, and diagnostics.
- [[Type Formation]] — type syntax to formed type, and what declarations contribute.
- [[Type Interface]] — exported signatures, canonical declaration identity, and import-scoped implementation visibility.
- [[Type Unify]] — making two types equal, or explaining why they are not.
- [[Type Check]] — checking declarations, statements, and expressions.
- [[Type Check Rule]] — the closed operator, call, member, and index rules.
- [[Type Marker]] — the compiler-controlled `Copy`, `Send`, and `Sync` markers, decided structurally.
- [[Type Exhaust]] — match coverage and arm reachability.
- [[Type Check Method]] — trait and implementation methods, `Self`, and inherited defaults.
- [[Type Check Import]] — body-free canonical interface installation and trait-scope filtering.
- [[Type Check Coherence]] — nominal orphan ownership plus qualified, alpha-normalized duplicate checks over implementation syntax.
- [[Type Check Pattern]] — checking patterns against the type they match.

Dependency direction: Value → Env → Unify/Formation → Rule/Pattern/Method/Coherence/Import → Check → Boundary.

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]] · [[Pudu Type]]
