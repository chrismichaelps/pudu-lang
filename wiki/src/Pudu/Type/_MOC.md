---
type: moc
tags: [moc, module]
---

# Type Module Map

- [[Type Boundary]] — the phase entry point and the published type map.
- [[Type Value]] — formed types, schemes, and how a type is rendered.
- [[Type Env]] — checker state, name frames, declared shapes, and diagnostics.
- [[Type Formation]] — type syntax to formed type, and what declarations contribute.
- [[Type Unify]] — making two types equal, or explaining why they are not.
- [[Type Check]] — checking declarations, statements, and expressions.
- [[Type Check Rule]] — the closed operator, call, member, and index rules.
- [[Type Exhaust]] — match coverage and arm reachability.
- [[Type Check Method]] — trait and implementation methods, `Self`, and inherited defaults.
- [[Type Check Coherence]] — qualified, alpha-normalized duplicate checks over implementation syntax.
- [[Type Check Pattern]] — checking patterns against the type they match.

Dependency direction: Value → Env → Unify/Formation → Rule/Pattern/Method/Coherence → Check → Boundary.

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]] · [[Pudu Type]]
