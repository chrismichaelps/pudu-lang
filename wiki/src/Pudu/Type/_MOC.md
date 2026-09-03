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
- [[Type Check Collection]] — post-inference collection-literal boundary diagnostics.
- [[Type Marker]] — the compiler-controlled `Copy`, `Send`, and `Sync` markers, decided structurally.
- [[Type Exhaust]] — match coverage and arm reachability.
- [[Type Check Call]] — what a call's callee refers to, resolved against the implementation it will run.
- [[Type Check Safety]] — compile-time purity and unsafe capabilities, the two transitive checks of what a body may reach.
- [[Type Check Iteration]] — what a `for` loop's binder takes, from the value beside it.
- [[Type Check Method]] — trait and implementation methods, `Self`, and inherited defaults.
- [[Type Check Import]] — body-free canonical interface installation and trait-scope filtering.
- [[Type Check Prelude]] — wired-in constructors and the signatures of runtime-provided effects.
- [[Type Check Coherence]] — nominal orphan ownership plus qualified, alpha-normalized duplicate checks over implementation syntax.
- [[Type Check Pattern]] — checking patterns against the type they match.
- [[Type Check Foreign]] — the type a foreign declaration gives its functions, and what its own declaration can be wrong about.

Dependency direction: Value → Env → Unify/Formation → Rule/Pattern/Method/Coherence/Import → Check → Boundary.

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]] · [[Pudu Type]]
