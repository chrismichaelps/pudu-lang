---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Coherence.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, coherence]
aliases: [Derive Graph Coherence]
---

# Derive Graph Coherence

## Purpose and interface

`requestOwnership` checks each request's canonical trait and target owners against
its original module. `generatedCoherence` compares generated heads against every
ordinary head and earlier generated head in the loaded graph. Return per-module
diagnostics with source anchors; no failing head becomes evidence.

## Algorithm and invariants

Form ordinary heads in their declaration scope. Generated heads are fully
canonical and carry their request binders. [[Trait Evidence Matching]] freshens
both parameter sets independently and tests complete target/trait overlap using
bounded isolated evidence. Conditional bounds do not make dispatch overlap safe.
Canonical aliases, alpha-renamed binders and concrete specializations cannot evade
overlap. Charge graph pair checks against the compile-time work limit.

## Diagnostics and edges

E3014 marks an orphan request; E3015 marks overlapping generated evidence with
the other head attached. E3093 refuses exhausted coherence work. A malformed
ordinary head remains the ordinary checker's error; it supplies no guessed
overlap evidence. Errors belong to request modules even though generated methods
retain definition-module lexical context. No ordinary-only behavior changes.

## Negative logic

No source-spelling ownership, source concatenation, implementation body checking,
filesystem reads, coinductive proof, caller substitutions or first-wins dispatch.

## Grill Log

- **Q:** Can definition placement authorize a foreign request? **A:** No;
  ownership comes from the canonical original request module. _Rejected:_ alias
  laundering or considering template ownership sufficient.
- **Q:** Check only identical syntax? **A:** Test typed overlap with the shared
  evidence matcher. _Rejected:_ trait basename keys and parameter-spelling keys.
- **Q:** Guess disjointness when matching exhausts work? **A:** Refuse publication.

## Linkage and references

Requires [[Derive Catalogue]], [[Trait Evidence Matching]], [[Compile Time Limits]],
[[Type Formation]] and [[Diagnostic Model]]. Referenced by [[Derive Graph]] ·
[[Type Check Coherence]] · [[Derive Design]] · [[src/_MOC]].
